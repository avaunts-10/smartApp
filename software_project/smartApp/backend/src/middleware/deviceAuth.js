import crypto from "crypto";

/**
 * Authenticates classroom hardware (RFID reader, sensor boards, ...).
 *
 * Devices can't log in like users, so each request carries a shared secret in
 * the `X-Device-Key` header, compared against DEVICE_API_KEY in backend/.env.
 * If DEVICE_API_KEY is not set, device endpoints stay closed.
 */
export function requireDevice(req, res, next) {
  const expected = process.env.DEVICE_API_KEY;
  if (!expected) {
    return res
      .status(503)
      .json({ message: "Device access is not configured (DEVICE_API_KEY)" });
  }

  const given = req.get("X-Device-Key") || "";
  const a = Buffer.from(given);
  const b = Buffer.from(expected);
  // timingSafeEqual needs equal lengths; it avoids leaking how many leading
  // characters of a guessed key were right.
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) {
    return res.status(401).json({ message: "Invalid device key" });
  }
  next();
}
