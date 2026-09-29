// Face descriptor helpers. Descriptors are 128-float vectors produced by
// face-api.js in the browser; the backend only stores and compares them.

export const DESCRIPTOR_LENGTH = 128;

// Standard face-api.js match cutoff. Lower = stricter.
export const MATCH_THRESHOLD = 0.5;

export function euclidean(a, b) {
  let sum = 0;
  for (let i = 0; i < a.length; i++) {
    const d = a[i] - b[i];
    sum += d * d;
  }
  return Math.sqrt(sum);
}

export function isValidDescriptor(d) {
  return (
    Array.isArray(d) &&
    d.length === DESCRIPTOR_LENGTH &&
    d.every((n) => typeof n === "number" && Number.isFinite(n))
  );
}
