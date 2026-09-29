CREATE TABLE IF NOT EXISTS chat_messages (
  id         SERIAL PRIMARY KEY,
  user_id    TEXT NOT NULL,
  subject    TEXT NOT NULL,
  role       TEXT NOT NULL CHECK (role IN ('user', 'ai')),
  content    TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS chat_messages_user_subject
  ON chat_messages (user_id, subject, created_at);
