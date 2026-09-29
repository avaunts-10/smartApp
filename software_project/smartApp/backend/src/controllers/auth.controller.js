// backend/src/controllers/auth.controller.js
import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";
import pool from "../db.js";

const JWT_SECRET = process.env.JWT_SECRET;
if (!JWT_SECRET) {
  throw new Error("JWT_SECRET is not set. Add it to backend/.env");
}

// Roles a visitor may pick for themselves on the public sign-up form.
// "admin" is deliberately excluded — admins are created via `npm run seed`.
const SELF_SIGNUP_ROLES = ["student", "teacher"];

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function toUser(r) {
  return { id: r.id, email: r.email, role: r.role, createdAt: r.created_at };
}

export async function register(req, res) {
  try {
    const { email, password } = req.body;
    const role = req.body.role ?? "student";

    if (!email || !password) {
      return res.status(400).json({ message: "email and password are required" });
    }
    if (typeof email !== "string" || !EMAIL_RE.test(email)) {
      return res.status(400).json({ message: "Enter a valid email address" });
    }
    if (typeof password !== "string" || password.length < 6) {
      return res
        .status(400)
        .json({ message: "Password must be at least 6 characters" });
    }
    if (!SELF_SIGNUP_ROLES.includes(role)) {
      return res.status(400).json({ message: "Role must be student or teacher" });
    }

    const existing = await pool.query("SELECT id FROM users WHERE email = $1", [email]);
    if (existing.rowCount) {
      return res.status(409).json({ message: "Email already registered" });
    }

    const hashed = await bcrypt.hash(password, 10);

    const { rows } = await pool.query(
      `INSERT INTO users (email, password, role)
       VALUES ($1, $2, $3)
       RETURNING id, email, role, created_at`,
      [email, hashed, role]
    );
    const user = toUser(rows[0]);

    // Log the new user straight in.
    const token = jwt.sign({ sub: user.id, role: user.role }, JWT_SECRET, {
      expiresIn: "7d",
    });

    return res.status(201).json({
      message: "User registered",
      token,
      user: { id: user.id, email: user.email, role: user.role },
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: "Server error" });
  }
}

export async function login(req, res) {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ message: "email and password are required" });
    }

    const { rows } = await pool.query("SELECT * FROM users WHERE email = $1", [email]);
    const user = rows[0];
    if (!user) {
      return res.status(401).json({ message: "Invalid credentials" });
    }

    const ok = await bcrypt.compare(password, user.password);
    if (!ok) {
      return res.status(401).json({ message: "Invalid credentials" });
    }

    const token = jwt.sign({ sub: user.id, role: user.role }, JWT_SECRET, {
      expiresIn: "7d",
    });

    return res.json({
      message: "Login success",
      token,
      user: { id: user.id, email: user.email, role: user.role },
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: "Server error" });
  }
}

/** Admin-only: create a teacher or student account from the User Management page. */
export async function createUser(req, res) {
  try {
    const { email, password, role } = req.body;

    if (!email || !password || !role) {
      return res
        .status(400)
        .json({ message: "email, password and role are required" });
    }
    if (typeof email !== "string" || !EMAIL_RE.test(email)) {
      return res.status(400).json({ message: "Enter a valid email address" });
    }
    if (typeof password !== "string" || password.length < 6) {
      return res
        .status(400)
        .json({ message: "Password must be at least 6 characters" });
    }
    if (!SELF_SIGNUP_ROLES.includes(role)) {
      return res.status(400).json({ message: "Role must be student or teacher" });
    }

    const existing = await pool.query("SELECT id FROM users WHERE email = $1", [email]);
    if (existing.rowCount) {
      return res.status(409).json({ message: "Email already registered" });
    }

    const hashed = await bcrypt.hash(password, 10);
    const { rows } = await pool.query(
      `INSERT INTO users (email, password, role)
       VALUES ($1, $2, $3)
       RETURNING id, email, role, created_at`,
      [email, hashed, role]
    );

    return res.status(201).json({ message: "User created", user: toUser(rows[0]) });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: "Server error" });
  }
}

/** Admin-only: remove an account. Admins cannot delete their own account. */
export async function deleteUser(req, res) {
  try {
    const id = Number(req.params.id);
    if (!Number.isInteger(id)) {
      return res.status(400).json({ message: "Invalid user id" });
    }
    if (id === req.user.id) {
      return res.status(400).json({ message: "You cannot delete your own account" });
    }

    const { rowCount } = await pool.query("DELETE FROM users WHERE id = $1", [id]);
    if (!rowCount) {
      return res.status(404).json({ message: "User not found" });
    }
    return res.json({ message: "User deleted" });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: "Server error" });
  }
}

/** Admin-only: every account plus a per-role count, for the User Management page. */
export async function listUsers(req, res) {
  try {
    const { rows } = await pool.query(
      "SELECT id, email, role, created_at FROM users ORDER BY created_at DESC"
    );
    const users = rows.map(toUser);
    const counts = { admin: 0, teacher: 0, student: 0 };
    for (const u of users) {
      if (counts[u.role] !== undefined) counts[u.role] += 1;
    }
    return res.json({ users, counts, total: users.length });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: "Server error" });
  }
}

/** Protected: returns the current user based on the bearer token. */
export async function me(req, res) {
  try {
    const { rows } = await pool.query(
      "SELECT id, email, role, created_at FROM users WHERE id = $1",
      [req.user.id]
    );
    if (!rows[0]) {
      return res.status(401).json({ message: "User no longer exists" });
    }
    return res.json({ user: toUser(rows[0]) });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ message: "Server error" });
  }
}
