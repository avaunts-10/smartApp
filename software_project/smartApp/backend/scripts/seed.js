// Seed baseline accounts for local development / demos.
// Run with:  npm run seed
import bcrypt from "bcrypt";
import pool from "../src/db.js";

const ACCOUNTS = [
  { email: "admin@classroom.com", password: "password", role: "admin" },
  { email: "teacher@classroom.com", password: "password", role: "teacher" },
  { email: "student@classroom.com", password: "password", role: "student" },
];

async function main() {
  for (const acc of ACCOUNTS) {
    const password = await bcrypt.hash(acc.password, 10);
    await pool.query(
      `INSERT INTO users (email, password, role)
       VALUES ($1, $2, $3)
       ON CONFLICT (email) DO UPDATE SET role = EXCLUDED.role`,
      [acc.email, password, acc.role]
    );
    console.log(`✔ ${acc.email} (${acc.role})`);
  }
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => pool.end());
