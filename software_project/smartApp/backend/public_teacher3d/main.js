import * as THREE from "three";
import { GLTFLoader } from "three/addons/loaders/GLTFLoader.js";
import { DRACOLoader } from "three/addons/loaders/DRACOLoader.js";
import { MeshoptDecoder } from "three/addons/libs/meshopt_decoder.module.js";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";
import { RoomEnvironment } from "three/addons/environments/RoomEnvironment.js";

/* ============================================================
   Config passed by the embedding Flutter page (query string)
   ============================================================ */
const params = new URLSearchParams(location.search);
const API_BASE = (params.get("api") || location.origin).replace(/\/$/, "");
const TOKEN = params.get("token") || "";
const SUBJECT = params.get("subject") || "General";
// embedded=1: the host app shows the transcript and the input itself and
// sends questions with postMessage({type:"ask"}); we only render + speak
const EMBEDDED = params.get("embedded") === "1";
let gender = (params.get("gender") || "female").toLowerCase();

/* ---- subject teachers -------------------------------------------------------
   teachers.json (next to this file, also read by the backend for the AI
   persona) assigns one named teacher per subject: avatar, voice, greeting and
   accent colour. The subject comes from the Flutter screen via ?subject=.   */
let teacher = null;               // roster entry for SUBJECT (null = generic teacher)

async function loadTeacher() {
  try {
    const r = await fetch("./teachers.json", { cache: "no-cache" });
    const roster = await r.json();
    const key = Object.keys(roster).find((k) => k.toLowerCase() === SUBJECT.toLowerCase());
    const t = roster[key] || roster.General;
    if (!t) return;
    teacher = { subject: key || "General", ...t };
    if (!params.get("gender") && (t.gender === "male" || t.gender === "female")) gender = t.gender;
    // both this subject's characters' models go first; the gender default stays as fallback
    if (t.avatar && !GLB_SOURCES[t.gender].includes(t.avatar)) GLB_SOURCES[t.gender].unshift(t.avatar);
    const alt = t.alt;
    if (alt && alt.avatar && (alt.gender === "male" || alt.gender === "female") &&
        !GLB_SOURCES[alt.gender].includes(alt.avatar)) {
      GLB_SOURCES[alt.gender].unshift(alt.avatar);
    }
  } catch (e) {
    console.warn("teachers.json unavailable, using the generic teacher:", e && e.message);
  }
}

// The subject's two characters, keyed by gender: the roster entry's own
// fields for its `gender`, and `alt` (falling back to the base fields for
// anything it doesn't override) for the other. Lets the student pick either
// one; whichever is active drives the badge, the voice and the AI persona.
function personaFor(g) {
  if (!teacher) return null;
  if (g === teacher.gender) return teacher;
  const alt = teacher.alt;
  if (alt && alt.gender === g) return { ...teacher, ...alt };
  return teacher; // no alternate character defined — stay on the default one
}

// Realistic avatars (Ready Player Me). For each gender we try, in order:
//   1) ?femaleUrl= / ?maleUrl= passed by the Flutter screen
//   2) a file you dropped in  backend/public_teacher3d/avatars/<gender>.glb
// If none load, we fall back to the built-in cartoon teacher (always works).
const RPM_QS = "?morphTargets=ARKit,Oculus%20Visemes&textureAtlas=1024&pose=A&lod=1";
const withQS = (u) => (u ? u + (/\?/.test(u) ? "" : RPM_QS) : null);
const GLB_SOURCES = {
  female: [withQS(params.get("femaleUrl")), "./avatars/female.glb"].filter(Boolean),
  male: [withQS(params.get("maleUrl")), "./avatars/male.glb"].filter(Boolean),
};

/* ============================================================
   DOM
   ============================================================ */
const hint = document.getElementById("hint");
const canvas = document.getElementById("c");
const answerBox = document.getElementById("answerBox");
const askBtn = document.getElementById("askBtn");
const questionInput = document.getElementById("question");
const fBtn = document.getElementById("femaleBtn");
const mBtn = document.getElementById("maleBtn");
const whoBox = document.getElementById("who");
const badge = document.getElementById("teacher");
const badgeName = document.getElementById("teacherName");
const badgeSubject = document.getElementById("teacherSubject");

function showTeacherBadge() {
  if (EMBEDDED) document.body.classList.add("embedded");
  if (!teacher) return;
  const p = personaFor(gender) || teacher;
  badgeName.textContent = p.name;
  badgeSubject.textContent = p.title || teacher.subject;
  badge.style.setProperty("--accent", teacher.accent || "#2563eb");
  badge.hidden = false;
  // every subject has a female and a male character to pick between
  whoBox.hidden = false;
  document.title = `${p.name} — 3D AI Teacher`;
}

function emit(type, extra = {}) {
  try { parent.postMessage({ source: "teacher3d", type, ...extra }, "*"); } catch (_) {}
}

/* ============================================================
   Renderer / scene / camera
   ============================================================ */
const renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
renderer.setSize(window.innerWidth, window.innerHeight);
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 0.85;
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;

const scene = new THREE.Scene();

// soft, friendly classroom-ish gradient backdrop, tinted with the subject's
// accent colour (very light at the top, deeper at the bottom)
function setBackdrop(accent = "#2563eb") {
  const hex = accent.replace("#", "");
  const [r, g0, b] = [0, 2, 4].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255);
  const mix = (t, base) => `rgb(${[r, g0, b].map((v) => Math.round((v * t + base * (1 - t)) * 255)).join(",")})`;
  const c = document.createElement("canvas");
  c.width = 16; c.height = 256;
  const ctx = c.getContext("2d");
  const g = ctx.createLinearGradient(0, 0, 0, 256);
  g.addColorStop(0.00, mix(0.07, 1));      // almost white
  g.addColorStop(0.45, mix(0.22, 1));      // pastel
  g.addColorStop(1.00, mix(0.55, 0.45));   // muted deep tone
  ctx.fillStyle = g; ctx.fillRect(0, 0, 16, 256);
  const tex = new THREE.CanvasTexture(c);
  tex.colorSpace = THREE.SRGBColorSpace;
  if (scene.background && scene.background.dispose) scene.background.dispose();
  scene.background = tex;
}
setBackdrop();

// image-based lighting for realistic skin/clothes, kept gentle so textures
// keep their real colour instead of washing out to white
const pmrem = new THREE.PMREMGenerator(renderer);
scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
scene.environmentIntensity = 0.55;

const camera = new THREE.PerspectiveCamera(30, window.innerWidth / window.innerHeight, 0.1, 100);

const controls = new OrbitControls(camera, renderer.domElement);
controls.enableDamping = true;
controls.enablePan = false;
controls.minDistance = 0.5;
controls.maxDistance = 3.5;
controls.minPolarAngle = Math.PI * 0.25;
controls.maxPolarAngle = Math.PI * 0.62;

/* soft 3-point rig — warm key, cool fill, gentle rim */
const key = new THREE.DirectionalLight(0xfff2e0, 1.5);
key.position.set(2.5, 4, 3);
key.castShadow = true;
key.shadow.mapSize.set(2048, 2048);
key.shadow.bias = -0.0002;
key.shadow.camera.near = 0.5;
key.shadow.camera.far = 12;
key.shadow.radius = 4;
scene.add(key);

const fill = new THREE.DirectionalLight(0xdfeaff, 0.5);
fill.position.set(-3, 1.5, 2.5);
scene.add(fill);

const rim = new THREE.DirectionalLight(0xbcd0ff, 0.7);
rim.position.set(-1.5, 3, -3);
scene.add(rim);

scene.add(new THREE.HemisphereLight(0xffffff, 0x8090a8, 0.35));

/* ground that only catches the shadow */
const ground = new THREE.Mesh(
  new THREE.CircleGeometry(3, 48).rotateX(-Math.PI / 2),
  new THREE.ShadowMaterial({ opacity: 0.32 })
);
ground.receiveShadow = true;
scene.add(ground);

/* ============================================================
   Avatar
   ============================================================ */
const draco = new DRACOLoader().setDecoderPath("/three/examples/jsm/libs/draco/");
const gltfLoader = new GLTFLoader()
  .setDRACOLoader(draco)
  .setMeshoptDecoder(MeshoptDecoder);

