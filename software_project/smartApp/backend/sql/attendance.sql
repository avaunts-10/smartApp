-- Students, their enrolled face descriptors, and daily attendance.
-- Raw pg (consistent with devices.sql / sensors.sql).
--   psql -U postgres -d smartapp -f backend/sql/attendance.sql

CREATE TABLE IF NOT EXISTS students (
  id           SERIAL PRIMARY KEY,
  name         TEXT NOT NULL,
  student_code TEXT UNIQUE NOT NULL,
  email        TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- One row per enrolled face sample (a student may have several). 128 floats.
CREATE TABLE IF NOT EXISTS face_descriptors (
  id         SERIAL PRIMARY KEY,
  student_id INTEGER NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  descriptor DOUBLE PRECISION[] NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS face_descriptors_student ON face_descriptors (student_id);

CREATE TABLE IF NOT EXISTS attendance_records (
  id           SERIAL PRIMARY KEY,
  student_id   INTEGER NOT NULL REFERENCES students(id) ON DELETE CASCADE,
  method       TEXT NOT NULL DEFAULT 'facial',  -- facial | rfid | manual
  status       TEXT NOT NULL DEFAULT 'present', -- present | late
  session_date DATE NOT NULL DEFAULT CURRENT_DATE,
  recorded_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (student_id, session_date)
);
CREATE INDEX IF NOT EXISTS attendance_records_date ON attendance_records (session_date);
