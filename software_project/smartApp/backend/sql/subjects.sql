CREATE TABLE IF NOT EXISTS subjects (
  id                 SERIAL PRIMARY KEY,
  name               TEXT NOT NULL UNIQUE,
  skill_level        NUMERIC(3,1) NOT NULL DEFAULT 0 CHECK (skill_level BETWEEN 0 AND 10),
  study_minutes      INT NOT NULL DEFAULT 0 CHECK (study_minutes >= 0),
  lessons_completed  INT NOT NULL DEFAULT 0 CHECK (lessons_completed >= 0),
  sort_order         INT NOT NULL DEFAULT 0
);

INSERT INTO subjects (name, skill_level, study_minutes, lessons_completed, sort_order)
SELECT * FROM (VALUES
  ('Mathematics',      7.0, 240, 2, 1),
  ('Computer Science', 6.0, 180, 1, 2),
  ('Science',          5.0, 120, 0, 3),
  ('Languages',        0.0,   0, 0, 4),
  ('History',          0.0,   0, 0, 5)
) AS seed(name, skill_level, study_minutes, lessons_completed, sort_order)
WHERE NOT EXISTS (SELECT 1 FROM subjects);