let avatar = null;
let mixer = null;                 // plays an embedded idle clip if the model has one
const bones = {};                 // normalised: Head, Neck, Spine1, Hips, LeftEye, ...
const morphMeshes = [];           // every mesh that has morph targets
let eyeHeight = 1.6;
let hasEmbeddedIdle = false;
let toon = null;                  // procedural cartoon rig (null when a GLB is used)

// "mixamorig:Head_06" / "Wolf3D_Head" / "Head" -> "Head"
function normBone(n) {
  return n.replace(/^mixamorig:?/i, "").replace(/_\d+$/, "").replace(/^Wolf3D_/i, "");
}

/* --- bone aiming in world space --------------------------------------------
   Sketchfab / Mixamo / RPM rigs have arbitrary bone-local axes and ship in
   A- or T-pose, so limbs are posed by *aiming* them: each frame we compute the
   world rotation that swings a bone's rest direction (bone -> child) onto a
   target direction, then convert it into the bone's local frame using the
   parent's CURRENT world orientation. Parents are aimed before children, so
   the chain stays consistent whatever the rig's rest pose is.
   World axes: X = avatar's left (screen right), Y = up, Z = toward camera.   */
const restPose = {};              // bone name -> { world: Quaternion, dir: Vector3 }
const LIMB_CHILD = { LeftArm: "LeftForeArm", RightArm: "RightForeArm", LeftForeArm: "LeftHand", RightForeArm: "RightHand" };
const _qTmp = new THREE.Quaternion(), _qInv = new THREE.Quaternion(), _qWorld = new THREE.Quaternion(), _qTwist = new THREE.Quaternion();
const _vA = new THREE.Vector3(), _vB = new THREE.Vector3();

function captureRest(names) {
  avatar.updateWorldMatrix(true, true);
  for (const n of names) {
    const b = bones[n], child = bones[LIMB_CHILD[n]];
    if (!b || !child) continue;
    const dir = child.getWorldPosition(_vA).sub(b.getWorldPosition(_vB));
    if (dir.length() < 1e-4) continue;
    restPose[n] = { world: b.getWorldQuaternion(new THREE.Quaternion()), dir: dir.clone().normalize() };
  }
}

// point bone `name` (its bone -> child axis) along world direction `target`,
// then roll it `twist` radians about that axis (used to turn palms inward)
function aimBone(name, target, twist = 0) {
  const r = restPose[name], b = bones[name];
  if (!r || !b) return;
  _vA.copy(target).normalize();
  _qTmp.setFromUnitVectors(r.dir, _vA);                 // world delta: rest dir -> target
  _qTwist.setFromAxisAngle(_vA, twist);
  _qWorld.copy(_qTwist).multiply(_qTmp).multiply(r.world);   // desired world orientation
  b.parent.updateWorldMatrix(true, false);
  b.parent.getWorldQuaternion(_qInv).invert();
  b.quaternion.copy(_qInv).multiply(_qWorld);           // local = parent⁻¹ · world
  b.updateWorldMatrix(false, false);
}

function setMorph(name, value) {
  for (const m of morphMeshes) {
    const i = m.morphTargetDictionary[name];
    if (i !== undefined) m.morphTargetInfluences[i] = value;
  }
}
function hasMorph(name) {
  return morphMeshes.some((m) => m.morphTargetDictionary[name] !== undefined);
}

function disposeAvatar() {
  if (avatar) {
    scene.remove(avatar);
    avatar.traverse((o) => {
      if (o.geometry) o.geometry.dispose();
      if (o.material) [].concat(o.material).forEach((mt) => mt.dispose());
    });
  }
  avatar = null; toon = null;
  if (mixer) { mixer.stopAllAction(); mixer = null; }
  hasEmbeddedIdle = false;
  morphMeshes.length = 0;
  for (const k of Object.keys(bones)) delete bones[k];
  for (const k of Object.keys(restPose)) delete restPose[k];
  for (const k of Object.keys(armCur)) delete armCur[k];
  for (const k of Object.keys(armTwist)) delete armTwist[k];
  gestureName = "rest"; nextGesture = 0; wordPulse = 0;
}

/* --- palettes: bright + friendly ------------------------------------------- */
const PALETTE = {
  female: { skin: 0xffcfa8, blush: 0xff9a8b, hair: 0x7b3f1d, brow: 0x5a2c12,
            top: 0xff5c8a, top2: 0xffd23f, iris: 0x3a6ea5, lip: 0xd85a6b },
  male:   { skin: 0xf3bE93, blush: 0xe98d76, hair: 0x2f2016, brow: 0x241811,
            top: 0x2f7df6, top2: 0xffffff, iris: 0x5a3a1e, lip: 0xc06a58 },
};

function mat(color, o = {}) {
  return new THREE.MeshStandardMaterial({
    color, roughness: o.rough ?? 0.72, metalness: o.metal ?? 0.0,
    emissive: o.emissive ?? 0x000000, emissiveIntensity: o.emissiveIntensity ?? 0,
    flatShading: !!o.flat,
  });
}
const ball = (r, m, seg = 32) => new THREE.Mesh(new THREE.SphereGeometry(r, seg, seg), m);
const cap = (r, len, m) => new THREE.Mesh(new THREE.CapsuleGeometry(r, len, 6, 16), m);

/* Build a stylised teacher entirely from primitives. Returns the root Group;
   also fills `bones.Head` and a `toon` rig used by the animation loop. */
