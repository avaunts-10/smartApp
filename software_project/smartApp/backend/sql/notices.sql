 CREATE TABLE IF NOT EXISTS notices (
  id SERIAL PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  message TEXT NOT NULL,
  attachment_url TEXT,
  attachment_name VARCHAR(255),
    created_by INTEGER REFERENCES "User"(id),
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notices_created_at ON notices(created_at DESC);