import express from "express";
import pool from "../db.js";
import { requireAuth, requireRole } from "../middleware/auth.js";

const router = express.Router();
router.use(requireAuth);

const staff = requireRole("admin", "teacher");
const AUTOMATION_TICK_MS = 30_000;

function minuteOfDay(date) {
  return date.getHours() * 60 + date.getMinutes();
}

function scheduleState(row, now = new Date()) {
  if (!row.enabled) return "disabled";
  const day = now.getDay();
  const minute = minuteOfDay(now);
  if (row.weekday === day && minute >= row.start_minute && minute < row.end_minute) {
    return "active";
  }
  return "scheduled";
}

function toBooking(row, now = new Date()) {
  return {
    id: row.id,
    title: row.title,
    teacher: row.teacher,
    room: row.room,
    weekday: row.weekday,
    startMinute: row.start_minute,
    endMinute: row.end_minute,
    // Retained for the existing dashboard preview.
    startHour: Math.floor(row.start_minute / 60),
    endHour: Math.ceil(row.end_minute / 60),
    enabled: row.enabled,
    automationEnabled: row.automation_enabled,
    fanMode: row.fan_mode,
    fanSpeed: row.fan_speed,
    targetTemperature: Number(row.target_temperature),
    lightOn: row.light_on,
    lightBrightness: row.light_brightness,
    attendanceEnabled: row.attendance_enabled,
    attendanceGraceMinutes: row.attendance_grace_minutes,
    state: scheduleState(row, now),
  };
}

function parseBooking(body) {
  const title = body.title?.toString().trim();
  const teacher = body.teacher?.toString().trim();
  const room = body.room?.toString().trim() || "Room 301";
  const weekday = Number(body.weekday);
  const startMinute = Number(body.startMinute);
  const endMinute = Number(body.endMinute);
  const fanMode = body.fanMode?.toString() || "auto";
  const fanSpeed = Number(body.fanSpeed ?? 2);
  const targetTemperature = Number(body.targetTemperature ?? 26);
  const lightBrightness = Number(body.lightBrightness ?? 80);
  const attendanceGraceMinutes = Number(body.attendanceGraceMinutes ?? 10);

  if (!title || !teacher) throw new Error("Class name and teacher are required");
  if (!Number.isInteger(weekday) || weekday < 1 || weekday > 5) {
    throw new Error("Select a weekday from Monday to Friday");
  }
  if (
    !Number.isInteger(startMinute) ||
    !Number.isInteger(endMinute) ||
    startMinute < 0 ||
    endMinute > 1440 ||
    endMinute <= startMinute
  ) {
    throw new Error("End time must be after start time");
  }
  if (startMinute % 30 !== 0 || endMinute % 30 !== 0) {
    throw new Error("Class times must use 30-minute intervals");
  }
  if (!["off", "on", "auto"].includes(fanMode)) {
    throw new Error("Invalid fan mode");
  }
  if (!Number.isInteger(fanSpeed) || fanSpeed < 1 || fanSpeed > 3) {
    throw new Error("Fan speed must be between 1 and 3");
  }
  if (targetTemperature < 16 || targetTemperature > 32) {
    throw new Error("Target temperature must be between 16 and 32°C");
  }
  if (!Number.isInteger(lightBrightness) || lightBrightness < 0 || lightBrightness > 100) {
    throw new Error("Light brightness must be between 0 and 100");
  }
  if (
    !Number.isInteger(attendanceGraceMinutes) ||
    attendanceGraceMinutes < 0 ||
    attendanceGraceMinutes > 60
  ) {
    throw new Error("Attendance grace period must be between 0 and 60 minutes");
  }

  return {
    title,
    teacher,
    room,
    weekday,
    startMinute,
    endMinute,
    enabled: body.enabled !== false,
    automationEnabled: body.automationEnabled !== false,
    fanMode,
    fanSpeed,
    targetTemperature,
    lightOn: body.lightOn !== false,
    lightBrightness,
    attendanceEnabled: body.attendanceEnabled !== false,
    attendanceGraceMinutes,
  };
}

async function findConflict(data, excludeId = null) {
  const { rows } = await pool.query(
    `SELECT id, title, teacher, room
     FROM bookings
     WHERE enabled = true
       AND weekday = $1
       AND id <> COALESCE($6, -1)
       AND start_minute < $3
       AND end_minute > $2
       AND (LOWER(room) = LOWER($4) OR LOWER(teacher) = LOWER($5))
     LIMIT 1`,
    [
      data.weekday,
      data.startMinute,
      data.endMinute,
      data.room,
      data.teacher,
      excludeId,
    ]
  );
  return rows[0] ?? null;
}

const bookingValues = (data) => [
  data.title,
  data.teacher,
  data.room,
  data.weekday,
  data.startMinute,
  data.endMinute,
  data.enabled,
  data.automationEnabled,
  data.fanMode,
  data.fanSpeed,
  data.targetTemperature,
  data.lightOn,
  data.lightBrightness,
  data.attendanceEnabled,
  data.attendanceGraceMinutes,
];

router.get("/", async (_req, res) => {
  try {
    const now = new Date();
    const { rows } = await pool.query(
      `SELECT * FROM bookings ORDER BY weekday, start_minute`
    );
    res.json({ serverTime: now, bookings: rows.map((row) => toBooking(row, now)) });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Could not load class schedule" });
  }
});

