import express from "express";
import cors from "cors";
import { createServer } from "http";
import { Server } from "socket.io";
import morgan from "morgan";
import helmet from "helmet";
import dotenv from "dotenv";
import path from "path";
import { fileURLToPath } from "url";
import sensorRoutes from "./routes/sensor.routes.js";

import { setIO } from "./socket.js";

import authRoutes from "./routes/auth.routes.js";
import deviceRoutes from "./routes/device.routes.js";
import environmentRoutes from "./routes/environment.routes.js";
import studentsRoutes from "./routes/students.routes.js";
import attendanceRoutes from "./routes/attendance.routes.js";
import scheduleRoutes, { startScheduleAutomation } from "./routes/schedule.routes.js";
import learningRoutes from "./routes/learning.routes.js";
import noticesRoutes from "./routes/notices.routes.js";
import materialsRoutes from "./routes/materials.routes.js";
import quizzesRoutes from "./routes/quizzes.routes.js";
import aiTeacherRouter from "./routes/aiTeacher.js";
import { startSensorSimulator } from "./sensors.js";

dotenv.config();

const app = express();

const httpServer = createServer(app);

const io = new Server(httpServer, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"],
  },
});

setIO(io);

io.on("connection", (socket) => {
  console.log(`Flutter client connected: ${socket.id}`);

  socket.on("disconnect", () => {
    console.log(`Flutter client disconnected: ${socket.id}`);
  });
});

app.use(cors());
app.use(
  helmet({
    contentSecurityPolicy: {
      useDefaults: true,
      directives: {
        ...helmet.contentSecurityPolicy.getDefaultDirectives(),

        // Allow textures and binary data used by glTF loaders
        "img-src": ["'self'", "data:", "blob:"],
        "connect-src": ["'self'", "blob:"],

        // Needed if you use module scripts / workers for wasm decoders
        "script-src": ["'self'", "'unsafe-inline'"],
        "worker-src": ["'self'", "blob:"],
      },
    },
    crossOriginResourcePolicy: { policy: "cross-origin" }, // helps with assets
  })
);
app.use(express.json());
app.use(morgan("dev"));

app.use("/api/auth", authRoutes);
app.use("/api/devices", deviceRoutes);
app.use("/api/environment", environmentRoutes);
app.use("/api/students", studentsRoutes);
app.use("/api/attendance", attendanceRoutes);
app.use("/api/schedule", scheduleRoutes);
app.use("/api/learning", learningRoutes);
app.use("/api/notices", noticesRoutes);
app.use("/api/materials", materialsRoutes);
app.use("/api/quizzes", quizzesRoutes);
app.use("/api/ai", aiTeacherRouter);
app.use("/api/sensors", sensorRoutes);

/* ✅ Serve 3D Teacher static files */
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// this points to: backend/public_teacher3d
// Embedded by the Flutter AI-Teacher screen in an <iframe> served from a
// different port, so relax helmet's frame-blocking headers for this path.
app.use(
  "/teacher3d",
  (req, res, next) => {
    res.removeHeader("X-Frame-Options");
    res.setHeader(
      "Content-Security-Policy",
      [
        "default-src 'self'",
        // 'wasm-unsafe-eval' + blob: for the Draco / meshopt decoders that
        // Ready Player Me avatars need; *.readyplayer.me for the GLB downloads.
        "script-src 'self' 'unsafe-inline' 'wasm-unsafe-eval' blob:",
        "style-src 'self' 'unsafe-inline'",
        "img-src 'self' data: blob: https://*.readyplayer.me",
        "media-src 'self' blob:",
        "connect-src 'self' blob: https://*.readyplayer.me",
        "worker-src 'self' blob:",
        "frame-ancestors *",
      ].join("; ")
    );
    next();
  },
  express.static(path.join(__dirname, "..", "public_teacher3d"))
);

// ✅ serve Three.js from node_modules (NO CDN)
app.use("/three", express.static(path.join(__dirname, "..", "node_modules", "three")));

// Notice-board attachments and subject learning materials uploaded via multer.
app.use("/uploads", express.static(path.join(__dirname, "..", "uploads")));

// Facial-recognition capture page (vendored face-api.js + models). Embedded by
// the Flutter Attendance screen in an <iframe> served from a different port, so
// override helmet's frame-blocking headers just for this path.
app.use(
  "/face",
  (req, res, next) => {
    res.removeHeader("X-Frame-Options");
    res.setHeader(
      "Content-Security-Policy",
      [
        "default-src 'self'",
        "script-src 'self' 'unsafe-inline'",
        "style-src 'self' 'unsafe-inline'",
        "img-src 'self' data: blob:",
        "media-src 'self' blob:",
        "connect-src 'self'",
        "frame-ancestors *",
      ].join("; ")
    );
    next();
  },
  express.static(path.join(__dirname, "..", "public", "face"))
);

app.get("/", (req, res) => {
  res.json({ message: "Smart Classroom API running" });
});

const PORT = process.env.PORT || 4000;
httpServer.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
  // Sensor readings arrive through the real-time sensor endpoint on main.
  startScheduleAutomation();
});
