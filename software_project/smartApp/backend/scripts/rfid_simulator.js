// RFID reader simulator.
//
// Pretends to be the classroom card reader: it sends exactly the request a
// real ESP32 + RC522 reader will send, so the backend and app can be tested
// before the hardware exists.
//
//   npm run rfid-sim                 interactive mode
//   npm run rfid-sim -- tap 04A32B1C  one scan, then exit
//
// Needs the backend running (npm start) and DEVICE_API_KEY in backend/.env.
// The `list` and `setup-demo` commands read/write the database directly;
// that is a development shortcut a real reader cannot do.

import readline from "readline";
import dotenv from "dotenv";

// Keep dotenv's startup tips out of the simulator output (db.js loads it too,
// so it is imported after this is set).
process.env.DOTENV_CONFIG_QUIET ??= "true";
dotenv.config();
const { default: pool } = await import("../src/db.js");

const API = `http://localhost:${process.env.PORT || 4000}/api/rfid/scan`;
const KEY = process.env.DEVICE_API_KEY;

const DEMO_STUDENTS = [
  { name: "Demo Student A", code: "DEMO-001", uid: "04A32B1C" },
  { name: "Demo Student B", code: "DEMO-002", uid: "04B45C2D" },
  { name: "Demo Student C", code: "DEMO-003", uid: "04C56D3E" },
];

const randomUid = () =>
  Array.from({ length: 4 }, () =>
    Math.floor(Math.random() * 256).toString(16).padStart(2, "0")
  )
    .join(":")
    .toUpperCase();

// ---- what a real reader does ------------------------------------------------

async function tap(uid) {
  console.log(`\n  📡 tap  ${uid}`);
  let res;
  try {
    res = await fetch(API, {
      method: "POST",
      headers: { "Content-Type": "application/json", "X-Device-Key": KEY ?? "" },
      body: JSON.stringify({ uid }),
    });
  } catch {
    console.log("  ⚠️  backend not reachable — is `npm start` running?");
    return;
  }
  const body = await res.json().catch(() => ({}));

  if (!res.ok) {
    console.log(`  ⚠️  HTTP ${res.status}: ${body.message ?? "error"}  (reader: long buzz)`);
    return;
  }
  switch (body.result) {
    case "marked":
      console.log(`  ✅ beep     ${body.student.name} marked ${body.status}` +
        (body.classTitle ? ` for ${body.classTitle}` : ""));
      break;
    case "already_marked":
      console.log(`  🔁 beep     ${body.student.name} was already marked today`);
      break;
    case "unknown_card":
      console.log(`  ❌ beep-beep  card ${body.uid} is not linked to any student`);
      break;
    default:
      console.log("  ?? unexpected reply:", body);
  }
}

// ---- development helpers (direct DB access) ---------------------------------

async function list() {
  const { rows } = await pool.query(
    `SELECT name, student_code, rfid_uid FROM students ORDER BY name`
  );
  if (!rows.length) {
    console.log("\n  No students yet. Try `setup-demo`.");
    return [];
  }
  console.log("");
  rows.forEach((r, i) =>
    console.log(
      `  [${i + 1}] ${r.name.padEnd(22)} ${r.student_code.padEnd(10)} ` +
        (r.rfid_uid ?? "— no card —")
    )
  );
  return rows;
}

async function setupDemo() {
  for (const s of DEMO_STUDENTS) {
    await pool.query(
      `INSERT INTO students (name, student_code, rfid_uid) VALUES ($1, $2, $3)
       ON CONFLICT (student_code) DO UPDATE SET rfid_uid = EXCLUDED.rfid_uid`,
      [s.name, s.code, s.uid]
    );
  }
  console.log(`\n  Created ${DEMO_STUDENTS.length} demo students with cards.`);
  await list();
}

async function linkedUids() {
  const { rows } = await pool.query(
    `SELECT rfid_uid FROM students WHERE rfid_uid IS NOT NULL`
  );
  return rows.map((r) => r.rfid_uid);
}

// ---- command loop -----------------------------------------------------------

const HELP = `
  tap <uid>     scan a card by UID (e.g. tap 04:A3:2B:1C)
  tap <n>       scan the card of student [n] from \`list\`
  random        scan a random linked card
  unknown       scan a card nobody owns
  list          show students and their cards      (dev helper)
  setup-demo    add 3 demo students with cards     (dev helper)
  help | quit`;

async function run(line) {
  const [cmd, arg] = line.trim().split(/\s+/);
  switch (cmd) {
    case "tap": {
      if (!arg) return console.log("  usage: tap <uid|n>");
      if (/^\d{1,3}$/.test(arg)) {
        const rows = await list();
        const row = rows[Number(arg) - 1];
        if (!row) return console.log("  no such student");
        if (!row.rfid_uid) return console.log(`  ${row.name} has no card`);
        return tap(row.rfid_uid);
      }
      return tap(arg);
    }
    case "random": {
      const uids = await linkedUids();
      if (!uids.length) return console.log("  no linked cards — try `setup-demo`");
      return tap(uids[Math.floor(Math.random() * uids.length)]);
    }
    case "unknown":
      return tap(randomUid());
    case "list":
      return list();
    case "setup-demo":
      return setupDemo();
    case "help":
    case "":
    case undefined:
      return console.log(HELP);
    default:
      console.log(`  unknown command "${cmd}" — type help`);
  }
}

async function main() {
  if (!KEY) {
    console.log("  DEVICE_API_KEY is missing from backend/.env");
    process.exit(1);
  }

  const args = process.argv.slice(2);
  if (args.length) {
    await run(args.join(" "));
    await pool.end();
    return;
  }

  console.log("RFID reader simulator — sending to", API);
  console.log(HELP);
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout, prompt: "\nrfid> " });
  rl.prompt();
  rl.on("line", async (line) => {
    if (["quit", "exit", "q"].includes(line.trim())) return rl.close();
    await run(line);
    rl.prompt();
  });
  rl.on("close", () => pool.end());
}

main().catch(async (err) => {
  console.error(err);
  await pool.end();
  process.exit(1);
});
