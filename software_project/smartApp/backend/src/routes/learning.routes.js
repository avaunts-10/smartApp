import express from "express";
import pool from "../db.js";
import { requireAuth, requireRole } from "../middleware/auth.js";

const router = express.Router();
router.use(requireAuth);

function toSubject(r) {
  return {
    id: r.id,
    name: r.name,
    skillLevel: Number(r.skill_level),
    studyMinutes: r.study_minutes,
    lessonsCompleted: r.lessons_completed,
  };
}

// GET /api/learning/subjects -> { subjects:[...], summary:{...} }
router.get("/subjects", async (_req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT * FROM subjects ORDER BY sort_order, id`
    );
    const subjects = rows.map(toSubject);
    const studied = subjects.filter((s) => s.studyMinutes > 0);
    const totalMin = subjects.reduce((a, s) => a + s.studyMinutes, 0);
    const avgSkill = studied.length
      ? studied.reduce((a, s) => a + s.skillLevel, 0) / studied.length
      : 0;
    res.json({
      subjects,
      summary: {
        totalMinutes: totalMin,
        avgSkill: Math.round(avgSkill * 10) / 10,
        subjectsStudied: studied.length,
        lessonsCompleted: subjects.reduce((a, s) => a + s.lessonsCompleted, 0),
      },
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
});

// PATCH /api/learning/subjects/:id  { skillLevel?, studyMinutes?, lessonsCompleted? }
router.patch("/subjects/:id", requireRole("admin", "teacher"), async (req, res) => {
  try {
    const { skillLevel, studyMinutes, lessonsCompleted } = req.body;
    const { rows } = await pool.query(
      `UPDATE subjects SET
         skill_level       = COALESCE($2, skill_level),
         study_minutes     = COALESCE($3, study_minutes),
         lessons_completed = COALESCE($4, lessons_completed)
       WHERE id = $1 RETURNING *`,
      [
        req.params.id,
        skillLevel ?? null,
        studyMinutes ?? null,
        lessonsCompleted ?? null,
      ]
    );
    if (!rows.length) return res.status(404).json({ message: "Not found" });
    res.json({ subject: toSubject(rows[0]) });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
});

export default router;
