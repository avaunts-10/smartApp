-- The /api/devices routes (src/routes/device.routes.js) and the schedule
-- automation (src/routes/schedule.routes.js) use a raw pg pool and expect this
-- table. Run once against the smartapp DB:
--   psql -U postgres -d smartapp -f backend/sql/devices.sql
--
-- Schema restored from the Prisma migration 20260919093000_add_devices_and_attendance,
-- which was dropped along with Prisma (d1950c1).
--
-- On a DB that still has the old devices table (main_lights, projector, hvac...
-- without device_type/online/updated_at), this upgrades it in place: the old
-- demo rows can't be controlled by the current routes, so they are replaced
-- with the fan / bulb / RFID reader devices below.

DO $$
BEGIN
  IF to_regclass('devices') IS NOT NULL
     AND NOT EXISTS (
       SELECT 1 FROM information_schema.columns
       WHERE table_schema = current_schema()
         AND table_name = 'devices' AND column_name = 'device_type'
     ) THEN
    DELETE FROM devices;
    ALTER TABLE devices
      ADD COLUMN device_type TEXT NOT NULL,
      ADD COLUMN online      BOOLEAN NOT NULL DEFAULT true,
      ADD COLUMN updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
      ADD CONSTRAINT devices_type_check CHECK (device_type IN ('fan', 'bulb', 'rfid')),
      ADD CONSTRAINT devices_value_check CHECK (
        (device_type = 'fan'  AND slider_value BETWEEN 1 AND 3) OR
        (device_type = 'bulb' AND slider_value BETWEEN 0 AND 100) OR
        (device_type = 'rfid' AND slider_value IS NULL)
      );
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS devices (
  id           TEXT PRIMARY KEY,
  title        TEXT NOT NULL,
  device_type  TEXT NOT NULL,
  is_on        BOOLEAN NOT NULL DEFAULT false,
  slider_value INTEGER,
  online       BOOLEAN NOT NULL DEFAULT true,
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT devices_type_check CHECK (device_type IN ('fan', 'bulb', 'rfid')),
  CONSTRAINT devices_value_check CHECK (
    (device_type = 'fan'  AND slider_value BETWEEN 1 AND 3) OR
    (device_type = 'bulb' AND slider_value BETWEEN 0 AND 100) OR
    (device_type = 'rfid' AND slider_value IS NULL)
  )
);

INSERT INTO devices (id, title, device_type, is_on, slider_value, online) VALUES
  ('fan',         'Classroom Fan',           'fan',  false, 2,    true),
  ('bulb',        'Classroom Light',         'bulb', true,  80,   true),
  ('rfid_reader', 'RFID Attendance Tracker', 'rfid', true,  NULL, true)
ON CONFLICT (id) DO NOTHING;
