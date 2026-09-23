/**
 * Login for the re-annotation study.
 *
 * Two annotators re-label the research images independently so the thesis can
 * report an inter-annotator agreement figure instead of resting on the
 * researcher's own labels. They are not app users and have no Google account
 * here: they type a code, and this function trades it for a Firebase custom
 * token. Security rules key off the claims in that token.
 *
 * This lives in its own Functions codebase on purpose. A mistake here cannot
 * break function discovery for `classifyWaste`, which is the backend the
 * thesis results depend on.
 */
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const { initializeApp, getApps } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const crypto = require("crypto");
const gerbang = require("./gerbang");

if (!getApps().length) initializeApp();

const REGION = "asia-southeast2";
const KOL_AKUN = "anotasi_akun";
const KOL_GERBANG = "anotasi_gerbang";

/** Same wording for every refusal: a different one would confirm valid codes. */
const DITOLAK = () => new HttpsError("permission-denied", "Kode tidak dikenali.");

/**
 * Refusals are slowed deliberately, so the answer takes the same visible time
 * whether or not the code exists.
 * @param {number} ms Milliseconds to wait.
 * @return {Promise<void>}
 */
const jeda = (ms) => new Promise((r) => setTimeout(r, ms));

/**
 * Gate document for one caller address, plus a shared global gate.
 * @param {string} alamat Caller IP.
 * @return {string} Document id.
 */
function kunciGerbang(alamat) {
  return "ip_" + crypto.createHash("sha256").update(alamat).digest("hex").slice(0, 32);
}

/**
 * Reads gate state as plain milliseconds.
 * @param {FirebaseFirestore.DocumentSnapshot} snap Gate document.
 * @return {{gagal: number, jendelaSejak: number, terkunciHingga: number}} State.
 */
function jejakDari(snap) {
  const d = snap.exists ? snap.data() : {};
  return {
    gagal: d.gagal || 0,
    jendelaSejak: d.jendelaSejak ? d.jendelaSejak.toMillis() : 0,
    terkunciHingga: d.terkunciHingga ? d.terkunciHingga.toMillis() : 0,
  };
}

/**
 * Writes gate state back, converting milliseconds to timestamps.
 * @param {FirebaseFirestore.DocumentReference} ref Gate document.
 * @param {object} jejak New state.
 * @return {Promise<void>}
 */
function simpanJejak(ref, jejak) {
  return ref.set({
    gagal: jejak.gagal,
    jendelaSejak: jejak.jendelaSejak ? new Date(jejak.jendelaSejak) : null,
    terkunciHingga: jejak.terkunciHingga ? new Date(jejak.terkunciHingga) : null,
    terakhir: FieldValue.serverTimestamp(),
  }, { merge: true });
}

exports.masukAnotator = onCall(
    { region: REGION, timeoutSeconds: 60, memory: "256MiB" },
    async (request) => {
      const db = getFirestore();
      const sekarang = Date.now();
      const kode = gerbang.normalkan((request.data || {}).kode);

      const alamat = (request.rawRequest && request.rawRequest.ip) || "tanpa-alamat";
      const rujukanIp = db.collection(KOL_GERBANG).doc(kunciGerbang(alamat));
      const rujukanGlobal = db.collection(KOL_GERBANG).doc("global");
      const [snapIp, snapGlobal] = await db.getAll(rujukanIp, rujukanGlobal);
      const jejakIp = jejakDari(snapIp);
      const jejakGlobal = jejakDari(snapGlobal);

      for (const jejak of [jejakIp, jejakGlobal]) {
        const putusan = gerbang.periksa(jejak, sekarang);
        if (putusan.terkunci) {
          throw new HttpsError(
              "resource-exhausted",
              "Terlalu banyak percobaan. Coba lagi nanti.",
              { detikTunggu: putusan.detikTunggu });
        }
      }

      /**
       * Records the failure on both gates, waits, then refuses.
       * @return {Promise<never>}
       */
      async function tolak() {
        await Promise.all([
          simpanJejak(rujukanIp, gerbang.gagalSekali(jejakIp, sekarang)),
          simpanJejak(rujukanGlobal,
              gerbang.gagalSekali(jejakGlobal, sekarang, gerbang.GAGAL_GLOBAL)),
        ]);
        await jeda(300);
        throw DITOLAK();
      }

      if (kode.length < 6 || kode.length > 64) return tolak();

      // Every account is checked, with no early exit, so the time taken does
      // not depend on which account the code belongs to.
      const akunSnap = await db.collection(KOL_AKUN).get();
      let cocok = null;
      for (const d of akunSnap.docs) {
        const akun = d.data();
        if (!akun.garam || !akun.hash) continue;
        const sama = gerbang.samaAman(
            gerbang.turunan(kode, akun.garam, akun.iterasi || 210000), akun.hash);
        if (sama && akun.aktif) cocok = akun;
      }
      if (!cocok) return tolak();

      await Promise.all([
        simpanJejak(rujukanIp, gerbang.BERHASIL),
        db.collection(KOL_AKUN).doc(cocok.idAnotator).set({
          gagal: 0, terkunciHingga: null, masukTerakhir: FieldValue.serverTimestamp(),
        }, { merge: true }),
      ]);

      const peran = cocok.peran === "peneliti" ? "peneliti" : "anotator";
      const klaim = {
        anotator: peran === "anotator",
        peran,
        idAnotator: cocok.idAnotator,
      };
      const token = await getAuth().createCustomToken(cocok.uid || cocok.idAnotator, klaim);
      logger.info(`${cocok.idAnotator} masuk sebagai ${peran}`);
      return {
        token,
        idAnotator: cocok.idAnotator,
        nama: cocok.nama || cocok.idAnotator,
        peran,
      };
    },
);
