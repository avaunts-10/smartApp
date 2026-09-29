-- Auth routes (src/controllers/auth.controller.js) use a raw pg pool and
-- expect this table. It is NOT managed by Prisma anymore. Run once against
-- the smartapp DB:
--   psql -U postgres -d smartapp -f backend/sql/users.sql
--
-- On a DB that still has the old Prisma-managed "User" table, this renames
-- it in place (preserving data) instead of creating a second table.

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'User') THEN
    ALTER TABLE "User" RENAME TO users;
    ALTER TABLE users RENAME COLUMN "createdAt" TO created_at;
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS users (
  id         SERIAL PRIMARY KEY,
  email      TEXT NOT NULL UNIQUE,
  password   TEXT NOT NULL,
  role       TEXT NOT NULL DEFAULT 'admin',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