function buildToonTeacher(which) {
  const P = PALETTE[which] || PALETTE.female;
  const outer = new THREE.Group();   // placed on the floor by frameAvatar()
  const root = new THREE.Group();    // inner — animated (breathe / sway)
  outer.add(root);

  const skin = mat(P.skin, { rough: 0.55 });
  const hairM = mat(P.hair, { rough: 0.5 });
  const legM = mat(which === "female" ? 0x35406b : 0x2a3550, { rough: 0.7 });
  const shoeM = mat(0x2b2b33, { rough: 0.5 });

  // ---- legs + shoes -------------------------------------------------------
  for (const s of [-1, 1]) {
    const leg = cap(0.085, 0.5, legM);
    leg.position.set(s * 0.12, 0.34, 0);
    root.add(leg);
    const shoe = new THREE.Mesh(new THREE.CapsuleGeometry(0.075, 0.12, 4, 12), shoeM);
    shoe.rotation.z = Math.PI / 2;
    shoe.position.set(s * 0.12, 0.04, 0.06);
    root.add(shoe);
  }

  // ---- torso ----------------------------------------------------------------
  let torso;
  if (which === "female") {
    const pts = [
      new THREE.Vector2(0.05, 0.00), new THREE.Vector2(0.30, 0.02),
      new THREE.Vector2(0.24, 0.34), new THREE.Vector2(0.17, 0.62),
      new THREE.Vector2(0.15, 0.74), new THREE.Vector2(0.00, 0.76),
    ];
    torso = new THREE.Mesh(new THREE.LatheGeometry(pts, 40), mat(P.top, { rough: 0.68 }));
    torso.position.y = 0.66;
  } else {
    torso = cap(0.24, 0.42, mat(P.top, { rough: 0.68 }));
    torso.position.y = 1.06;
    const collar = new THREE.Mesh(new THREE.TorusGeometry(0.13, 0.03, 8, 24), mat(P.top2));
    collar.rotation.x = Math.PI / 2; collar.position.y = 1.33; root.add(collar);
    const tie = new THREE.Mesh(new THREE.ConeGeometry(0.05, 0.34, 4), mat(P.blush));
    tie.position.set(0, 1.12, 0.2); tie.rotation.x = 0.1; root.add(tie);
  }
  torso.castShadow = true;
  root.add(torso);

  // ---- arms ---------------------------------------------------------------
  for (const s of [-1, 1]) {
    const arm = cap(0.06, 0.34, skin);
    arm.position.set(s * 0.3, 1.06, 0);
    arm.rotation.z = s * 0.28;
    arm.castShadow = true;
    root.add(arm);
    const hand = ball(0.075, skin, 16);
    hand.position.set(s * 0.42, 0.82, 0.02);
    root.add(hand);
  }

  // ---- neck + head pivot -------------------------------------------------
  const neck = cap(0.06, 0.08, skin);
  neck.position.y = 1.4;
  root.add(neck);

  const headPivot = new THREE.Group();
  headPivot.position.set(0, 1.5, 0);
  root.add(headPivot);

  const head = ball(0.24, skin);
  head.scale.set(1, 1.08, 0.98);
  head.castShadow = true;
  headPivot.add(head);

  for (const s of [-1, 1]) {                       // ears
    const ear = ball(0.05, skin, 16);
    ear.position.set(s * 0.235, 0, 0);
    headPivot.add(ear);
  }
  const nose = ball(0.035, mat(P.skin, { rough: 0.5 }), 16);
  nose.position.set(0, -0.01, 0.235);
  headPivot.add(nose);

  for (const s of [-1, 1]) {                       // cheeks
    const b = ball(0.045, mat(P.blush, { rough: 0.9 }), 16);
    b.position.set(s * 0.12, -0.06, 0.205); b.scale.z = 0.4;
    headPivot.add(b);
  }

  // ---- eyes -------------------------------------------------------------
  const eyes = new THREE.Group();
  headPivot.add(eyes);
  const eyeParts = [];
  for (const s of [-1, 1]) {
    const g = new THREE.Group();
    g.position.set(s * 0.095, 0.03, 0.2);
    const white = ball(0.052, mat(0xffffff, { rough: 0.3 }), 24);
    white.scale.z = 0.6;
    const iris = ball(0.026, mat(P.iris, { rough: 0.25 }), 20);
    iris.position.z = 0.035;
    const pupil = ball(0.012, mat(0x101015), 16);
    pupil.position.z = 0.052;
    g.add(white, iris, pupil);
    eyes.add(g);
    eyeParts.push(g);
  }
  const brows = new THREE.Group();
  headPivot.add(brows);
  for (const s of [-1, 1]) {
    const br = new THREE.Mesh(new THREE.CapsuleGeometry(0.014, 0.08, 4, 8), mat(P.brow));
    br.rotation.z = Math.PI / 2;
    br.position.set(s * 0.095, 0.11, 0.21);
    brows.add(br);
  }

  // ---- mouth (the lip-sync driver) ------------------------------------
  const mouth = new THREE.Group();
  mouth.position.set(0, -0.11, 0.205);
  headPivot.add(mouth);
  const lips = new THREE.Mesh(new THREE.CircleGeometry(0.06, 24), mat(P.lip, { rough: 0.5 }));
  lips.scale.set(1.5, 0.16, 1);                    // closed = thin line
  const cavity = new THREE.Mesh(new THREE.CircleGeometry(0.052, 24), mat(0x5b1a22));
  cavity.position.z = -0.006; cavity.scale.set(1.35, 0.9, 1);
  const teeth = new THREE.Mesh(new THREE.PlaneGeometry(0.09, 0.03), mat(0xffffff, { rough: 0.3 }));
  teeth.position.set(0, 0.02, -0.004);
  const tongue = new THREE.Mesh(new THREE.CircleGeometry(0.03, 16), mat(0xe0656f));
  tongue.position.set(0, -0.02, -0.005);
  mouth.add(cavity, teeth, tongue, lips);

  // ---- hair (kept behind the face plane so it never clips the eyes) -----
  const hairTop = ball(0.256, hairM);
  headPivot.add(hairTop);
  if (which === "female") {
    hairTop.scale.set(1.12, 1.1, 0.9);
    hairTop.position.set(0, 0.06, -0.05);
    for (const s of [-1, 1]) {                     // shoulder-length sides
      const side = cap(0.075, 0.3, hairM);
      side.position.set(s * 0.215, -0.14, -0.03);
      headPivot.add(side);
    }
    const bun = ball(0.12, hairM, 20);
    bun.position.set(0, 0.14, -0.2);
    headPivot.add(bun);
    const fringe = new THREE.Mesh(new THREE.TorusGeometry(0.17, 0.05, 10, 28, Math.PI), hairM);
    fringe.rotation.set(Math.PI / 2, 0, 0);
    fringe.position.set(0, 0.16, 0.02);
    headPivot.add(fringe);
  } else {
    hairTop.scale.set(1.1, 0.7, 0.95);
    hairTop.position.set(0, 0.13, -0.04);
  }

  // ---- glasses (teacher!) -------------------------------------------
  const frame = mat(0x2b2f3a, { rough: 0.4 });
  for (const s of [-1, 1]) {
    const lens = new THREE.Mesh(new THREE.TorusGeometry(0.062, 0.011, 8, 24), frame);
    lens.position.set(s * 0.095, 0.03, 0.24);
    headPivot.add(lens);
  }
  const bridge = new THREE.Mesh(new THREE.BoxGeometry(0.06, 0.012, 0.012), frame);
  bridge.position.set(0, 0.03, 0.24);
  headPivot.add(bridge);

  outer.traverse((o) => { if (o.isMesh) o.castShadow = true; });

  bones.Head = headPivot;
  toon = { headPivot, eyes: eyeParts, brows, mouth, lips, teeth, tongue, root };
  return outer;
}

function frameAvatar() {
  // scale so the model is ~1.75 tall, drop feet to the floor
  let box = new THREE.Box3().setFromObject(avatar);
  let size = box.getSize(new THREE.Vector3());
  if (size.y > 4 || size.y < 0.6) avatar.scale.multiplyScalar(1.75 / size.y);
  box = new THREE.Box3().setFromObject(avatar);
  avatar.position.x -= (box.min.x + box.max.x) / 2;
  avatar.position.z -= (box.min.z + box.max.z) / 2;
  avatar.position.y -= box.min.y;

  eyeHeight = bones.Head
    ? bones.Head.getWorldPosition(new THREE.Vector3()).y
    : box.getSize(new THREE.Vector3()).y * 0.9;
  const focus = eyeHeight - 0.28;                 // aim at upper chest
  camera.position.set(0.28, eyeHeight - 0.08, 1.75);
  controls.target.set(0, focus, 0);
  controls.update();
}

async function loadAvatar(which) {
  setButtons(which);
  disposeAvatar();

  let gltf = null;
  for (const src of GLB_SOURCES[which]) {
    hint.textContent = "Loading teacher…";
    try {
      gltf = await gltfLoader.loadAsync(src);
      console.log("avatar loaded from:", src);
      break;
    } catch (e) {
      console.warn("avatar source failed:", src, "→", e && e.message);
    }
  }

  if (!gltf) {
    console.info("no realistic avatar found — using the built-in cartoon teacher");
    avatar = buildToonTeacher(which);
    scene.add(avatar);
    frameAvatar();
    restMouth();
    hint.textContent = "Ready — ask a question";
    emit("ready", { gender: which, lipSync: true, style: "toon" });
    return;
  }

  avatar = gltf.scene;
  let textured = 0, plain = 0;
  avatar.traverse((o) => {
    if (o.isMesh) {
      o.castShadow = true;
      o.frustumCulled = false;
      if (o.morphTargetDictionary) morphMeshes.push(o);
      for (const mt of [].concat(o.material)) {
        if (!mt) continue;
        if (mt.map) {
          mt.map.colorSpace = THREE.SRGBColorSpace;      // keep albedo colours true
          mt.map.anisotropy = 4;
          textured++;
        } else {
          plain++;
        }
        mt.envMapIntensity = 0.6;                        // don't let IBL wash it out
        if (mt.emissiveIntensity > 1) mt.emissiveIntensity = 1;
        mt.needsUpdate = true;
      }
    }
    if (o.isBone) bones[normBone(o.name)] = o;
  });
  console.log(`avatar materials: ${textured} textured, ${plain} untextured`);

  scene.add(avatar);

  // play an embedded idle clip if the model ships one (e.g. bundled teacher.glb)
  hasEmbeddedIdle = (gltf.animations || []).length > 0;
  if (hasEmbeddedIdle) {
    mixer = new THREE.AnimationMixer(avatar);
    mixer.clipAction(gltf.animations[0]).play();
  }

  frameAvatar();

  // arms are posed every frame by poseArms() (rest at the sides + gestures)
  if (!hasEmbeddedIdle) captureRest(ARM_BONES);

  let lip = hasMorph("viseme_aa") || hasMorph("jawOpen");
  if (!lip) {
    try { lip = synthesizeFace(); } catch (e) { console.warn("synthetic face failed:", e); }
  }
  restMouth();
  hint.textContent = lip ? "Ready — ask a question" : "Ready (avatar has no mouth shapes — see avatars/README.md)";
  emit("ready", { gender: which, lipSync: lip, teacher: (personaFor(which) || teacher || {}).name });
  greet();
}