router.post("/automation/sync", staff, async (_req, res) => {
  try {
    const result = await syncScheduleAutomation();
    res.json(result);
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Could not synchronize classroom devices" });
  }
});

router.post("/", staff, async (req, res) => {
  try {
    const data = parseBooking(req.body);
    const conflict = await findConflict(data);
    if (conflict) {
      return res.status(409).json({
        message: `Conflicts with ${conflict.title} (${conflict.teacher}, ${conflict.room})`,
      });
    }
    const { rows } = await pool.query(
      `INSERT INTO bookings
       (title, teacher, room, weekday, start_minute, end_minute, enabled,
        automation_enabled, fan_mode, fan_speed, target_temperature, light_on,
        light_brightness, attendance_enabled, attendance_grace_minutes)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
       RETURNING *`,
      bookingValues(data)
    );
    res.status(201).json({ booking: toBooking(rows[0]) });
  } catch (err) {
    if (err.message && !err.code) return res.status(400).json({ message: err.message });
    console.error(err);
    res.status(500).json({ message: "Could not create class" });
  }
});

router.patch("/:id", staff, async (req, res) => {
  try {
    const id = Number(req.params.id);
    if (!Number.isInteger(id)) return res.status(400).json({ message: "Invalid class id" });
    const data = parseBooking(req.body);
    const conflict = await findConflict(data, id);
    if (conflict) {
      return res.status(409).json({
        message: `Conflicts with ${conflict.title} (${conflict.teacher}, ${conflict.room})`,
      });
    }
    const { rows } = await pool.query(
      `UPDATE bookings SET
       title=$1, teacher=$2, room=$3, weekday=$4, start_minute=$5, end_minute=$6,
       enabled=$7, automation_enabled=$8, fan_mode=$9, fan_speed=$10,
       target_temperature=$11, light_on=$12, light_brightness=$13,
       attendance_enabled=$14, attendance_grace_minutes=$15
       WHERE id=$16 RETURNING *`,
      [...bookingValues(data), id]
    );
    if (!rows.length) return res.status(404).json({ message: "Class not found" });
    await syncScheduleAutomation();
    res.json({ booking: toBooking(rows[0]) });
  } catch (err) {
    if (err.message && !err.code) return res.status(400).json({ message: err.message });
    console.error(err);
    res.status(500).json({ message: "Could not update class" });
  }
});

router.delete("/:id", staff, async (req, res) => {
  try {
    const { rowCount } = await pool.query(`DELETE FROM bookings WHERE id = $1`, [
      req.params.id,
    ]);
    if (!rowCount) return res.status(404).json({ message: "Class not found" });
    await syncScheduleAutomation();
    res.json({ message: "Deleted" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Could not delete class" });
  }
});

async function activeAutomatedBooking(now = new Date()) {
  const { rows } = await pool.query(
    `SELECT * FROM bookings
     WHERE enabled = true AND automation_enabled = true
       AND weekday = $1 AND start_minute <= $2 AND end_minute > $2
     ORDER BY start_minute LIMIT 1`,
    [now.getDay(), minuteOfDay(now)]
  );
  return rows[0] ?? null;
}

async function updateDevice(id, isOn, sliderValue) {
  await pool.query(
    `UPDATE devices SET is_on=$1, slider_value=$2, updated_at=now()
     WHERE id=$3 AND online=true`,
    [isOn, sliderValue, id]
  );
}

export async function syncScheduleAutomation(now = new Date()) {
  const booking = await activeAutomatedBooking(now);
  const { rows: stateRows } = await pool.query(
    `SELECT active, active_booking_id FROM schedule_automation_state WHERE id=1`
  );
  const previous = stateRows[0] ?? { active: false, active_booking_id: null };

  if (!booking) {
    if (previous.active) {
      await Promise.all([
        updateDevice("fan", false, 1),
        updateDevice("bulb", false, 0),
      ]);
      await pool.query(
        `UPDATE schedule_automation_state
         SET active=false, active_booking_id=NULL, updated_at=now() WHERE id=1`
      );
    }
    return { active: false, message: "No automated class is active" };
  }

  let fanOn = booking.fan_mode === "on";
  let temperature = null;
  if (booking.fan_mode === "auto") {
    const { rows } = await pool.query(
      `SELECT value FROM sensor_readings
       WHERE type='temperature' ORDER BY created_at DESC LIMIT 1`
    );
    temperature = rows[0] ? Number(rows[0].value) : null;
    fanOn = temperature == null || temperature >= Number(booking.target_temperature);
  }

  await Promise.all([
    updateDevice("fan", fanOn, booking.fan_speed),
    updateDevice("bulb", booking.light_on, booking.light_brightness),
  ]);
  await pool.query(
    `UPDATE schedule_automation_state
     SET active=true, active_booking_id=$1, updated_at=now() WHERE id=1`,
    [booking.id]
  );

  return {
    active: true,
    booking: toBooking(booking, now),
    applied: {
      fanOn,
      fanSpeed: booking.fan_speed,
      lightOn: booking.light_on,
      lightBrightness: booking.light_brightness,
      temperature,
    },
  };
}

export function startScheduleAutomation() {
  syncScheduleAutomation().catch((err) =>
    console.error("schedule automation start failed:", err.message)
  );
  setInterval(() => {
    syncScheduleAutomation().catch((err) =>
      console.error("schedule automation tick failed:", err.message)
    );
  }, AUTOMATION_TICK_MS);
}

export default router;
