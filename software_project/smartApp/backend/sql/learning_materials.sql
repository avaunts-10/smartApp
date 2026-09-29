CREATE TABLE IF NOT EXISTS learning_materials (
  id SERIAL PRIMARY KEY,
  subject_id INTEGER REFERENCES subjects(id),
  title VARCHAR(255) NOT NULL,
  description TEXT,
  file_url TEXT NOT NULL,
  file_name VARCHAR(255),
  file_type VARCHAR(50),
  uploaded_by INTEGER REFERENCES users(id),
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_learning_materials_subject ON learning_materials(subject_id);