// the subject teacher introduces themselves once per visit (whichever
// character — female or male — is active on first load)
let greeted = false;
function greet() {
  if (greeted || !teacher) return;
  const p = personaFor(gender) || teacher;
  if (!p.greeting) return;
  greeted = true;
  answerBox.textContent = p.greeting;
  emit("greeting", { text: p.greeting, teacher: p.name });
  speak(p.greeting);
}

/* --- synthetic face for models without blendshapes -------------------------
   Sketchfab re-exports of Ready Player Me avatars strip every morph target,
   but the head still has separate upper/lower lip loops, eye openings, an
   inner mouth cavity and teeth. We rebuild a small ARKit-style set of
   blendshapes at load time so the existing lip-sync / blink / brow / smile
   code drives them unchanged:

     jawOpen                  lower lip + chin + lower teeth rotate about a
                              jaw pivot (vertices labelled by mesh
                              connectivity, so the touching lips separate)
     eyeBlinkLeft / Right     eyelids rotate about the eyeball centre (the
                              eye bone), sized by the eyeball mesh radius
     mouthSmileLeft / Right   mouth corners pulled up, out and back
     mouthPucker              lips drawn to the centre and forward (O / U)
     browInnerUp              inner brow region lifted

   Geometry lives in the skeleton bind space, which Sketchfab wraps in
   ±90° / ×100 nodes, so every measurement is a projection onto that space's
   own right / up / forward axes rather than raw x / y / z.
   Side convention: the avatar faces +Z, so its LEFT is +X (screen right). */
const JAW_OPEN_ANGLE = 0.22;                       // radians at jawOpen = 1
const JAW_SKIP_RE = /hair|glass|eye|brow|lash|outfit|top|bottom|footwear|shoe|body|beard/i;

// axes of geometry (bind) space expressed in geometry coordinates, plus the
// matrix that maps world points into it
function geomFrame(mesh) {
  const sk = mesh.skeleton;
  let i = sk.bones.findIndex((b) => /hips/i.test(b.name));
  if (i < 0) i = 0;
  // geometry -> world at rest: bone.matrixWorld * inverseBind (GLTFLoader binds with an
  // identity bindMatrix, so the skinned mesh node transform itself is not applied)
  const T = new THREE.Matrix4().multiplyMatrices(sk.bones[i].matrixWorld, sk.boneInverses[i]);
  const Tinv = T.clone().invert();
  const R = new THREE.Matrix3().setFromMatrix4(Tinv);
  const axis = (x, y, z) => new THREE.Vector3(x, y, z).applyMatrix3(R).normalize();
  return { Tinv, right: axis(1, 0, 0), up: axis(0, 1, 0), fwd: axis(0, 0, 1) };
}

// projected coordinates of vertex i: [side, height, depth]
function proj(p, i, F, v) {
  v.fromBufferAttribute(p, i);
  return [v.dot(F.right), v.dot(F.up), v.dot(F.fwd)];
}
const projPoint = (pt, F) => [pt.dot(F.right), pt.dot(F.up), pt.dot(F.fwd)];

function findMouthLine(meshes, F) {
  const v = new THREE.Vector3();
  const teeth = meshes.find((m) => /teeth/i.test(m.material.name) || /teeth/i.test(m.name));
  if (teeth) {
    const p = teeth.geometry.attributes.position;
    let hMin = Infinity, hMax = -Infinity, dMax = -Infinity;
    for (let i = 0; i < p.count; i++) {
      const [, h, d] = proj(p, i, F, v);
      hMin = Math.min(hMin, h); hMax = Math.max(hMax, h); dMax = Math.max(dMax, d);
    }
    const H = hMax - hMin;
    return { mouthH: (hMin + hMax) / 2, mouthD: dMax, H, chinH: hMin - 0.2 * H };
  }
  // no teeth mesh (single-mesh export): the lips meet along a line of
  // duplicated vertices, so find the densest band of duplicates under the eyes
  if (!bones.LeftEye || !bones.RightEye) return null;
  const eye = bones.LeftEye.getWorldPosition(new THREE.Vector3())
    .add(bones.RightEye.getWorldPosition(v)).multiplyScalar(0.5).applyMatrix4(F.Tinv);
  const eyeH = eye.dot(F.up), eyeD = eye.dot(F.fwd);
  const head = meshes.reduce((a, m) => (m.geometry.attributes.position.count > a.geometry.attributes.position.count ? m : a));
  const p = head.geometry.attributes.position;
  let chinH = Infinity;
  const seen = new Set(), dups = [];
  for (let i = 0; i < p.count; i++) {
    const [s, h, d] = proj(p, i, F, v);
    if (Math.abs(s) > 0.03 || d < eyeD + 0.02 || h > eyeH - 0.03 || h < eyeH - 0.16) continue;
    if (Math.abs(s) < 0.015) chinH = Math.min(chinH, h);
    const key = `${s.toFixed(4)},${h.toFixed(4)},${d.toFixed(4)}`;
    if (seen.has(key)) dups.push([h, d]); else seen.add(key);
  }
  if (!isFinite(chinH)) return null;
  const D = eyeH - chinH, H = 0.32 * D;
  if (dups.length < 6) return { mouthH: chinH + 0.21 * D, mouthD: eyeD + 0.05, H, chinH };
  const bins = new Map();                            // 2 mm histogram of duplicate heights
  for (const [h] of dups) { const b = Math.round(h / 0.002); bins.set(b, (bins.get(b) || 0) + 1); }
  const mode = [...bins.entries()].sort((a, b) => b[1] - a[1])[0][0] * 0.002;
  const band = dups.filter(([h]) => Math.abs(h - mode) < 0.004);
  const mouthH = band.reduce((t, [h]) => t + h, 0) / band.length;
  const mouthD = Math.max(...band.map(([, d]) => d));
  return { mouthH, mouthD, H, chinH };
}

// vertex -> neighbours from the index buffer
function adjacency(g) {
  const n = g.attributes.position.count;
  const idx = g.index ? g.index.array : null;
  if (!idx) return null;
  const adj = Array.from({ length: n }, () => []);
  for (let i = 0; i < idx.length; i += 3) {
    const a = idx[i], b = idx[i + 1], c = idx[i + 2];
    adj[a].push(b, c); adj[b].push(a, c); adj[c].push(a, b);
  }
  return adj;
}

// eyeball for one side: centre and radius. The eye bone is only a rough guide
// (on some exports it sits above / behind the eyeball), so the eyeball surface
// itself is located: a separate eye mesh if the export kept one, otherwise a
// small round island of the head mesh next to the bone. The sphere centre is
// one radius behind that surface's front.
function findEye(F, bone, head, islands) {
  const v = new THREE.Vector3();
  const [bs, bh, bd] = projPoint(bone.getWorldPosition(v).applyMatrix4(F.Tinv), F);
  const cands = [];
  const measure = (p, indices) => {
    let s0 = Infinity, s1 = -Infinity, h0 = Infinity, h1 = -Infinity, d1 = -Infinity;
    for (const i of indices) {
      const [ps, ph, pd] = proj(p, i, F, v);
      s0 = Math.min(s0, ps); s1 = Math.max(s1, ps); h0 = Math.min(h0, ph); h1 = Math.max(h1, ph); d1 = Math.max(d1, pd);
    }
    const W = s1 - s0, Hh = h1 - h0;
    if (W < 0.012 || W > 0.06 || Math.abs(W - Hh) > 0.35 * W) return;      // eyeballs are round
    const cs = (s0 + s1) / 2, ch = (h0 + h1) / 2;
    const dist = Math.hypot(cs - bs, ch - bh);
    if (dist > 0.015) return;
    const R = Math.max(W, Hh) / 2;
    cands.push({ cs, ch, cd: d1 - R, R, dist });
  };
  avatar.traverse((o) => {
    if (o.isMesh && /eye/i.test(o.material.name) && !/brow|lash/i.test(o.material.name)) {
      const p = o.geometry.attributes.position;
      measure(p, Array.from({ length: p.count }, (_, i) => i));
    }
  });
  for (const isl of islands) measure(head.geometry.attributes.position, isl);
  cands.sort((x, y) => x.dist - y.dist);
  return cands[0] || { cs: bs, ch: bh, cd: bd, R: 0.014 };
}

