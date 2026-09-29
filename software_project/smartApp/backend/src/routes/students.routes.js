import express from "express";
import pool from "../db.js";
import { requireAuth, requireRole } from "../middleware/auth.js";
import { isValidDescriptor } from "../face.js";

const router = express.Router();
router.use(requireAuth);

const staff = requireRole("admin", "teacher");

// GET /api/students  — roster with enrolled-face counts
router.get("/", async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT s.id, s.name, s.student_code, s.email, s.created_at,
              COUNT(f.id)::int AS face_count
       FROM students s
       LEFT JOIN face_descriptors f ON f.student_id = s.id
       GROUP BY s.id
       ORDER BY s.name ASC`
    );
    res.json({
      students: rows.map((r) => ({
        id: r.id,
        name: r.name,
        studentCode: r.student_code,
        email: r.email,
        faceCount: r.face_count,
        enrolled: r.face_count > 0,
      })),
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
});

// POST /api/students  { name, studentCode, email? }
router.post("/", staff, async (req, res) => {
  try {
    const { name, studentCode, email } = req.body;
    if (!name || !studentCode) {
      return res
        .status(400)
        .json({ message: "name and studentCode are required" });
    }
    const existing = await pool.query(
      `SELECT id FROM students WHERE student_code = $1`,
      [studentCode]
    );
    if (existing.rowCount) {
      return res.status(409).json({ message: "studentCode already exists" });
    }
    const { rows } = await pool.query(
      `INSERT INTO students (name, student_code, email)
       VALUES ($1, $2, $3) RETURNING id, name, student_code, email`,
      [name, studentCode, email ?? null]
    );
    const r = rows[0];
    res.status(201).json({
      student: {
        id: r.id,
        name: r.name,
        studentCode: r.student_code,
        email: r.email,
        faceCount: 0,
        enrolled: false,
      },
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
});

// DELETE /api/students/:id
router.delete("/:id", staff, async (req, res) => {
  try {
    const { rowCount } = await pool.query(`DELETE FROM students WHERE id = $1`, [
      req.params.id,
    ]);
    if (!rowCount) return res.status(404).json({ message: "Not found" });
    res.json({ message: "Deleted" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
});

// POST /api/students/:id/faces  { descriptor: number[128] }  — enroll a face sample
router.post("/:id/faces", staff, async (req, res) => {
  try {
    const { descriptor } = req.body;
    if (!isValidDescriptor(descriptor)) {
      return res
        .status(400)
        .json({ message: "descriptor must be an array of 128 numbers" });
    }
    const student = await pool.query(`SELECT id FROM students WHERE id = $1`, [
      req.params.id,
    ]);
    if (!student.rowCount) {
      return res.status(404).json({ message: "Student not found" });
    }
    await pool.query(
      `INSERT INTO face_descriptors (student_id, descriptor) VALUES ($1, $2)`,
      [req.params.id, descriptor]
    );
    const { rows } = await pool.query(
      `SELECT COUNT(*)::int AS n FROM face_descriptors WHERE student_id = $1`,
      [req.params.id]
    );
    res.status(201).json({ message: "Face enrolled", faceCount: rows[0].n });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
});

// DELETE /api/students/:id/faces  — clear a student's enrollment
router.delete("/:id/faces", staff, async (req, res) => {
  try {
    await pool.query(`DELETE FROM face_descriptors WHERE student_id = $1`, [
      req.params.id,
    ]);
    res.json({ message: "Enrollment cleared" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
});

export default router;
