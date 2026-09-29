/* Facial-recognition capture page. Embedded by the Flutter Attendance screen.
 *
 * URL params:
 *   mode=scan | enroll
 *   studentId=<n>          (enroll only)
 *   token=<jwt>            (Bearer for API calls)
 *   api=<base>             (default: same origin)
 */
(() => {
  const qs = new URLSearchParams(location.search);
  const MODE = qs.get('mode') === 'enroll' ? 'enroll' : 'scan';
  const STUDENT_ID = qs.get('studentId');
  const TOKEN = qs.get('token') || '';
  const API = (qs.get('api') || location.origin).replace(/\/$/, '');

  const video = document.getElementById('video');
  const overlay = document.getElementById('overlay');
  const octx = overlay.getContext('2d');
  const statusEl = document.getElementById('status');
  const captureBtn = document.getElementById('capture');
  const toastEl = document.getElementById('toast');

  const setStatus = (t) => (statusEl.textContent = t);
  let toastTimer = null;
  const toast = (t) => {
    toastEl.textContent = t;
    toastEl.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => toastEl.classList.remove('show'), 2500);
  };
  const post = (msg) => parent.postMessage({ source: 'face', ...msg }, '*');

  async function api(path, body) {
    const res = await fetch(API + path, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer ' + TOKEN,
      },
      body: JSON.stringify(body),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw new Error(data.message || 'Request failed (' + res.status + ')');
    return data;
  }

  const detectOpts = new faceapi.TinyFaceDetectorOptions({
    inputSize: 320,
    scoreThreshold: 0.5,
  });

  function fitOverlay() {
    overlay.width = video.videoWidth || overlay.clientWidth;
    overlay.height = video.videoHeight || overlay.clientHeight;
  }

  function drawBox(box, label, color) {
    octx.strokeStyle = color;
    octx.lineWidth = 3;
    octx.strokeRect(box.x, box.y, box.width, box.height);
    if (label) {
      octx.font = '600 16px sans-serif';
      const w = octx.measureText(label).width + 12;
      octx.fillStyle = color;
      octx.fillRect(box.x, box.y - 24, w, 24);
      octx.fillStyle = '#0b1220';
      octx.fillText(label, box.x + 6, box.y - 6);
    }
  }

  // ---- scan mode -----------------------------------------------------------
  const recentlySeen = new Map(); // studentCode -> timestamp
  const COOLDOWN_MS = 20000;
  let scanning = false;

  async function scanLoop() {
    if (scanning) return;
    scanning = true;
    try {
      const results = await faceapi
        .detectAllFaces(video, detectOpts)
        .withFaceLandmarks()
        .withFaceDescriptors();

      fitOverlay();
      octx.clearRect(0, 0, overlay.width, overlay.height);

      for (const r of results) {
        const box = r.detection.box;
        let color = '#f59e0b';
        let label = 'Checking…';
        try {
          const out = await api('/api/attendance/recognize', {
            descriptor: Array.from(r.descriptor),
          });
          if (out.matched) {
            color = out.status === 'late' ? '#f59e0b' : '#22c55e';
            label = out.student.name + (out.alreadyMarked ? ' ✓' : '');
            const last = recentlySeen.get(out.student.studentCode) || 0;
            if (Date.now() - last > COOLDOWN_MS) {
              recentlySeen.set(out.student.studentCode, Date.now());
              if (!out.alreadyMarked) {
                toast(out.student.name + ' — ' + out.status);
              }
              post({ type: 'attendance', student: out.student, status: out.status,
                     alreadyMarked: out.alreadyMarked, summary: out.summary });
            }
          } else {
            color = '#ef4444';
            label = 'Unknown';
          }
        } catch (e) {
          label = 'Error';
        }
        drawBox(box, label, color);
      }

      setStatus(
        results.length
          ? results.length + ' face' + (results.length > 1 ? 's' : '') + ' in frame'
          : 'Looking for faces…'
      );
    } catch (e) {
      setStatus('Detection error: ' + e.message);
    } finally {
      scanning = false;
    }
  }

  // ---- enroll mode --------------------------------------------------------
  let previewTimer = null;
  function previewLoop() {
    faceapi
      .detectSingleFace(video, detectOpts)
      .then((det) => {
        fitOverlay();
        octx.clearRect(0, 0, overlay.width, overlay.height);
        if (det) drawBox(det.box, null, '#2d66f6');
        captureBtn.disabled = !det;
        setStatus(det ? 'Face detected — hold still and Capture' : 'Position your face in the frame');
      })
      .catch(() => {});
  }

  async function capture() {
    captureBtn.disabled = true;
    setStatus('Capturing…');
    try {
      const r = await faceapi
        .detectSingleFace(video, detectOpts)
        .withFaceLandmarks()
        .withFaceDescriptor();
      if (!r) {
        setStatus('No face — try again');
        return;
      }
      const out = await api('/api/students/' + STUDENT_ID + '/faces', {
        descriptor: Array.from(r.descriptor),
      });
      toast('Sample ' + out.faceCount + ' saved');
      setStatus('Enrolled ' + out.faceCount + ' sample(s). Capture more or close.');
      post({ type: 'enrolled', faceCount: out.faceCount });
    } catch (e) {
      setStatus('Enroll failed: ' + e.message);
    } finally {
      captureBtn.disabled = false;
    }
  }

  // ---- boot -------------------------------------------------------------
  async function start() {
    try {
      setStatus('Loading models…');
      await faceapi.nets.tinyFaceDetector.loadFromUri('./models');
      await faceapi.nets.faceLandmark68Net.loadFromUri('./models');
      await faceapi.nets.faceRecognitionNet.loadFromUri('./models');

      setStatus('Starting camera…');
      const stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: 'user', width: { ideal: 640 }, height: { ideal: 480 } },
        audio: false,
      });
      video.srcObject = stream;
      await video.play();
      fitOverlay();

      if (MODE === 'enroll') {
        if (!STUDENT_ID) {
          setStatus('Missing studentId');
          return;
        }
        captureBtn.style.display = '';
        captureBtn.addEventListener('click', capture);
        previewTimer = setInterval(previewLoop, 600);
        setStatus('Position your face in the frame');
      } else {
        setInterval(scanLoop, 1500);
        setStatus('Scanning for students…');
      }
      post({ type: 'ready', mode: MODE });
    } catch (e) {
      setStatus(
        e.name === 'NotAllowedError'
          ? 'Camera permission denied'
          : 'Startup failed: ' + e.message
      );
      post({ type: 'error', message: e.message });
    }
  }

  start();
})();
