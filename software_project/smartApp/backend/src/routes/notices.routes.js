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
const uploadDir = path.join(__dirname, "..", "..", "uploads", "notices");
fs.mkdirSync(uploadDir, { recursive: true });

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, uploadDir),
  filename: (_req, file, cb) => {
    const unique = `${Date.now()}-${Math.round(Math.random() * 1e9)}`;
    cb(null, `${unique}${path.extname(file.originalname)}`);
  },
});
const upload = multer({ storage, limits: { fileSize: 10 * 1024 * 1024 } });

function toNotice(r) {
  return {
    id: r.id,
    title: r.title,
    message: r.message,
    attachmentUrl: r.attachment_url,
    attachmentName: r.attachment_name,
    createdBy: r.created_by,
    createdByEmail: r.created_by_email ?? null,
    createdAt: r.created_at,
  };
}

// GET /api/notices -> all notices, newest first
router.get("/", async (_req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT n.*, u.email AS created_by_email
       FROM notices n
       LEFT JOIN users u ON u.id = n.created_by
       ORDER BY n.created_at DESC`
    );
    res.json({ notices: rows.map(toNotice) });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
});

// POST /api/notices  (teacher only)  multipart: title, message, attachment?
router.post(
  "/",
  requireRole("teacher"),
  upload.single("attachment"),
  async (req, res) => {
    try {
      const { title, message } = req.body;
      if (!title || !message) {
        return res
          .status(400)
          .json({ message: "title and message are required" });
      }
      const attachmentUrl = req.file
        ? `/uploads/notices/${req.file.filename}`
        : null;
      const attachmentName = req.file ? req.file.originalname : null;

      const { rows } = await pool.query(
        `INSERT INTO notices (title, message, attachment_url, attachment_name, created_by)
         VALUES ($1, $2, $3, $4, $5) RETURNING *`,
        [title, message, attachmentUrl, attachmentName, req.user.id]
      );
      res.status(201).json({ notice: toNotice(rows[0]) });
    } catch (err) {
      console.error(err);
      res.status(500).json({ message: "Server error" });
    }
  }
);

// DELETE /api/notices/:id (teacher/admin only)
router.delete("/:id", requireRole("admin", "teacher"), async (req, res) => {
  try {
    const { rows } = await pool.query(
      `DELETE FROM notices WHERE id = $1 RETURNING attachment_url`,
      [req.params.id]
    );
    if (!rows.length) return res.status(404).json({ message: "Not found" });

    const attachmentUrl = rows[0].attachment_url;
    if (attachmentUrl) {
      const filePath = path.join(
        __dirname,
        "..",
        "..",
        attachmentUrl.replace(/^\//, "")
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
