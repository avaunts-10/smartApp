// Environmental sensor simulator.
//
// There is no real IoT hardware wired to this project, so this module keeps the
// `sensor_readings` table populated with believable, slowly-drifting values:
// one reading per sensor type every 20 seconds. The API just reads that table.

import pool from "./db.js";
import { getIO } from "./socket.js";

export const SENSORS = {
  temperature: { unit: "°C", base: 24, spread: 1.6, warnAbove: 26 },
  humidity: { unit: "%", base: 52, spread: 6, warnAbove: 70 },
  air_quality: { unit: "PPM", base: 390, spread: 45, warnAbove: 450 },
  light: { unit: "Lux", base: 340, spread: 70, warnAbove: null },
  noise: { unit: "dB", base: 44, spread: 9, warnAbove: 60 },
};

const TICK_MS = 20_000;
const HISTORY_MINUTES = 20;

const round1 = (n) => Math.round(n * 10) / 10;

function statusFor(type, value) {
  const w = SENSORS[type].warnAbove;
  return w != null && value > w ? "warning" : "normal";
}

// Mean-reverting random walk: drift a little, but pull back toward `base`.
function nextValue(type, prev) {
  const { base, spread } = SENSORS[type];
  const drift = (Math.random() - 0.5) * spread * 0.6;
  const pull = (base - prev) * 0.25;
  return round1(prev + drift + pull);
}

async function insert(type, value, createdAt) {
  const { unit } = SENSORS[type];
  const status = statusFor(type, value);

  const result = await pool.query(
    `INSERT INTO sensor_readings (type, value, unit, status, created_at)
     VALUES ($1, $2, $3, $4, COALESCE($5, now()))
     RETURNING type, value, unit, status, created_at`,
    [type, value, unit, status, createdAt ?? null]
  );

  const reading = result.rows[0];

  const io = getIO();

  if (io && !createdAt) {
    io.emit("sensorData", {
      type: reading.type,
      value: Number(reading.value),
      unit: reading.unit,
      status: reading.status,
      updatedAt: reading.created_at,
    });
  }
}

async function lastValue(type) {
  const { rows } = await pool.query(
    `SELECT value FROM sensor_readings WHERE type = $1
     ORDER BY created_at DESC LIMIT 1`,
    [type]
  );
  return rows[0]?.value ?? SENSORS[type].base;
}

async function seedHistoryIfEmpty() {
  const { rows } = await pool.query(
    `SELECT COUNT(*)::int AS n FROM sensor_readings
     WHERE created_at > now() - interval '${HISTORY_MINUTES} minutes'`
  );
  if (rows[0].n >= Object.keys(SENSORS).length * 10) return;

  for (const type of Object.keys(SENSORS)) {
    let v = SENSORS[type].base + (Math.random() - 0.5) * SENSORS[type].spread;
    for (let m = HISTORY_MINUTES; m >= 0; m--) {
      v = nextValue(type, v);
      const when = new Date(Date.now() - m * 60_000);
      await insert(type, round1(v), when);
    }
  }
  console.log("🌡️  seeded sensor history");
}

async function tick() {
  try {
    for (const type of Object.keys(SENSORS)) {
      const prev = await lastValue(type);
      await insert(type, nextValue(type, prev));
    }
    await pool.query(
      `DELETE FROM sensor_readings WHERE created_at < now() - interval '2 hours'`
    );
  } catch (err) {
    console.error("sensor tick failed:", err.message);
  }
}

export async function startSensorSimulator() {
  try {
    await seedHistoryIfEmpty();
    await tick();
  } catch (err) {
    console.error("sensor simulator start failed:", err.message);
  }
  setInterval(tick, TICK_MS);
}