// small connected components of a mesh (eyeballs, teeth, lashes … inside a
// single-mesh export), as arrays of vertex indices
function smallIslands(g, maxSize = 600) {
  const adj = adjacency(g);
  if (!adj) return [];
  const n = g.attributes.position.count, comp = new Int32Array(n).fill(-1), out = [];
  for (let i = 0; i < n; i++) {
    if (comp[i] >= 0) continue;
    const q = [i]; comp[i] = i;
    for (let k = 0; k < q.length; k++) for (const w of adj[q[k]]) if (comp[w] < 0) { comp[w] = i; q.push(w); }
    if (q.length >= 12 && q.length <= maxSize) out.push(q);
  }
  return out;
}

// attach a named relative morph target to a mesh
function addMorph(mesh, name, delta) {
  const g = mesh.geometry;
  g.morphAttributes.position = g.morphAttributes.position || [];
  g.morphTargetsRelative = true;
  const index = g.morphAttributes.position.length;
  g.morphAttributes.position.push(new THREE.Float32BufferAttribute(delta, 3));
  mesh.morphTargetInfluences = mesh.morphTargetInfluences || [];
  mesh.morphTargetInfluences[index] = 0;
  mesh.morphTargetDictionary = mesh.morphTargetDictionary || {};
  mesh.morphTargetDictionary[name] = index;
  mesh.material.needsUpdate = true;
}

// generic helper: delta[i] = weight(s,h,d,v) * displacement(s,h,d,v)
function regionMorph(mesh, F, fn) {
  const p = mesh.geometry.attributes.position, n = p.count;
  const delta = new Float32Array(n * 3), v = new THREE.Vector3(), r = new THREE.Vector3();
  let moved = 0;
  for (let i = 0; i < n; i++) {
    const [s, h, d] = proj(p, i, F, v);
    r.set(0, 0, 0);
    if (!fn(s, h, d, v, r)) continue;
    delta[i * 3] = r.x; delta[i * 3 + 1] = r.y; delta[i * 3 + 2] = r.z;
    moved++;
  }
  return moved ? delta : null;
}

function buildJawMorph(mesh, L, F) {
  const g = mesh.geometry, p = g.attributes.position, n = p.count;
  const { mouthH, mouthD, H, chinH } = L;
  const pivotH = mouthH + 0.7 * H, pivotD = mouthD - 4.3 * H;
  const pivot = new THREE.Vector3().addScaledVector(F.up, pivotH).addScaledVector(F.fwd, pivotD);
  const label = new Int8Array(n);                    // 1 = moves with jaw, -1 = stays
  const v = new THREE.Vector3();
  const adj = adjacency(g);
  if (adj) {
    const q = [];
    for (let i = 0; i < n; i++) {
      const [, h, d] = proj(p, i, F, v);
      if (d < mouthD - 2.5 * H) continue;
      if (h < mouthH - 0.45 * H && h > chinH - 1.0 * H) { label[i] = 1; q.push(i); }
      else if (h > mouthH + 0.45 * H) { label[i] = -1; q.push(i); }
    }
    for (let k = 0; k < q.length; k++) {
      const a = q[k];
      for (const b of adj[a]) if (label[b] === 0) { label[b] = label[a]; q.push(b); }
    }
  }
  const rot = new THREE.Quaternion().setFromAxisAngle(F.right, JAW_OPEN_ANGLE);
  let i = -1;
  return regionMorph(mesh, F, (s, h, d, pos, out) => {
    i++;
    const lower = label[i] !== 0 ? label[i] === 1 : h < mouthH;   // islands (teeth, tongue): by height
    if (!lower) return false;
    const w = THREE.MathUtils.smoothstep(h, chinH - 1.4 * H, chinH - 0.7 * H)   // fade out into the neck
            * THREE.MathUtils.smoothstep(d, pivotD - 1.5 * H, pivotD + 0.5 * H); // never the back of the head
    if (w <= 0) return false;
    out.copy(pos).sub(pivot).applyQuaternion(rot).add(pivot).sub(pos).multiplyScalar(w);
    return true;
  });
}

// eyelids close by rotating about the eyeball centre (upper lid most of the way,
// lower lid a little), fading out towards the socket rim
function buildBlinkMorph(mesh, F, eye) {
  const { cs, ch, cd, R } = eye;
  const centre = new THREE.Vector3().addScaledVector(F.right, cs).addScaledVector(F.up, ch).addScaledVector(F.fwd, cd);
  const q = new THREE.Quaternion();
  return regionMorph(mesh, F, (s, h, d, pos, out) => {
    // shorter reach upward so the eyebrows stay put
    const r = Math.hypot(s - cs, (h - ch) * (h > ch ? 1.35 : 1));
    if (r > 1.45 * R || d < cd - 0.3 * R) return false;                 // front of the socket only
    const w = 1 - THREE.MathUtils.smoothstep(r, 0.9 * R, 1.45 * R);
    if (w <= 0) return false;
    const t = THREE.MathUtils.smoothstep(h - ch, -0.15 * R, 0.15 * R);   // 1 = upper lid, 0 = lower lid
    q.setFromAxisAngle(F.right, (1.05 * t - 0.3 * (1 - t)) * w);       // +angle swings the front of the eye down
    out.copy(pos).sub(centre).applyQuaternion(q).add(centre).sub(pos);
    return true;
  });
}

// mouth corner pulled up, outward and back (cheek follows through the falloff)
function buildSmileMorph(mesh, F, corner, H) {
  const [cs, ch, cd] = corner, side = Math.sign(cs) || 1;
  return regionMorph(mesh, F, (s, h, d, pos, out) => {
    const r = Math.hypot((s - cs) * 1.3, h - ch, (d - cd) * 0.7);   // tighter sideways: the lip centre stays put
    if (r > 1.1 * H) return false;
    const w = 1 - THREE.MathUtils.smoothstep(r, 0.3 * H, 1.1 * H);
    if (w <= 0) return false;
    out.addScaledVector(F.up, 0.34 * H * w).addScaledVector(F.right, side * 0.26 * H * w).addScaledVector(F.fwd, -0.14 * H * w);
    return true;
  });
}

// lips drawn towards the centre and pushed forward (O / U sounds)
function buildPuckerMorph(mesh, F, L, corners) {
  const half = Math.abs(corners[0][0] - corners[1][0]) / 2;
  const { mouthH, mouthD, H } = L;
  return regionMorph(mesh, F, (s, h, d, pos, out) => {
    const r = Math.hypot(s / 1.15, (h - mouthH) * 1.6);
    if (r > 1.05 * half || d < mouthD - 2 * H) return false;
    const w = 1 - THREE.MathUtils.smoothstep(r, 0.45 * half, 1.05 * half);
    if (w <= 0) return false;
    out.addScaledVector(F.right, -s * 0.38 * w).addScaledVector(F.fwd, 0.22 * H * w);
    return true;
  });
}

// inner brows lift (the region between and just above the eyes)
function buildBrowMorph(mesh, F, eyeL, eyeR) {
  const cs = (eyeL.cs + eyeR.cs) / 2, R = (eyeL.R + eyeR.R) / 2;
  const ch = (eyeL.ch + eyeR.ch) / 2 + 1.9 * R, cd = (eyeL.cd + eyeR.cd) / 2;
  return regionMorph(mesh, F, (s, h, d, pos, out) => {
    const r = Math.hypot((s - cs) / 1.6, h - ch);
    if (r > 2.0 * R || d < cd - 2 * R) return false;
    const w = 1 - THREE.MathUtils.smoothstep(r, 0.6 * R, 2.0 * R);
    if (w <= 0) return false;
    out.addScaledVector(F.up, 0.6 * R * w).addScaledVector(F.fwd, 0.1 * R * w);
    return true;
  });
}

