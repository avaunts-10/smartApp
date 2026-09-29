import express from "express";
import multer from "multer";
import path from "path";
import fs from "fs";
import { fileURLToPath } from "url";
import pool from "../db.js";
import { requireAuth, requireRole } from "../middleware/auth.js";

const router = express.Router();
router.use(requireAuth);

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const uploadDir = path.join(__dirname, "..", "..", "uploads", "materials");
fs.mkdirSync(uploadDir, { recursive: true });

const ALLOWED_TYPES = new Set([
  "application/pdf",
  "application/msword",
  "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  "image/png",
  "image/jpeg",
  "image/webp",
]);

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, uploadDir),
  filename: (_req, file, cb) => {
    const unique = `${Date.now()}-${Math.round(Math.random() * 1e9)}`;
    cb(null, `${unique}${path.extname(file.originalname)}`);
  },
});
const upload = multer({
  storage,
  limits: { fileSize: 20 * 1024 * 1024 },
  fileFilter: (_req, file, cb) => cb(null, ALLOWED_TYPES.has(file.mimetype)),
});

function toMaterial(r) {
  return {
    id: r.id,
    subjectId: r.subject_id,
    subjectName: r.subject_name ?? null,
    title: r.title,
    description: r.description,
    fileUrl: r.file_url,
    fileName: r.file_name,
    fileType: r.file_type,
    uploadedBy: r.uploaded_by,
    createdAt: r.created_at,
  };
}

// GET /api/materials?subject_id=...
router.get("/", async (req, res) => {
  try {
    const { subject_id } = req.query;
    const params = [];
    let where = "";
    if (subject_id) {
      params.push(subject_id);
      where = "WHERE m.subject_id = $1";
    }
    const { rows } = await pool.query(
      `SELECT m.*, s.name AS subject_name
       FROM learning_materials m
       LEFT JOIN subjects s ON s.id = m.subject_id
       ${where}
       ORDER BY m.created_at DESC`,
      params
    );
    res.json({ materials: rows.map(toMaterial) });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
});

// POST /api/materials (teacher only)  multipart: subject_id, title, description?, file
router.post(
  "/",
  requireRole("teacher"),
  upload.single("file"),
  async (req, res) => {
    try {
      const { subject_id, title, description } = req.body;
      if (!subject_id || !title) {
        return res
          .status(400)
          .json({ message: "subject_id and title are required" });
      }
      if (!req.file) {
        return res.status(400).json({ message: "file is required" });
      }

      const fileUrl = `/uploads/materials/${req.file.filename}`;
      const { rows } = await pool.query(
        `INSERT INTO learning_materials
           (subject_id, title, description, file_url, file_name, file_type, uploaded_by)
         VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *`,
        [
          subject_id,
          title,
          description || null,
          fileUrl,
          req.file.originalname,
          req.file.mimetype,
          req.user.id,
        ]
      );
      res.status(201).json({ material: toMaterial(rows[0]) });
    } catch (err) {
      console.error(err);
      res.status(500).json({ message: "Server error" });
    }
  }
);

// DELETE /api/materials/:id (teacher/admin only)
router.delete("/:id", requireRole("admin", "teacher"), async (req, res) => {
  try {
    const { rows } = await pool.query(
      `DELETE FROM learning_materials WHERE id = $1 RETURNING file_url`,
      [req.params.id]
    );
    if (!rows.length) return res.status(404).json({ message: "Not found" });

    const fileUrl = rows[0].file_url;
    if (fileUrl) {
      const filePath = path.join(
        __dirname,
        "..",
        "..",
        fileUrl.replace(/^\//, "")
      );
      fs.unlink(filePath, () => {});
    }
    res.json({ message: "Deleted" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
});

export default router;
