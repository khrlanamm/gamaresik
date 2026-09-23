/**
 * Gate logic for the annotation login, kept free of Firebase so it can be
 * unit-tested offline.
 *
 * The callable that uses this is unauthenticated by design — annotators have no
 * account until they type a code — so the gate is the only thing standing
 * between a stranger and a guessing loop. Two mechanisms do that work: PBKDF2
 * with an iteration count high enough to make each attempt cost real time, and
 * a lockout that widens the longer the guessing continues.
 */
const crypto = require("crypto");

/** Failures tolerated inside one window before the door shuts. */
const GAGAL_MAKS = 6;
/**
 * The same tally across every address, which exists only to blunt a spread-out
 * guessing loop. It sits far above GAGAL_MAKS on purpose: one annotator
 * mistyping a code must never lock the other one out.
 */
const GAGAL_GLOBAL = 40;
/** Failures counted within this window; older ones are forgotten. */
const JENDELA_MS = 15 * 60 * 1000;
/** First lockout, doubling per further failure. */
const KUNCI_AWAL_MS = 15 * 60 * 1000;
const KUNCI_MAKS_MS = 60 * 60 * 1000;

/**
 * Normalises a typed code. Must match `anotasi_akun.normalkan` in the
 * experiment repo exactly, or a code created there will never verify here.
 * @param {*} kode Raw input.
 * @return {string} Uppercase alphanumerics only.
 */
function normalkan(kode) {
  return String(kode == null ? "" : kode).trim().toUpperCase().replace(/[^A-Z0-9]/g, "");
}

/**
 * PBKDF2-HMAC-SHA256 derivation, byte-identical to hashlib.pbkdf2_hmac.
 * @param {string} kode Normalised code.
 * @param {string} garamHex Salt, hex encoded.
 * @param {number} iterasi Iteration count stored with the account.
 * @return {string} 32-byte derived key, hex encoded.
 */
function turunan(kode, garamHex, iterasi) {
  return crypto
      .pbkdf2Sync(kode, Buffer.from(garamHex, "hex"), iterasi, 32, "sha256")
      .toString("hex");
}

/**
 * Constant-time comparison that tolerates differing lengths.
 * @param {string} a First value.
 * @param {string} b Second value.
 * @return {boolean} True when equal.
 */
function samaAman(a, b) {
  const x = Buffer.from(String(a));
  const y = Buffer.from(String(b));
  if (x.length !== y.length) return false;
  return crypto.timingSafeEqual(x, y);
}

/**
 * Whether this attempt is allowed through the gate right now.
 * @param {object} jejak Stored gate state: gagal, jendelaSejak, terkunciHingga (ms).
 * @param {number} sekarang Current epoch milliseconds.
 * @return {{terkunci: boolean, detikTunggu: number}} Verdict.
 */
function periksa(jejak, sekarang) {
  const sampai = (jejak && jejak.terkunciHingga) || 0;
  if (sampai > sekarang) {
    return { terkunci: true, detikTunggu: Math.ceil((sampai - sekarang) / 1000) };
  }
  return { terkunci: false, detikTunggu: 0 };
}

/**
 * Gate state after one failed attempt.
 * @param {object} jejak Stored gate state.
 * @param {number} sekarang Current epoch milliseconds.
 * @param {number} [batas] Failures tolerated on this gate.
 * @return {{gagal: number, jendelaSejak: number, terkunciHingga: number|null}} New state.
 */
function gagalSekali(jejak, sekarang, batas) {
  const maks = batas || GAGAL_MAKS;
  const sejak = (jejak && jejak.jendelaSejak) || 0;
  const dalamJendela = sekarang - sejak < JENDELA_MS;
  const gagal = (dalamJendela ? (jejak && jejak.gagal) || 0 : 0) + 1;
  const jendelaSejak = dalamJendela ? sejak : sekarang;
  if (gagal < maks) return { gagal, jendelaSejak, terkunciHingga: null };
  const lama = Math.min(KUNCI_AWAL_MS * Math.pow(2, gagal - maks), KUNCI_MAKS_MS);
  return { gagal, jendelaSejak, terkunciHingga: sekarang + lama };
}

/** Gate state after a successful attempt. */
const BERHASIL = { gagal: 0, jendelaSejak: 0, terkunciHingga: null };

module.exports = {
  normalkan, turunan, samaAman, periksa, gagalSekali, BERHASIL,
  GAGAL_MAKS, GAGAL_GLOBAL, JENDELA_MS, KUNCI_AWAL_MS, KUNCI_MAKS_MS,
};
