import express from "express";
import pool from "../db.js";
import { requireAuth, requireRole } from "../middleware/auth.js";

const router = express.Router();
router.use(requireAuth);

const staff = requireRole("admin", "teacher");
const OPTIONS = ["A", "B", "C", "D"];

function toQuiz(r) {
  return {
    id: r.id,
    subjectId: r.subject_id,
    title: r.title,
    description: r.description,
    createdBy: r.created_by,
    createdAt: r.created_at,
  };
}

function toQuestion(r, hideAnswer) {
  const q = {
    id: r.id,
    quizId: r.quiz_id,
    questionText: r.question_text,
    optionA: r.option_a,
    optionB: r.option_b,
    optionC: r.option_c,
    optionD: r.option_d,
    sortOrder: r.sort_order,
  };
  if (!hideAnswer) q.correctOption = r.correct_option;
  return q;
}

function validQuestionPayload(q) {
  return (
    q &&
    typeof q.question_text === "string" &&
    q.question_text.trim() &&
    typeof q.option_a === "string" &&
    q.option_a.trim() &&
    typeof q.option_b === "string" &&
    q.option_b.trim() &&
    typeof q.option_c === "string" &&
    q.option_c.trim() &&
    typeof q.option_d === "string" &&
    q.option_d.trim() &&
    OPTIONS.includes(q.correct_option)
  );
}