function synthesizeFace() {
  const meshes = [];
  avatar.updateWorldMatrix(true, true);
  avatar.traverse((o) => {
    if (o.isSkinnedMesh && !JAW_SKIP_RE.test(o.material.name) && !JAW_SKIP_RE.test(o.name)) meshes.push(o);
  });
  if (!meshes.length) return false;
  const F = geomFrame(meshes[0]);
  const L = findMouthLine(meshes, F);
  if (!L) return false;

  // jaw: every mesh that reaches into the mouth region (skin, teeth, tongue, …)
  let ok = false;
  const v = new THREE.Vector3();
  for (const m of meshes) {
    const p = m.geometry.attributes.position;
    let hMin = Infinity, hMax = -Infinity, dMax = -Infinity;
    for (let i = 0; i < p.count; i++) {
      const [, h, d] = proj(p, i, F, v);
      hMin = Math.min(hMin, h); hMax = Math.max(hMax, h); dMax = Math.max(dMax, d);
    }
    if (hMax < L.mouthH - 3 * L.H || hMin > L.mouthH + L.H || dMax < L.mouthD - 3 * L.H) continue;
    const delta = buildJawMorph(m, L, F);
    if (delta) { addMorph(m, "jawOpen", delta); if (!morphMeshes.includes(m)) morphMeshes.push(m); ok = true; }
  }
  if (!ok) return false;

  // expressions live on the head skin (the largest candidate mesh)
  const head = meshes.reduce((a, m) => (m.geometry.attributes.position.count > a.geometry.attributes.position.count ? m : a));
  const p = head.geometry.attributes.position;
  const built = ["jawOpen"];

  // mouth corners: the lips touch along a line of duplicated vertices (one copy
  // per lip); its outermost duplicates are the corners. Cheek vertices at the
  // same height would otherwise pass for corners, so keep to the lip front.
  let cL = null, cR = null;
  const seen = new Set();
  for (let i = 0; i < p.count; i++) {
    const [s, h, d] = proj(p, i, F, v);
    if (Math.abs(h - L.mouthH) > 0.2 * L.H || d < L.mouthD - 0.6 * L.H) continue;
    const key = `${s.toFixed(4)},${h.toFixed(4)},${d.toFixed(4)}`;
    if (!seen.has(key)) { seen.add(key); continue; }
    if (!cL || s > cL[0]) cL = [s, h, d];
    if (!cR || s < cR[0]) cR = [s, h, d];
  }
  if (cL && cR && cL[0] - cR[0] > 0.6 * L.H) {
    const dl = buildSmileMorph(head, F, cL, L.H), dr = buildSmileMorph(head, F, cR, L.H);
    if (dl) { addMorph(head, "mouthSmileLeft", dl); built.push("mouthSmileLeft"); }
    if (dr) { addMorph(head, "mouthSmileRight", dr); built.push("mouthSmileRight"); }
    const dp = buildPuckerMorph(head, F, L, [cL, cR]);
    if (dp) { addMorph(head, "mouthPucker", dp); built.push("mouthPucker"); }
  }

  // eyes: lids rotate about the eye bones (= eyeball centres in bind space)
  if (bones.LeftEye && bones.RightEye) {
    const islands = smallIslands(head.geometry);
    const eyeL = findEye(F, bones.LeftEye, head, islands), eyeR = findEye(F, bones.RightEye, head, islands);
    const bl = buildBlinkMorph(head, F, eyeL), br = buildBlinkMorph(head, F, eyeR);
    if (bl) { addMorph(head, "eyeBlinkLeft", bl); built.push("eyeBlinkLeft"); }
    if (br) { addMorph(head, "eyeBlinkRight", br); built.push("eyeBlinkRight"); }
    const bb = buildBrowMorph(head, F, eyeL, eyeR);
    if (bb) { addMorph(head, "browInnerUp", bb); built.push("browInnerUp"); }
  }
  if (!morphMeshes.includes(head)) morphMeshes.push(head);
  console.log("synthetic face built:", built.join(", "));
  return true;
}

/* ============================================================
   Idle animation (blink, breathe, sway, eye saccades)
   ============================================================ */
const clock = new THREE.Clock();
let nextBlink = 1.5, blinkT = -1;
let nextSaccade = 1, eyeYaw = 0, eyePitch = 0, eyeYawT = 0, eyePitchT = 0;

/* ---- hand gestures while speaking ----------------------------------------
   A small library of "explaining" poses: target directions for the upper arm
   and forearm of each side. While speaking the teacher drifts between them on
   a natural beat (every ~1.5–3 s), hands lift slightly on each spoken word,
   and everything eases back to a relaxed pose when speech ends.            */
const ARM_BONES = ["LeftArm", "RightArm", "LeftForeArm", "RightForeArm"];   // parents first
// [x, y, z] world directions for the avatar's LEFT side; x is mirrored for the right
const GESTURES = {
  // twist: forearm roll that turns the palm inward/up (0 = as the rig ships)
  rest:    { twist: 0, L: { up: [0.16, -1.00, 0.06], fore: [0.10, -1.00, 0.24] },
             R: { up: [0.16, -1.00, 0.06], fore: [0.10, -1.00, 0.24] } },
  explain: { twist: 0.9, L: { up: [0.22, -0.95, 0.30], fore: [0.20,  0.05, 1.00] },
             R: { up: [0.22, -0.95, 0.30], fore: [0.20,  0.05, 1.00] } },
  open:    { twist: 0.9, L: { up: [0.30, -0.92, 0.22], fore: [0.45,  0.00, 0.80] },
             R: { up: [0.30, -0.92, 0.22], fore: [0.45,  0.00, 0.80] } },
  leftUp:  { twist: 0.6, L: { up: [0.20, -0.90, 0.35], fore: [0.05,  0.20, 0.95] },
             R: { up: [0.16, -1.00, 0.10], fore: [0.05, -0.75, 0.65] } },
  rightUp: { twist: 0.6, L: { up: [0.16, -1.00, 0.10], fore: [0.05, -0.75, 0.65] },
             R: { up: [0.20, -0.90, 0.35], fore: [0.05,  0.20, 0.95] } },
  low:     { twist: 1.1, L: { up: [0.18, -1.00, 0.18], fore: [-0.25, -0.35, 0.90] },
             R: { up: [0.18, -1.00, 0.18], fore: [-0.25, -0.35, 0.90] } },
};
const TALK_GESTURES = ["explain", "open", "leftUp", "rightUp", "low", "explain"];
const armCur = {};                // bone name -> current (smoothed) direction
const armTwist = {};              // forearm name -> current (smoothed) twist
const _gTarget = new THREE.Vector3();
let gestureName = "rest", nextGesture = 0;
let wordPulse = 0;                // spikes to 1 on each word, decays

function gestureDir(g, bone) {
  const side = /^Left/.test(bone) ? "L" : "R";
  const d = /ForeArm$/.test(bone) ? GESTURES[g][side].fore : GESTURES[g][side].up;
  return _gTarget.set(side === "L" ? d[0] : -d[0], d[1], d[2]);
}

function poseArms(dt, t) {
  if (!restPose.LeftArm) return;
  wordPulse = Math.max(0, wordPulse - dt * 6);

  nextGesture -= dt;
  if (speaking) {
    if (nextGesture <= 0 || gestureName === "rest") {
      let g;
      do g = TALK_GESTURES[Math.floor(Math.random() * TALK_GESTURES.length)]; while (g === gestureName);
      gestureName = g;
      nextGesture = 1.5 + Math.random() * 1.5;
    }
  } else if (gestureName !== "rest") {
    gestureName = "rest"; nextGesture = 0;
  }

  const k = 1 - Math.exp(-dt * (speaking ? 4.5 : 3));   // ease-out blend
  const sway = Math.sin(t * 1.7) * 0.03;
  for (const n of ARM_BONES) {
    const left = /^Left/.test(n);
    const d = gestureDir(gestureName, n);
    if (/ForeArm$/.test(n)) {
      if (speaking) {
        d.y += wordPulse * 0.22 + sway;                        // hands lift a little on each word
        d.x += (left ? 1 : -1) * Math.sin(t * 1.3 + (left ? 0 : 1.5)) * 0.03;
      } else {
        d.z += sway * 0.4;                                     // barely-there idle drift
      }
    }
    if (!armCur[n]) armCur[n] = d.clone();
    armCur[n].lerp(d, k);
    let tw = 0;
    if (/ForeArm$/.test(n)) {
      const want = GESTURES[gestureName].twist * (left ? -1 : 1);
      tw = armTwist[n] = (armTwist[n] ?? 0) + (want - (armTwist[n] ?? 0)) * k;
    }
    aimBone(n, armCur[n], tw);
  }
}

