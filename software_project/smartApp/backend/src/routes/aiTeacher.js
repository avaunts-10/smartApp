import express from "express";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import pool from "../db.js";
import { requireAuth } from "../middleware/auth.js";

const router = express.Router();

/* ---- teacher roster: one named teacher per subject -----------------------
   Shared with the 3D page (served statically at /teacher3d/teachers.json), so
   the avatar, voice and the AI persona always agree. Re-read on every request
   so edits take effect without a restart (it is a tiny file).             */
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROSTER_PATH = path.join(__dirname, "..", "..", "public_teacher3d", "teachers.json");

function loadRoster() {
  try {
    const r = JSON.parse(fs.readFileSync(ROSTER_PATH, "utf8"));
    delete r._comment;
    return r;
  } catch (e) {
    console.error("teachers.json unreadable:", e.message);
    return {};
  }
}

// case-insensitive lookup; unknown subjects get the General teacher
// `gender` picks which of the subject's two characters (female/male) is
// speaking — the roster entry's own fields, or its `alt` when the student has
// switched to the other one. Falls back to the default character when the
// requested gender has no `alt` defined, or none was requested.
function teacherFor(subject, gender) {
  const roster = loadRoster();
  const key = Object.keys(roster).find((k) => k.toLowerCase() === subject.toLowerCase());
  const t = roster[key] || roster.General || { name: "the AI teacher", style: "clear and friendly" };
  const alt = t.alt;
  const g = (gender || "").toLowerCase();
  const merged = alt && alt.gender === g && g !== t.gender ? { ...t, ...alt } : t;
  return { subject: key || subject, ...merged };
}

// GET /api/ai/teachers -> { teachers:[{subject,name,title,gender,accent,avatar,greeting}] }
router.get("/teachers", requireAuth, (_req, res) => {
  const roster = loadRoster();
  res.json({
    teachers: Object.entries(roster).map(([subject, t]) => ({
      subject,
      name: t.name,
      title: t.title,
      gender: t.gender,
      accent: t.accent,
      avatar: t.avatar,
      greeting: t.greeting,
      // the subject's other character (female/male), if the roster defines one
      alt: t.alt
        ? {
            name: t.alt.name,
            title: t.alt.title || t.title,
            gender: t.alt.gender,
            avatar: t.alt.avatar,
            greeting: t.alt.greeting,
          }
        : null,
    })),
  });
});

// Configurable so you can swap models/host without touching code.
const OLLAMA_URL = process.env.OLLAMA_URL || "http://127.0.0.1:11434";
const OLLAMA_MODEL = process.env.OLLAMA_MODEL || "gemma3:4b";

// GET /api/ai/sessions -> one row per subject the user has chatted about
router.get("/sessions", requireAuth, async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT DISTINCT ON (subject)
              subject,
              content     AS last_message,
              created_at  AS updated_at,
              (SELECT COUNT(*)::int FROM chat_messages c2
                 WHERE c2.user_id = c.user_id AND c2.subject = c.subject) AS count
       FROM chat_messages c
       WHERE user_id = $1
       ORDER BY subject, created_at DESC`,
      [String(req.user.id)]
    );
    rows.sort((a, b) => new Date(b.updated_at) - new Date(a.updated_at));
    res.json({
      sessions: rows.map((r) => ({
        subject: r.subject,
        lastMessage: r.last_message,
        count: r.count,
        updatedAt: r.updated_at,
      })),
    });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: "Server error" });
  }
});

// GET /api/ai/history?subject=Mathematics -> { messages:[{role,content,createdAt}] }
router.get("/history", requireAuth, async (req, res) => {
  try {
    const subject = (req.query.subject || "General").toString();
    const { rows } = await pool.query(
      `SELECT role, content, created_at FROM chat_messages
       WHERE user_id = $1 AND subject = $2
       ORDER BY created_at ASC, id ASC`,
      [String(req.user.id), subject]
    );
    res.json({
      messages: rows.map((r) => ({
        role: r.role,
        content: r.content,
        createdAt: r.created_at,
      })),
    });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: "Server error" });
  }
});

// DELETE /api/ai/history?subject=Mathematics -> clears that subject's history
router.delete("/history", requireAuth, async (req, res) => {
  try {
    const subject = (req.query.subject || "General").toString();
    await pool.query(
      `DELETE FROM chat_messages WHERE user_id = $1 AND subject = $2`,
      [String(req.user.id), subject]
    );
    res.json({ message: "Cleared" });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: "Server error" });
  }
});

router.post("/teacher", requireAuth, async (req, res) => {
  try {
    const { message, roomId, schedule, gender } = req.body;
    const subject = (req.body.subject || "General").toString();
    if (!message || !message.trim()) {
      return res.status(400).json({ error: "message is required" });
    }

    const t = teacherFor(subject, gender);
    const prompt = `
You are ${t.name}, the ${t.subject} teacher in a smart classroom.
Teaching style: ${t.style}.
Stay in character as ${t.name}. Do not introduce yourself unless the student asks who you are.
Keep the answer focused on ${t.subject}; if the question belongs to another subject, answer briefly and suggest asking that subject's teacher.
Your answer is read aloud by a 3D avatar, so use plain spoken language: no markdown, no headings, no bullet symbols. Keep it under 120 words unless the student asks for more detail.
Room: ${roomId || "unknown"}
Schedule: ${schedule ? JSON.stringify(schedule) : "not provided"}

Student question: ${message}
`;

    const r = await fetch(`${OLLAMA_URL}/api/generate`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ model: OLLAMA_MODEL, prompt, stream: false }),
    });

    if (!r.ok) {
      const t = await r.text();
      return res
        .status(502)
        .json({ error: `Ollama error (${r.status}): ${t.slice(0, 200)}` });
    }

    const data = await r.json();
    const reply = data.response;

    // Persist the turn (best-effort — a DB hiccup must not lose the reply).
    try {
      await pool.query(
        `INSERT INTO chat_messages (user_id, subject, role, content)
         VALUES ($1, $2, 'user', $3), ($1, $2, 'ai', $4)`,
        [String(req.user.id), subject, message, reply]
      );
    } catch (dbErr) {
      console.error("chat history save failed:", dbErr);
    }

    return res.json({ reply, teacher: { subject: t.subject, name: t.name } });
  } catch (e) {
    console.error(e);
    return res.status(502).json({
      error: "Cannot reach the AI model. Is Ollama running?",
    });
  }
});

export default router;