// GET /api/quizzes?subject_id=...
router.get("/", async (req, res) => {
  try {
    const { subject_id } = req.query;
    const isStudent = req.user.role === "student";
    const where = subject_id ? "WHERE q.subject_id = $1" : "";
    const params = subject_id ? [subject_id] : [];

    if (isStudent) {
      params.push(req.user.id);
      const { rows } = await pool.query(
        `SELECT q.*,
                (SELECT COUNT(*)::int FROM quiz_questions qq WHERE qq.quiz_id = q.id) AS question_count,
                a.score AS my_score, a.total AS my_total, a.submitted_at AS my_submitted_at
         FROM quizzes q
         LEFT JOIN quiz_attempts a ON a.quiz_id = q.id AND a.student_id = $${params.length}
         ${where}
         ORDER BY q.created_at DESC`,
        params
      );
      res.json({
        quizzes: rows.map((r) => ({
          ...toQuiz(r),
          questionCount: r.question_count,
          attempted: r.my_score !== null,
          myScore: r.my_score,
          myTotal: r.my_total,
          mySubmittedAt: r.my_submitted_at,
        })),
      });
    } else {
      const { rows } = await pool.query(
        `SELECT q.*,
                (SELECT COUNT(*)::int FROM quiz_questions qq WHERE qq.quiz_id = q.id) AS question_count,
                (SELECT COUNT(*)::int FROM quiz_attempts qa WHERE qa.quiz_id = q.id) AS attempt_count
         FROM quizzes q
         ${where}
         ORDER BY q.created_at DESC`,
        params
      );
      res.json({
        quizzes: rows.map((r) => ({
          ...toQuiz(r),
          questionCount: r.question_count,
          attemptCount: r.attempt_count,
        })),
      });
    }
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
});

// POST /api/quizzes (teacher only)
// { subject_id, title, description?, questions: [{question_text, option_a..d, correct_option}] }
router.post("/", requireRole("teacher"), async (req, res) => {
  const { subject_id, title, description, questions } = req.body;
  if (!subject_id || !title || !Array.isArray(questions) || !questions.length) {
    return res.status(400).json({
      message: "subject_id, title, and at least one question are required",
    });
  }
  if (!questions.every(validQuestionPayload)) {
    return res.status(400).json({
      message:
        "Each question needs question_text, option_a..option_d, and a correct_option of A/B/C/D",
    });
  }

  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const { rows } = await client.query(
      `INSERT INTO quizzes (subject_id, title, description, created_by)
       VALUES ($1, $2, $3, $4) RETURNING *`,
      [subject_id, title, description || null, req.user.id]
    );
    const quiz = rows[0];

    let order = 0;
    for (const q of questions) {
      await client.query(
        `INSERT INTO quiz_questions
           (quiz_id, question_text, option_a, option_b, option_c, option_d, correct_option, sort_order)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
        [
          quiz.id,
          q.question_text,
          q.option_a,
          q.option_b,
          q.option_c,
          q.option_d,
          q.correct_option,
          order++,
        ]
      );
    }

    await client.query("COMMIT");
    res
      .status(201)
      .json({ quiz: { ...toQuiz(quiz), questionCount: questions.length } });
  } catch (err) {
    await client.query("ROLLBACK");
    console.error(err);
    res.status(500).json({ message: "Server error" });
  } finally {
    client.release();
  }
});

// GET /api/quizzes/:id — full detail + questions (answers hidden from students)
router.get("/:id", async (req, res) => {
  try {
    const { rows: quizRows } = await pool.query(
      `SELECT * FROM quizzes WHERE id = $1`,
      [req.params.id]
    );
    if (!quizRows.length) return res.status(404).json({ message: "Not found" });

    const { rows: qRows } = await pool.query(
      `SELECT * FROM quiz_questions WHERE quiz_id = $1 ORDER BY sort_order, id`,
      [req.params.id]
    );

    const isStudent = req.user.role === "student";
    res.json({
      quiz: toQuiz(quizRows[0]),
      questions: qRows.map((q) => toQuestion(q, isStudent)),
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
});

// GET /api/quizzes/:id/results (teacher/admin only)
router.get("/:id/results", staff, async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT a.id, a.student_id, u.email AS student_email, a.score, a.total, a.submitted_at
       FROM quiz_attempts a
       JOIN users u ON u.id = a.student_id
       WHERE a.quiz_id = $1
       ORDER BY a.submitted_at DESC`,
      [req.params.id]
    );
    res.json({
      results: rows.map((r) => ({
        attemptId: r.id,
        studentId: r.student_id,
        studentEmail: r.student_email,
        score: r.score,
        total: r.total,
        submittedAt: r.submitted_at,
      })),
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
});

// POST /api/quizzes/:id/submit (student only)  body: [{question_id, selected_option}]
router.post("/:id/submit", requireRole("student"), async (req, res) => {
  try {
    const quizId = req.params.id;
    const answers = req.body;
    if (!Array.isArray(answers) || !answers.length) {
      return res.status(400).json({
        message: "Body must be a non-empty array of {question_id, selected_option}",
      });
    }
    for (const a of answers) {
      if (!a || !a.question_id || !OPTIONS.includes(a.selected_option)) {
        return res.status(400).json({
          message: "Each answer needs question_id and selected_option (A-D)",
        });
      }
    }

    const existing = await pool.query(
      `SELECT id FROM quiz_attempts WHERE quiz_id = $1 AND student_id = $2`,
      [quizId, req.user.id]
    );
    if (existing.rowCount) {
      return res
        .status(409)
        .json({ message: "You have already attempted this quiz" });
    }

    const { rows: qRows } = await pool.query(
      `SELECT id, correct_option FROM quiz_questions WHERE quiz_id = $1`,
      [quizId]
    );
    if (!qRows.length) {
      return res.status(404).json({ message: "Quiz not found" });
    }
    const correctById = new Map(qRows.map((q) => [q.id, q.correct_option]));

    let score = 0;
    const graded = [];
    for (const a of answers) {
      const correct = correctById.get(a.question_id);
      if (correct === undefined) {
        return res.status(400).json({
          message: `question_id ${a.question_id} does not belong to this quiz`,
        });
      }
      const isCorrect = correct === a.selected_option;
      if (isCorrect) score++;
      graded.push({
        questionId: a.question_id,
        selectedOption: a.selected_option,
        isCorrect,
        correctOption: correct,
      });
    }
    const total = qRows.length;

    const client = await pool.connect();
    try {
      await client.query("BEGIN");
      const { rows: attemptRows } = await client.query(
        `INSERT INTO quiz_attempts (quiz_id, student_id, score, total)
         VALUES ($1, $2, $3, $4) RETURNING *`,
        [quizId, req.user.id, score, total]
      );
      const attempt = attemptRows[0];

      for (const g of graded) {
        await client.query(
          `INSERT INTO quiz_answers (attempt_id, question_id, selected_option, is_correct)
           VALUES ($1, $2, $3, $4)`,
          [attempt.id, g.questionId, g.selectedOption, g.isCorrect]
        );
      }

      await client.query("COMMIT");
      res.status(201).json({
        score,
        total,
        submittedAt: attempt.submitted_at,
        answers: graded,
      });
    } catch (err) {
      await client.query("ROLLBACK");
      if (err.code === "23505") {
        return res
          .status(409)
          .json({ message: "You have already attempted this quiz" });
      }
      throw err;
    } finally {
      client.release();
    }
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
});

// DELETE /api/quizzes/:id (teacher/admin only) — cascades to questions/attempts/answers
router.delete("/:id", staff, async (req, res) => {
  try {
    const { rowCount } = await pool.query(`DELETE FROM quizzes WHERE id = $1`, [
      req.params.id,
    ]);
    if (!rowCount) return res.status(404).json({ message: "Not found" });
    res.json({ message: "Deleted" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
});

export default router;
