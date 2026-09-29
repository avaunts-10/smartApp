import { Router } from "express";
import {
  register,
  login,
  me,
  listUsers,
  createUser,
  deleteUser,
} from "../controllers/auth.controller.js";
import { requireAuth, requireRole } from "../middleware/auth.js";

const router = Router();

router.post("/register", register);
router.post("/login", login);
router.get("/me", requireAuth, me);
router.get("/users", requireAuth, requireRole("admin"), listUsers);
router.post("/users", requireAuth, requireRole("admin"), createUser);
router.delete("/users/:id", requireAuth, requireRole("admin"), deleteUser);

export default router;