function idle(dt, t) {
  // blink
  nextBlink -= dt;
  if (nextBlink <= 0 && blinkT < 0) { blinkT = 0; nextBlink = 2 + Math.random() * 4; }
  if (blinkT >= 0) {
    blinkT += dt;
    const p = blinkT / 0.14;                       // ~140ms blink
    const v = p < 1 ? Math.sin(Math.min(p, 1) * Math.PI) : 0;
    setMorph("eyeBlinkLeft", v);
    setMorph("eyeBlinkRight", v);
    if (toon) toon.eyes.forEach((e) => (e.scale.y = 1 - 0.92 * v));
    if (blinkT > 0.16) { blinkT = -1; setMorph("eyeBlinkLeft", 0); setMorph("eyeBlinkRight", 0); }
  }

  // body motion — skip when an embedded clip is already animating the skeleton
  if (!hasEmbeddedIdle) {
    const breath = Math.sin(t * 1.6) * 0.012;
    if (bones.Spine1) bones.Spine1.rotation.x = breath;
    if (bones.Spine2) bones.Spine2.rotation.x = breath * 0.6;

    const talk = speaking ? 1 : 0.35;
    if (bones.Hips) bones.Hips.position.x = Math.sin(t * 0.4) * 0.01;
    if (bones.Neck) {
      bones.Neck.rotation.y = Math.sin(t * 0.7) * 0.05 * talk;
      bones.Neck.rotation.x = Math.sin(t * 0.9 + 1) * 0.03 * talk;
    }
    if (bones.Head) {
      bones.Head.rotation.y = Math.sin(t * 1.1 + 0.5) * 0.06 * talk + eyeYaw * 0.15;
      bones.Head.rotation.x = Math.sin(t * 1.3) * 0.03 * talk;
      bones.Head.rotation.z = Math.sin(t * 0.5) * 0.02 * talk;
      // models without mouth shapes still show they're talking: nod on each word
      if (speaking && !useVisemes() && !hasMorph("jawOpen")) bones.Head.rotation.x += wordPulse * 0.035;
    }
    poseArms(dt, t);
  } else if (speaking && bones.Head) {
    // clip is running; add a little extra nod while speaking
    bones.Head.rotation.y += Math.sin(t * 3.0) * 0.03;
  }

  // eye saccades
  nextSaccade -= dt;
  if (nextSaccade <= 0) {
    eyeYawT = (Math.random() - 0.5) * 0.5;
    eyePitchT = (Math.random() - 0.5) * 0.3;
    nextSaccade = 0.6 + Math.random() * 2.5;
  }
  eyeYaw += (eyeYawT - eyeYaw) * Math.min(1, dt * 12);
  eyePitch += (eyePitchT - eyePitch) * Math.min(1, dt * 12);
  if (bones.LeftEye) { bones.LeftEye.rotation.y = eyeYaw; bones.LeftEye.rotation.x = eyePitch; }
  if (bones.RightEye) { bones.RightEye.rotation.y = eyeYaw; bones.RightEye.rotation.x = eyePitch; }

  if (toon) {
    // pupils track the saccade; gentle breathing on the whole body
    toon.eyes.forEach((e) => {
      e.children[1].position.x = eyeYaw * 0.03;   // iris
      e.children[2].position.x = eyeYaw * 0.03;   // pupil
      e.children[1].position.y = 0.0 + eyePitch * 0.02;
      e.children[2].position.y = eyePitch * 0.02;
    });
    toon.root.position.y = Math.sin(t * 1.6) * 0.006 + (speaking ? Math.sin(t * 9) * 0.004 : 0);
    toon.root.rotation.y = Math.sin(t * 0.3) * 0.05;
  }
}

/* ============================================================
   Lip sync — visemes derived from the spoken text, scheduled
   against SpeechSynthesis word-boundary events.
   ============================================================ */
const VISEMES = [
  "viseme_sil","viseme_PP","viseme_FF","viseme_TH","viseme_DD","viseme_kk",
  "viseme_CH","viseme_SS","viseme_nn","viseme_RR","viseme_aa","viseme_E",
  "viseme_I","viseme_O","viseme_U",
];
const useVisemes = () => hasMorph("viseme_aa");

function wordToVisemes(w) {
  w = w.toLowerCase().replace(/[^a-z]/g, "");
  const out = [];
  for (let i = 0; i < w.length; i++) {
    const c = w[i], c2 = w[i + 1];
    let v = "viseme_sil";
    if (c === "t" && c2 === "h") { v = "viseme_TH"; i++; }
    else if ((c === "c" || c === "s") && c2 === "h") { v = "viseme_CH"; i++; }
    else if (c === "a") v = "viseme_aa";
    else if (c === "e") v = "viseme_E";
    else if (c === "i" || c === "y") v = "viseme_I";
    else if (c === "o") v = "viseme_O";
    else if (c === "u" || c === "w") v = "viseme_U";
    else if ("bpm".includes(c)) v = "viseme_PP";
    else if ("fv".includes(c)) v = "viseme_FF";
    else if ("td".includes(c)) v = "viseme_DD";
    else if ("nl".includes(c)) v = "viseme_nn";
    else if ("kgcq".includes(c)) v = "viseme_kk";
    else if ("szxj".includes(c)) v = "viseme_SS";
    else if (c === "r") v = "viseme_RR";
    else if (c === "h") v = "viseme_sil";
    if (!(out.length && out[out.length - 1] === v)) out.push(v);
  }
  return out.length ? out : ["viseme_aa"];
}

const OPEN = { viseme_aa: 0.9, viseme_E: 0.5, viseme_I: 0.35, viseme_O: 0.8, viseme_U: 0.5 };
let curViseme = "viseme_sil", curOpen = 0, targetOpen = 0, targetViseme = "viseme_sil";
let curPucker = 0, curStretch = 0;        // O/U rounding and E/I widening for the synthetic mouth
let visemeTimers = [];

function clearVisemeTimers() { visemeTimers.forEach(clearTimeout); visemeTimers = []; }

function playWord(word, ms) {
  clearVisemeTimers();
  const seq = wordToVisemes(word);
  const step = Math.max(45, ms / seq.length);
  seq.forEach((v, k) => {
    visemeTimers.push(setTimeout(() => {
      targetViseme = v;
      targetOpen = OPEN[v] ?? 0.16;
    }, k * step));
  });
  visemeTimers.push(setTimeout(() => { targetViseme = "viseme_sil"; targetOpen = 0.06; }, seq.length * step));
}

function restMouth() {
  clearVisemeTimers();
  targetViseme = "viseme_sil"; targetOpen = 0; curOpen = 0;
  if (useVisemes()) VISEMES.forEach((v) => setMorph(v, 0));
  setMorph("jawOpen", 0);
  setMorph("mouthClose", 0);
  curPucker = 0; curStretch = 0;
  setMorph("mouthPucker", 0);
  if (toon) {
    toon.lips.scale.set(1.5, 0.16, 1);
    toon.teeth.visible = false;
    toon.tongue.visible = false;
  }
}

function updateMouth(dt) {
  curOpen += (targetOpen - curOpen) * Math.min(1, dt * (targetOpen > curOpen ? 24 : 14));
  if (curViseme !== targetViseme) {
    if (useVisemes()) setMorph(curViseme, 0);
    curViseme = targetViseme;
  }
  if (useVisemes()) {
    VISEMES.forEach((v) => { if (v !== curViseme) setMorph(v, 0); });
    setMorph(curViseme, curViseme === "viseme_sil" ? 0 : Math.min(1, curOpen + 0.1));
  }
  // jaw always helps readability
  setMorph("jawOpen", curOpen * 0.55);
  // round the lips on O / U and widen them on E / I (real visemes do this themselves)
  const round = !useVisemes() && (curViseme === "viseme_O" || curViseme === "viseme_U") ? 0.75 : 0;
  const wide = !useVisemes() && (curViseme === "viseme_E" || curViseme === "viseme_I") ? 0.35 : 0;
  curPucker += (round - curPucker) * Math.min(1, dt * 16);
  curStretch += (wide - curStretch) * Math.min(1, dt * 16);
  setMorph("mouthPucker", curPucker);
  // light smile while talking
  const s = (speaking ? 0.12 + curOpen * 0.1 : 0.06) + curStretch;
  setMorph("mouthSmileLeft", s);
  setMorph("mouthSmileRight", s);

  // cartoon mouth: scale the lip line + reveal cavity / teeth
  if (toon) {
    const o = Math.max(0, Math.min(1, curOpen));
    toon.lips.scale.set(1.5 - o * 0.35, 0.16 + o * 1.25, 1);
    toon.lips.position.y = -o * 0.03;
    toon.teeth.visible = o > 0.12;
    toon.tongue.visible = o > 0.35;
    const smile = (speaking ? 0.14 : 0.06) + o * 0.05;
    toon.mouth.rotation.z = 0;
    toon.lips.rotation.z = 0;
    toon.brows.position.y = (speaking ? Math.sin(performance.now() * 0.004) * 0.006 : 0);
    toon.mouth.scale.x = 1 + smile; // widen corners a bit
  }
}

