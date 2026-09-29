# Teacher avatars

The 3D teacher loads these two files automatically:

    female.glb
    male.glb

If either is missing the app falls back to the built-in cartoon teacher.

## One teacher per subject

`../teachers.json` assigns a named teacher to every subject (key = the
subject name in the `subjects` table):

```json
"Mathematics": {
  "name": "Ms. Nadia Perera", "title": "Mathematics Teacher",
  "gender": "female", "avatar": "avatars/female.glb", "accent": "#2563EB",
  "voice": { "pitch": 1.08, "rate": 0.98 },
  "style": "patient and precise; solves problems step by step …",
  "greeting": "Hello! I'm Ms. Perera, your Mathematics teacher. …"
}
```

It is read by three places, so they always agree:

- **the 3D page** (`?subject=Mathematics`) — loads that teacher's `avatar`
  (falling back to `avatars/<gender>.glb`), shows the name badge, tints the
  backdrop with `accent`, uses `voice`, and speaks `greeting` on load;
- **the backend** (`/api/ai/teacher`) — the AI answers *as* that teacher,
  in the given `style`, for both the 3D screen and the text chat;
- **the Flutter app** (`/api/ai/teachers`) — every subject card names its
  teacher, and tapping the card opens that subject's classroom
  (`SubjectTeacherScreen`): the teacher's 3D avatar beside the conversation
  with them. The page is embedded with `?embedded=1`, which hides its own
  input/answer box; the app sends questions with
  `postMessage({type:"ask", question})` and receives `thinking`, `answer`,
  `error` and `greeting` events back.

To give a teacher a unique look, drop another GLB in this folder (e.g.
`avatars/math_teacher.glb`) and point that entry's `avatar` at it. Edits to
`teachers.json` take effect on the next page load — no restart needed.
Unknown subjects get the `General` teacher.

## Current status

Both files are Ready Player Me avatars re-exported through Sketchfab, which
strips every facial blendshape (no visemes, no jaw, no blink). To keep them
usable the app **rebuilds a small set of ARKit-style blendshapes at load
time** (`synthesizeFace()` in `../main.js`) from the head geometry alone:

| shape                    | how it is built                                              | driven by |
|--------------------------|--------------------------------------------------------------|-----------|
| `jawOpen`                | lower lip / chin / lower teeth rotate about a jaw pivot; vertices are labelled by mesh connectivity so the touching lips separate cleanly | lip-sync (every vowel/consonant) |
| `mouthPucker`            | lips drawn to the centre and pushed forward                  | O / U sounds |
| `mouthSmileLeft/Right`   | mouth corners (ends of the lip seam) pulled up, out and back | light smile while talking, E / I sounds |
| `eyeBlinkLeft/Right`     | eyelids rotate about the eyeball centre (found as the eye mesh or a round island of the head mesh) | blink every 2–6 s |
| `browInnerUp`            | inner brow region lifted                                     | random word emphasis |

It is not per-phoneme lip animation, but at speaking distance the teacher
now talks, blinks, smiles and raises the brows convincingly. Anything the
detection cannot find on a given model is simply skipped (the console logs
which shapes were built).

> Ready Player Me shut down its public service on 31 Jan 2026 (acquired by
> Netflix); `models.readyplayer.me` no longer exists, so avatars can no
> longer be re-exported from there.

## Getting avatars with real mouth shapes (optional)

Any GLB whose head carries **ARKit blendshapes** (`jawOpen`,
`eyeBlinkLeft`, `mouthSmileLeft`, …) and/or **Oculus visemes**
(`viseme_aa`, `viseme_PP`, …) is picked up automatically — the app checks
for `viseme_aa` / `jawOpen` and uses them instead of the synthetic jaw.
Services that export those today include Avaturn and Avatar SDK MetaPerson
(both produce Ready-Player-Me-style rigs). Export as GLB with blendshapes
enabled, name the file `female.glb` / `male.glb`, drop it here, and
hard-refresh the app (Ctrl+Shift+R).

Alternatively paste a direct GLB URL into `kFemaleAvatarUrl` /
`kMaleAvatarUrl` at the top of `lib/ui/pages/ai_teacher_3d_screen.dart`
(the host must allow CORS and be added to the `/teacher3d` CSP in
`backend/src/server.js`).

## Testing without the AI backend

Open `http://localhost:4000/teacher3d/index.html?gender=male` in a browser,
click the page once, then in the DevTools console run:

    __teacherSay("Hello class, today we will learn about fractions.")
    __teacherMorph("mouthSmileLeft", 1)   // pose one shape by hand (0..1)

This speaks the text with the browser voice and drives gestures + lip-sync
without needing a login token or Ollama.
