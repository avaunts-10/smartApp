import express from "express";
import pool from "../db.js";
import { requireAuth } from "../middleware/auth.js";
import { SENSORS } from "../sensors.js";

const router = express.Router();
router.use(requireAuth);

const LABELS = {
  temperature: "Temperature",
  humidity: "Humidity",
  air_quality: "Air Quality",
  light: "Light",
  noise: "Noise",
};

// GET /api/environment/latest -> newest reading per sensor type
router.get("/latest", async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT DISTINCT ON (type) type, value, unit, status, created_at
       FROM sensor_readings
       ORDER BY type, created_at DESC`
    );

    const sensors = rows.map((r) => ({
      type: r.type,
      label: LABELS[r.type] ?? r.type,
      value: r.value,
      unit: r.unit,
      status: r.status,
      updatedAt: r.created_at,
    }));

    const updatedAt = rows.reduce(
      (max, r) => (r.created_at > max ? r.created_at : max),
      rows[0]?.created_at ?? null
    );

    res.json({ updatedAt, sensors });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
});

// GET /api/environment/history?minutes=20 -> time series per sensor type
router.get("/history", async (req, res) => {
  try {
    const minutes = Math.min(
      120,
      Math.max(5, parseInt(req.query.minutes, 10) || 20)
    );

    const { rows } = await pool.query(
      `SELECT type, value,
              EXTRACT(EPOCH FROM (now() - created_at)) / 60 AS minutes_ago
       FROM sensor_readings
       WHERE created_at > now() - ($1 || ' minutes')::interval
       ORDER BY created_at ASC`,
      [minutes]
    );

    const series = {};
    for (const key of Object.keys(SENSORS)) series[key] = [];
    for (const r of rows) {
      if (!series[r.type]) continue;
      series[r.type].push({
        // x on a 0..minutes axis where 0 = oldest, `minutes` = now
        t: Math.max(0, Math.round((minutes - r.minutes_ago) * 10) / 10),
        value: r.value,
      });
    }

    res.json({ minutes, series });
  } catch (err) {
    console.error(err);
    res.status(500).json({ message: "Server error" });
  }
});

export default router;
