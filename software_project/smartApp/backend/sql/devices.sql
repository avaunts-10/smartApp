-- The /api/devices routes (src/routes/device.routes.js) use a raw pg pool and
-- expect this table. It is NOT managed by Prisma. Run once against the smartapp DB:
--   psql -U postgres -d smartapp -f backend/sql/devices.sql

CREATE TABLE IF NOT EXISTS devices (
  id           TEXT PRIMARY KEY,
  title        TEXT NOT NULL,
  is_on        BOOLEAN NOT NULL DEFAULT false,
  slider_value INTEGER
);

INSERT INTO devices (id, title, is_on, slider_value) VALUES
  ('main_lights',      'Main Lights',      true,  80),
  ('board_lights',     'Board Lights',     true,  100),
  ('projector',        'Projector',        false, NULL),
  ('hvac',             'HVAC System',      true,  22),
  ('audio',            'Audio System',     false, NULL),
  ('emergency_lights', 'Emergency Lights', true,  50)
ON CONFLICT (id) DO NOTHING;
