-- Weekly classes and their Smart Classroom IoT presets.
CREATE TABLE IF NOT EXISTS bookings (
  id                       SERIAL PRIMARY KEY,
  title                    TEXT NOT NULL,
  teacher                  TEXT NOT NULL,
  room                     TEXT NOT NULL DEFAULT 'Room 301',
  weekday                  INT NOT NULL CHECK (weekday BETWEEN 1 AND 5),
  start_minute             INT NOT NULL CHECK (start_minute BETWEEN 0 AND 1439),
  end_minute               INT NOT NULL CHECK (end_minute BETWEEN 1 AND 1440),
  enabled                  BOOLEAN NOT NULL DEFAULT true,
  automation_enabled       BOOLEAN NOT NULL DEFAULT true,
  fan_mode                 TEXT NOT NULL DEFAULT 'auto' CHECK (fan_mode IN ('off', 'on', 'auto')),
  fan_speed                INT NOT NULL DEFAULT 2 CHECK (fan_speed BETWEEN 1 AND 3),
  target_temperature       DOUBLE PRECISION NOT NULL DEFAULT 26 CHECK (target_temperature BETWEEN 16 AND 32),
  light_on                 BOOLEAN NOT NULL DEFAULT true,
  light_brightness         INT NOT NULL DEFAULT 80 CHECK (light_brightness BETWEEN 0 AND 100),
  attendance_enabled       BOOLEAN NOT NULL DEFAULT true,
  attendance_grace_minutes INT NOT NULL DEFAULT 10 CHECK (attendance_grace_minutes BETWEEN 0 AND 60),
  created_at               TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (end_minute > start_minute)
);

-- Migrate a pre-existing bookings table from the legacy hour-granularity
-- schema (start_hour/end_hour, no IoT presets) to the current one.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'bookings' AND column_name = 'start_hour'
  ) THEN
    ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_check;
    ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_start_hour_check;
    ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_end_hour_check;
    ALTER TABLE bookings RENAME COLUMN start_hour TO start_minute;
    ALTER TABLE bookings RENAME COLUMN end_hour TO end_minute;
    UPDATE bookings SET start_minute = start_minute * 60, end_minute = end_minute * 60;
    ALTER TABLE bookings ADD CHECK (start_minute BETWEEN 0 AND 1439);
    ALTER TABLE bookings ADD CHECK (end_minute BETWEEN 1 AND 1440);
    ALTER TABLE bookings ADD CHECK (end_minute > start_minute);
  END IF;
END $$;

ALTER TABLE bookings ALTER COLUMN enabled SET DEFAULT true;
ALTER TABLE bookings ALTER COLUMN enabled SET NOT NULL;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS automation_enabled BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS fan_mode TEXT NOT NULL DEFAULT 'auto' CHECK (fan_mode IN ('off', 'on', 'auto'));
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS fan_speed INT NOT NULL DEFAULT 2 CHECK (fan_speed BETWEEN 1 AND 3);
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS target_temperature DOUBLE PRECISION NOT NULL DEFAULT 26 CHECK (target_temperature BETWEEN 16 AND 32);
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS light_on BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS light_brightness INT NOT NULL DEFAULT 80 CHECK (light_brightness BETWEEN 0 AND 100);
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS attendance_enabled BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS attendance_grace_minutes INT NOT NULL DEFAULT 10 CHECK (attendance_grace_minutes BETWEEN 0 AND 60);

CREATE INDEX IF NOT EXISTS bookings_day_time
ON bookings (weekday, start_minute, end_minute);

CREATE TABLE IF NOT EXISTS schedule_automation_state (
  id                INT PRIMARY KEY CHECK (id = 1),
  active            BOOLEAN NOT NULL DEFAULT false,
  active_booking_id INT,
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO schedule_automation_state (id) VALUES (1)
ON CONFLICT (id) DO NOTHING;

ALTER TABLE attendance_records ADD COLUMN IF NOT EXISTS booking_id INT;
CREATE UNIQUE INDEX IF NOT EXISTS attendance_student_class_date_key
ON attendance_records (student_id, session_date, COALESCE(booking_id, 0));
