-- Environmental sensor readings. Populated by src/sensors.js (a simulator, since
-- there is no real IoT hardware). Read via /api/environment/latest and /history.
--   psql -U postgres -d smartapp -f backend/sql/sensors.sql

CREATE TABLE IF NOT EXISTS sensor_readings (
  id         SERIAL PRIMARY KEY,
  type       TEXT NOT NULL,          -- temperature | humidity | air_quality | light | noise
  value      DOUBLE PRECISION NOT NULL,
  unit       TEXT NOT NULL,
  status     TEXT NOT NULL DEFAULT 'normal',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS sensor_readings_type_time
  ON sensor_readings (type, created_at DESC);