/* ============================================================
   Voice
   ============================================================ */
let voices = [];
function refreshVoices() { voices = window.speechSynthesis ? speechSynthesis.getVoices() : []; }
refreshVoices();
if (window.speechSynthesis) speechSynthesis.onvoiceschanged = refreshVoices;

const FEMALE_RE = /female|woman|zira|aria|jenny|jane|hazel|susan|linda|samantha|catherine|serena|tessa|fiona|karen|moira|veena|google uk english female|google us english/i;
const MALE_RE = /\bmale\b|\bman\b|david|guy|mark|george|james|ryan|daniel|thomas|oliver|arthur|google uk english male/i;

function pickVoice(g) {
  if (!voices.length) return null;
  const en = voices.filter((v) => /^en(-|_|$)/i.test(v.lang));
  const pool = en.length ? en : voices;
  const want = g === "male" ? MALE_RE : FEMALE_RE;
  const avoid = g === "male" ? FEMALE_RE : MALE_RE;
  return pool.find((v) => want.test(v.name))
      || pool.find((v) => !avoid.test(v.name))
      || pool[0];
}

/* ============================================================
   Speaking
   ============================================================ */
let speaking = false;
let wordTimers = [];
let pendingSpeech = null;         // text refused by the autoplay policy, spoken on first gesture
function deferSpeech(text) {
  pendingSpeech = text;
  const go = () => { const t = pendingSpeech; pendingSpeech = null; if (t) speak(t); };
  document.addEventListener("pointerdown", go, { once: true });
  document.addEventListener("keydown", go, { once: true });
}
const clearWordTimers = () => { wordTimers.forEach(clearTimeout); wordTimers = []; };

function onWord(word, ms) {
  playWord(word, ms);
  wordPulse = 1;
  if (Math.random() < 0.22) pulseBrow();
}

// Some voices never fire word-boundary events; without them there is no
// lip-sync and no gesturing at all. Estimate the timing from the text instead
// (~13 chars/s at rate 1, plus short pauses at punctuation).
function scheduleWordsFallback(text, rate) {
  clearWordTimers();
  let at = 0;
  const re = /([A-Za-z']+)([^A-Za-z']*)/g;
  let m;
  while ((m = re.exec(text))) {
    const word = m[1], gap = m[2];
    const ms = Math.max(160, ((word.length + 1) / 13) * 1000 / rate);
    wordTimers.push(setTimeout(() => onWord(word, ms), at));
    at += ms + (/[.!?]/.test(gap) ? 380 : /[,;:]/.test(gap) ? 200 : 0);
  }
}

function speak(text) {
  if (!window.speechSynthesis) return;
  speechSynthesis.cancel();
  clearWordTimers();
  const u = new SpeechSynthesisUtterance(text);
  const v = pickVoice(gender);
  if (v) u.voice = v;
  u.lang = (v && v.lang) || "en-US";
  const tv = (personaFor(gender) || teacher || {}).voice || {};
  u.rate = tv.rate ?? 1;
  u.pitch = tv.pitch ?? (gender === "male" ? 0.95 : 1.05);

  let sawBoundary = false;
  u.onstart = () => {
    speaking = true;
    emit("speaking", { state: true });
    wordTimers.push(setTimeout(() => { if (!sawBoundary && speaking) scheduleWordsFallback(text, u.rate); }, 350));
  };
  u.onend = () => { speaking = false; clearWordTimers(); restMouth(); emit("speaking", { state: false }); };
  u.onerror = (e) => {
    speaking = false; clearWordTimers(); restMouth(); emit("speaking", { state: false });
    if (e && e.error === "not-allowed") deferSpeech(text);
  };

  u.onboundary = (e) => {
    if (e.name && e.name !== "word") return;
    if (!sawBoundary) { sawBoundary = true; clearWordTimers(); }
    const rest = text.slice(e.charIndex);
    const m = rest.match(/^\s*([A-Za-z']+)/);
    const word = m ? m[1] : "";
    // rough per-word duration from speech rate (~13 chars/sec at rate 1)
    const ms = Math.max(160, (word.length / 13) * 1000 / u.rate);
    if (word) onWord(word, ms);
  };

  speechSynthesis.speak(u);
}

let browT = -1;
function pulseBrow() { browT = 0; }
function updateBrow(dt) {
  if (browT < 0) return;
  browT += dt;
  const v = Math.sin(Math.min(browT / 0.45, 1) * Math.PI) * 0.35;
  setMorph("browInnerUp", v);
  if (browT > 0.5) { browT = -1; setMorph("browInnerUp", 0); }
}

/* ============================================================
   AI request
   ============================================================ */
async function ask() {
  const q = questionInput.value.trim();
  if (!q || askBtn.disabled) return;
  askBtn.disabled = true;
  hint.textContent = "Teacher is thinking…";
  answerBox.textContent = "";
  emit("thinking", { question: q });

  try {
    const res = await fetch(`${API_BASE}/api/ai/teacher`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...(TOKEN ? { Authorization: `Bearer ${TOKEN}` } : {}),
      },
      body: JSON.stringify({ message: q, subject: SUBJECT, gender }),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(data.error || `Request failed (${res.status})`);

    const answer = (data.reply || "").trim() || "(no answer)";
    answerBox.textContent = answer;
    questionInput.value = "";
    hint.textContent = "Ready";
    emit("answer", { question: q, answer });
    speak(answer);
  } catch (e) {
    console.error(e);
    answerBox.textContent = `⚠️ ${e.message}`;
    hint.textContent = "Ready";
    emit("error", { message: e.message });
  } finally {
    askBtn.disabled = false;
  }
}

/* ============================================================
   UI wiring
   ============================================================ */
function setButtons(which) {
  fBtn.classList.toggle("on", which === "female");
  mBtn.classList.toggle("on", which === "male");
}
fBtn.addEventListener("click", () => switchGender("female"));
mBtn.addEventListener("click", () => switchGender("male"));

function switchGender(g) {
  if (g === gender && avatar) return;
  gender = g;
  if (window.speechSynthesis) speechSynthesis.cancel();
  speaking = false;
  showTeacherBadge();
  const p = personaFor(gender);
  if (p) emit("character", { gender, name: p.name, title: p.title || teacher.subject });
  loadAvatar(g);
}

askBtn.addEventListener("click", ask);
questionInput.addEventListener("keydown", (e) => { if (e.key === "Enter") ask(); });
window.addEventListener("message", (e) => {
  const d = e.data;
  if (!d) return;
  if (d.type === "ask" && typeof d.question === "string") {
    questionInput.value = d.question; ask();
  }
  if (d.type === "setGender" && (d.gender === "female" || d.gender === "male")) {
    switchGender(d.gender);
  }
});

// small API for the embedding page / console: teacher3d.speak("..."), teacher3d.switchGender("male")
window.teacher3d = { speak, switchGender, ask };

window.addEventListener("resize", () => {
  camera.aspect = window.innerWidth / window.innerHeight;
  camera.updateProjectionMatrix();
  renderer.setSize(window.innerWidth, window.innerHeight);
});

/* ============================================================
   Loop
   ============================================================ */
function tick() {
  requestAnimationFrame(tick);
  const dt = Math.min(clock.getDelta(), 0.05);
  const t = clock.elapsedTime;
  if (mixer) mixer.update(dt);
  if (avatar) {
    idle(dt, t);
    updateMouth(dt);
    updateBrow(dt);
  }
  controls.update();
  renderer.render(scene, camera);
}
tick();

loadTeacher().then(() => {
  showTeacherBadge();
  if (teacher && teacher.accent) setBackdrop(teacher.accent);
  loadAvatar(gender);
});
window.__teacherSay = speak;      // debug: __teacherSay("Hello class") from the console
window.__teacherMorph = setMorph; // debug: __teacherMorph("eyeBlinkLeft", 1)
