// RFID attendance.
//
//   Hardware  -> POST /api/rfid/scan            (X-Device-Key header)
//   Staff app -> GET/PUT/DELETE /api/rfid/cards (normal user login)
//
// A scan marks attendance with method 'rfid', using the same present/late
// rules as face recognition. The Device Control screen's RFID panel already
// reads those records from GET /api/attendance.

import express from "express";
import pool from "../db.js";
import { getIO } from "../socket.js";
import { requireAuth, requireRole } from "../middleware/auth.js";
import { requireDevice } from "../middleware/deviceAuth.js";
import {
  activeAttendanceClass,
  attendanceStatus,
  todayISO,
} from "./attendance.routes.js";

const router = express.Router();
const staff = [requireAuth, requireRole("admin", "teacher")];

// Readers print UIDs in different styles ("04:a3:2b:1c", "04 A3 2B 1C",
// "04A32B1C"). Store one form: uppercase hex, no separators. Cards use 4, 7 or
// 10 byte UIDs, i.e. 8, 14 or 20 hex characters.
export function normalizeUid(raw) {
  if (typeof raw !== "string") return null;
  const hex = raw.replace(/[^0-9a-f]/gi, "").toUpperCase();
  return [8, 14, 20].includes(hex.length) ? hex : null;
}

// POST /api/rfid/scan  { uid, readerId? }
// Always answers 200 for a well-formed scan; `result` tells the reader what
// happened so it can beep / light an LED:
//   marked | already_marked | unknown_card
router.post("/scan", requireDevice, async (req, res) => {
  try {
    const uid = normalizeUid(req.body?.uid);
    if (!uid) {
      return res
        .status(400)
        .json({ message: "uid must be 4, 7 or 10 bytes of hex" });
    }
    const readerId = req.body?.readerId || "rfid_reader";

    // Any scan proves the reader is alive.
    await pool.query(
      `UPDATE devices SET online = true, updated_at = now()
       WHERE id = $1 AND device_type = 'rfid'`,
      [readerId]
    );

    const { rows } = await pool.query(
      `SELECT id, name, student_code FROM students WHERE rfid_uid = $1`,
      [uid]
    );
    const student = rows[0];

    let payload;
    if (!student) {
      payload = { result: "unknown_card", uid };
    } else {
      const now = new Date();
      const activeClass = await activeAttendanceClass(now);
      const status = attendanceStatus(activeClass, now);
      const insert = await pool.query(
        `INSERT INTO attendance_records
         (student_id, method, status, session_date, booking_id)
         VALUES ($1, 'rfid', $2, $3, $4)
         ON CONFLICT DO NOTHING
         RETURNING id`,
        [student.id, status, todayISO(), activeClass?.id ?? null]
      );
      payload = {
        result: insert.rowCount ? "marked" : "already_marked",
        uid,
        student: { name: student.name, studentCode: student.student_code },
        status,
        classTitle: activeClass?.title ?? null,
      };
    }

    getIO()?.emit("rfidScan", { ...payload, readerId, at: new Date() });
    res.json(payload);
  } catch (err) {
    console.error("POST /api/rfid/scan ERROR:", err);
    res.status(500).json({ message: "Could not process RFID scan" });
  }
});

// GET /api/rfid/cards -> students and their linked card (null if none)
router.get("/cards", staff, async (_req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT id, name, student_code, rfid_uid FROM students ORDER BY name`
    );
    res.json({
      students: rows.map((r) => ({
        id: r.id,
        name: r.name,
        studentCode: r.student_code,
        rfidUid: r.rfid_uid,
      })),
    });
  } catch (err) {
    console.error("GET /api/rfid/cards ERROR:", err);
    res.status(500).json({ message: "Could not load RFID cards" });
  }
});

// PUT /api/rfid/cards/:studentId  { uid } -> link a card to a student
router.put("/cards/:studentId", staff, async (req, res) => {
  try {
    const uid = normalizeUid(req.body?.uid);
    if (!uid) {
      return res
        .status(400)
        .json({ message: "uid must be 4, 7 or 10 bytes of hex" });
    }
    const { rows } = await pool.query(
      `UPDATE students SET rfid_uid = $1 WHERE id = $2
       RETURNING id, name, student_code, rfid_uid`,
      [uid, req.params.studentId]
    );
    if (!rows.length) {
      return res.status(404).json({ message: "Student not found" });
    }
    const s = rows[0];
    res.json({
      student: {
        id: s.id,
        name: s.name,
        studentCode: s.student_code,
        rfidUid: s.rfid_uid,
      },
    });
  } catch (err) {
    if (err.code === "23505") {
      return res
        .status(409)
        .json({ message: "This card is already linked to another student" });
    }
    console.error("PUT /api/rfid/cards ERROR:", err);
    res.status(500).json({ message: "Could not link RFID card" });
  }
});

// DELETE /api/rfid/cards/:studentId -> unlink (lost card, etc.)
router.delete("/cards/:studentId", staff, async (req, res) => {
  try {
    const { rowCount } = await pool.query(
      `UPDATE students SET rfid_uid = NULL WHERE id = $1`,
      [req.params.studentId]
    );
    if (!rowCount) {
      return res.status(404).json({ message: "Student not found" });
    }
    res.json({ message: "Card unlinked" });
  } catch (err) {
    console.error("DELETE /api/rfid/cards ERROR:", err);
    res.status(500).json({ message: "Could not unlink RFID card" });
  }
});

export default router;
