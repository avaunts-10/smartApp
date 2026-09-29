import express from "express";
import pool from "../db.js";
import { getIO } from "../socket.js";

const router = express.Router();

const SENSOR_CONFIG = {
  temperature: {
    unit: "°C",
    warnAbove: 26,
  },
  humidity: {
    unit: "%",
    warnAbove: 70,
  },
  air_quality: {
    unit: "PPM",
    warnAbove: 450,
  },
  light: {
    unit: "Lux",
    warnAbove: null,
  },
};

function getStatus(type, value) {
  const config = SENSOR_CONFIG[type];

  if (!config) {
    return "normal";
  }

  if (config.warnAbove !== null && value > config.warnAbove) {
    return "warning";
  }

  return "normal";
}

router.post("/readings", async (req, res) => {
  try {
    const {
      temperature,
      humidity,
      air_quality,
      light,
    } = req.body;

    const readings = [
      {
        type: "temperature",
        value: temperature,
      },
      {
        type: "humidity",
        value: humidity,
      },
      {
        type: "air_quality",
        value: air_quality,
      },
      {
        type: "light",
        value: light,
      },
    ];

    const savedReadings = [];

    for (const reading of readings) {
      if (
        reading.value === undefined ||
        reading.value === null ||
        Number.isNaN(Number(reading.value))
      ) {
        continue;
      }

      const config = SENSOR_CONFIG[reading.type];
      const value = Number(reading.value);
      const status = getStatus(reading.type, value);

      const result = await pool.query(
        `INSERT INTO sensor_readings
          (type, value, unit, status, created_at)
         VALUES ($1, $2, $3, $4, NOW())
         RETURNING type, value, unit, status, created_at`,
        [
          reading.type,
          value,
          config.unit,
          status,
        ]
      );

      const saved = result.rows[0];

      const formattedReading = {
        type: saved.type,
        value: Number(saved.value),
        unit: saved.unit,
        status: saved.status,
        updatedAt: saved.created_at,
      };

      savedReadings.push(formattedReading);

      // Send the real reading immediately to Flutter
      const io = getIO();

      if (io) {
        io.emit("sensorData", formattedReading);
      }
    }

    res.json({
      success: true,
      readings: savedReadings,
    });
  } catch (err) {
    console.error("Sensor reading error:", err);

    res.status(500).json({
      success: false,
      message: "Failed to save sensor readings",
    });
  }
});

export default router;