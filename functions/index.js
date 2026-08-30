const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getStorage } = require("firebase-admin/storage");
const { GoogleGenAI, Type } = require("@google/genai");
const {
  CATEGORIES,
  CATEGORY_TO_ID,
  CATEGORY_IDS,
  clamp,
  normalizeConfig,
  classify,
} = require("./classifier");

initializeApp();
const db = getFirestore();

const geminiApiKey = defineSecret("GEMINI_API_KEY");

const REGION = "asia-southeast2";

/** Safety rail so an oversized upload cannot blow up the function. */
const MAX_IMAGE_BYTES = 10 * 1024 * 1024;

const RESPONSE_SCHEMA = {
  type: Type.OBJECT,
  properties: {
    label: { type: Type.STRING, enum: CATEGORIES },
    confidence_score: { type: Type.NUMBER },
    reasoning: { type: Type.STRING },
  },
  required: ["label", "confidence_score"],
  propertyOrdering: ["label", "confidence_score", "reasoning"],
};

/**
 * Reads app_config/settings and normalizes it against the documented defaults.
 * @return {Promise<{mode: string, threshold: number, fewShotCount: number}>}
 */
async function loadConfig() {
  let data = {};
  try {
    const snap = await db.doc("app_config/settings").get();
    if (snap.exists) {
      data = snap.data();
    } else {
      logger.warn("app_config/settings is missing — falling back to defaults.");
    }
  } catch (err) {
    logger.error("Failed to read app_config/settings, using defaults", err);
  }
  return normalizeConfig(data, (message) => logger.warn(message));
}

function buildInstructionText(hasExamples) {
  const base = `Anda adalah sistem klasifikasi sampah untuk kampus Universitas Gadjah Mada (UGM).
Klasifikasikan gambar sampah ke dalam TEPAT SATU dari tiga kategori berikut:

1. "Organik Terpilah" — sisa makanan, kulit buah, daun, dan material yang terurai secara alami.
2. "Recycle Bersih Terpilah" — botol plastik, kertas, kardus, kaleng, atau kaca yang BERSIH, kering, dan bernilai daur ulang.
3. "Residu Terpilah" — sampah campuran atau kotor yang tidak dapat didaur ulang: kemasan sachet, popok, tisu, puntung rokok, styrofoam kotor, plastik kresek kotor, masker.

Aturan penting:
- Material daur ulang yang KOTOR atau berminyak termasuk "Residu Terpilah", bukan "Recycle Bersih Terpilah".
- Nilai confidence_score harus antara 0.0 dan 1.0 dan mencerminkan keyakinan Anda yang sebenarnya.
- Jika objek tidak jelas, ambigu, atau bukan sampah, berikan confidence_score yang rendah.
- reasoning maksimal satu kalimat singkat dalam Bahasa Indonesia.`;

  if (hasExamples) {
    return `${base}

Beberapa contoh di bawah ini sudah divalidasi oleh manusia. Pelajari pola tersebut, lalu klasifikasikan gambar utama di bagian akhir.`;
  }
  return base;
}

/**
 * Downloads a Storage object as base64, rejecting anything that is not a
 * reasonably sized image.
 * @param {string} storagePath Path within the default Storage bucket.
 * @return {Promise<{base64: string, mimeType: string}>}
 */
async function downloadImage(storagePath) {
  const file = getStorage().bucket().file(storagePath);

  const [metadata] = await file.getMetadata();
  const contentType = metadata.contentType || "";
  if (!contentType.startsWith("image/")) {
    throw new HttpsError("invalid-argument", "File yang diunggah bukan gambar.");
  }
  if (Number(metadata.size) > MAX_IMAGE_BYTES) {
    throw new HttpsError("invalid-argument", "Ukuran gambar melebihi 10 MB.");
  }

  const [buffer] = await file.download();
  return { base64: buffer.toString("base64"), mimeType: contentType };
}

/**
 * Fetches up to `count` human-validated few-shot examples, skipping any whose
 * backing image can no longer be read.
 * @param {number} count Max number of examples.
 * @return {Promise<Array<{base64: string, mimeType: string, label: string}>>}
 */
async function fetchExamples(count) {
  if (count <= 0) return [];

  let snap;
  try {
    snap = await db
        .collection("few_shot_data")
        .where("validated", "==", true)
        .orderBy("createdAt", "desc")
        .limit(count)
        .get();
  } catch (err) {
    logger.error("Failed to query few_shot_data", err);
    return [];
  }

  const examples = [];
  for (const doc of snap.docs) {
    const { storagePath, label } = doc.data();
    if (!storagePath || !CATEGORIES.includes(label)) continue;
    try {
      const { base64, mimeType } = await downloadImage(storagePath);
      examples.push({ base64, mimeType, label });
    } catch (err) {
      logger.warn(`Skipping few-shot example ${doc.id}: ${err.message}`);
    }
  }
  return examples;
}

/**
 * Translates a Gemini/network failure into a callable error the Flutter app
 * can show verbatim, so users never see a bare "INTERNAL".
 * @param {Error} err Original error.
 * @return {HttpsError}
 */
function toHttpsError(err) {
  if (err instanceof HttpsError) return err;

  const status = err && err.status;
  const message = String((err && err.message) || "");

  if (status === 429 || /RESOURCE_EXHAUSTED|quota|credits are depleted/i.test(message)) {
    logger.error("Gemini quota/credits exhausted", err);
    return new HttpsError(
        "resource-exhausted",
        "Kuota layanan AI sedang habis. Silakan hubungi pengelola aplikasi.",
    );
  }
  if (status === 404 && /model/i.test(message)) {
    logger.error("Gemini model unavailable — the configured model id may be deprecated", err);
    return new HttpsError(
        "failed-precondition",
        "Model AI tidak tersedia. Silakan hubungi pengelola aplikasi.",
    );
  }
  if (status === 503 || status === 500) {
    return new HttpsError(
        "unavailable",
        "Layanan AI sedang sibuk. Silakan coba lagi sebentar lagi.",
    );
  }

  logger.error("Unexpected classification failure", err);
  return new HttpsError("internal", "Gagal memproses gambar. Silakan coba lagi.");
}

/**
 * One Gemini inference pass, optionally grounded with few-shot examples.
 * @param {object} args
 * @return {Promise<{label: string, confidenceScore: number, reasoning: (string|null)}>}
 */
async function runGemini({ ai, image, examples }) {
  const parts = [{ text: buildInstructionText(examples.length > 0) }];

  examples.forEach((ex, i) => {
    parts.push({ text: `Contoh tervalidasi ${i + 1} — kategori benar: "${ex.label}"` });
    parts.push({ inlineData: { mimeType: ex.mimeType, data: ex.base64 } });
  });

  parts.push({
    text: examples.length > 0 ?
      "Sekarang klasifikasikan gambar BARU berikut (bukan salah satu contoh di atas):" :
      "Klasifikasikan gambar berikut:",
  });
  parts.push({ inlineData: { mimeType: image.mimeType, data: image.base64 } });

  const response = await ai.models.generateContent({
    model: "gemini-3.6-flash",
    contents: [{ role: "user", parts }],
    config: {
      responseMimeType: "application/json",
      responseSchema: RESPONSE_SCHEMA,
      temperature: 0.2,
    },
  });

  const raw = response && response.text;
  if (!raw) {
    logger.error("Gemini returned an empty response", JSON.stringify(response || {}));
    throw new HttpsError(
        "invalid-argument",
        "Gambar tidak dapat dianalisis. Coba ambil foto yang lebih jelas.",
    );
  }

  let parsed;
  try {
    parsed = JSON.parse(raw);
  } catch (err) {
    logger.error("Gemini returned non-JSON output", raw);
    throw new HttpsError("internal", "Model tidak mengembalikan hasil yang valid.");
  }

  if (!CATEGORIES.includes(parsed.label)) {
    logger.error("Gemini returned an unexpected label", parsed);
    throw new HttpsError("internal", "Model mengembalikan kategori yang tidak dikenal.");
  }

  return {
    label: parsed.label,
    confidenceScore: clamp(Number(parsed.confidence_score) || 0, 0, 1),
    reasoning: typeof parsed.reasoning === "string" ? parsed.reasoning.trim() : null,
  };
}

/** Shapes a stored classification doc into the callable's response. */
function toResponse(logId, data) {
  return {
    logId,
    label: data.predictedLabel,
    category: data.category,
    confidenceScore: data.confidenceScore,
    reasoning: data.reasoning,
    usedFewShot: data.usedFewShot,
    fewShotExampleCount: data.fewShotExampleCount || 0,
    mode: data.classificationMode,
    escalated: data.escalated || false,
    zeroShotConfidence: data.zeroShotConfidence,
    totalScans: data.totalScansAfter || null,
  };
}

exports.classifyWaste = onCall(
    {
      region: REGION,
      secrets: [geminiApiKey],
      timeoutSeconds: 120,
      memory: "512MiB",
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Anda harus login untuk melakukan scan.");
      }
      const uid = request.auth.uid;

      const { storagePath, imageUrl, clientRequestId } = request.data || {};

      if (typeof storagePath !== "string" || !storagePath) {
        throw new HttpsError("invalid-argument", "storagePath wajib diisi.");
      }
      // The function reads this path with admin privileges, so it must belong
      // to the caller — otherwise any user could classify another user's image.
      if (!storagePath.startsWith(`scans/${uid}/`) || storagePath.includes("..")) {
        throw new HttpsError("permission-denied", "Anda tidak berhak mengakses gambar ini.");
      }
      if (typeof clientRequestId !== "string" || !/^[A-Za-z0-9_-]{6,128}$/.test(clientRequestId)) {
        throw new HttpsError("invalid-argument", "clientRequestId tidak valid.");
      }

      const logRef = db.collection("users").doc(uid).collection("classifications").doc(clientRequestId);
      const statsRef = db.collection("users").doc(uid);

      // Idempotency fast path: a retry of an already-processed scan returns the
      // stored result without paying for another inference or double-counting.
      const existing = await logRef.get();
      if (existing.exists) {
        logger.info(`Returning cached result for ${clientRequestId}`);
        return toResponse(existing.id, existing.data());
      }

      const config = await loadConfig();
      const image = await downloadImage(storagePath).catch((err) => {
        if (err instanceof HttpsError) throw err;
        logger.error("Failed to download scan image", err);
        throw new HttpsError("not-found", "Gambar tidak ditemukan di penyimpanan.");
      });

      let result;
      try {
        const ai = new GoogleGenAI({ apiKey: geminiApiKey.value() });
        result = await classify({
          mode: config.mode,
          threshold: config.threshold,
          fewShotCount: config.fewShotCount,
          runInference: (examples) => runGemini({ ai, image, examples }),
          fetchExamples: (count) => fetchExamples(count),
        });
      } catch (err) {
        throw toHttpsError(err);
      }

      const category = CATEGORY_TO_ID[result.label];
      const docData = {
        predictedLabel: result.label,
        category,
        confidenceScore: result.confidenceScore,
        reasoning: result.reasoning,
        classificationMode: config.mode,
        confidenceThreshold: config.threshold,
        usedFewShot: result.usedFewShot,
        fewShotExampleCount: result.fewShotExampleCount,
        escalated: result.escalated,
        zeroShotLabel: result.zeroShotLabel,
        zeroShotConfidence: result.zeroShotConfidence,
        imageUrl: typeof imageUrl === "string" ? imageUrl : null,
        storagePath,
        corrected: false,
        correctedLabel: null,
        correctedCategory: null,
        timestamp: FieldValue.serverTimestamp(),
      };

      // Write the log and bump the user's aggregates in one atomic step, so a
      // concurrent double-tap can never count the same scan twice.
      const wasWritten = await db.runTransaction(async (tx) => {
        const raced = await tx.get(logRef);
        if (raced.exists) return false;

        tx.set(logRef, docData);
        tx.set(
            statsRef,
            {
              totalScans: FieldValue.increment(1),
              categoryCounts: { [category]: FieldValue.increment(1) },
              lastScanAt: FieldValue.serverTimestamp(),
              displayName: request.auth.token.name || null,
              email: request.auth.token.email || null,
              photoURL: request.auth.token.picture || null,
            },
            { merge: true },
        );
        return true;
      });

      if (!wasWritten) {
        const winner = await logRef.get();
        return toResponse(winner.id, winner.data());
      }

      const stats = await statsRef.get();
      return toResponse(logRef.id, {
        ...docData,
        totalScansAfter: stats.exists ? stats.data().totalScans : null,
      });
    },
);

/**
 * Records a user's "Laporan Hasil Tidak Tepat" correction.
 *
 * Runs server-side so that clients never write to the few-shot pool or to
 * their own aggregate counters directly. Re-correcting the same scan updates
 * the same few-shot entry instead of polluting the pool with duplicates.
 */
exports.submitCorrection = onCall(
    { region: REGION, timeoutSeconds: 60, memory: "256MiB" },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Anda harus login untuk mengirim koreksi.");
      }
      const uid = request.auth.uid;

      const { logId, correctCategory } = request.data || {};
      if (typeof logId !== "string" || !logId) {
        throw new HttpsError("invalid-argument", "logId wajib diisi.");
      }
      if (!CATEGORY_IDS.includes(correctCategory)) {
        throw new HttpsError("invalid-argument", "Kategori koreksi tidak valid.");
      }

      const correctLabel = CATEGORIES[CATEGORY_IDS.indexOf(correctCategory)];
      const logRef = db.collection("users").doc(uid).collection("classifications").doc(logId);
      const statsRef = db.collection("users").doc(uid);
      // Deterministic id: correcting the same scan twice overwrites one entry
      // rather than appending a duplicate example to the few-shot pool.
      const fewShotRef = db.collection("few_shot_data").doc(`${uid}_${logId}`);

      await db.runTransaction(async (tx) => {
        const logSnap = await tx.get(logRef);
        if (!logSnap.exists) {
          throw new HttpsError("not-found", "Data scan tidak ditemukan.");
        }
        const log = logSnap.data();

        // Whatever the stats currently attribute this scan to.
        const previousCategory = log.corrected ? log.correctedCategory : log.category;

        tx.set(
            fewShotRef,
            {
              imageUrl: log.imageUrl || null,
              storagePath: log.storagePath,
              label: correctLabel,
              category: correctCategory,
              validated: true,
              sourceUid: uid,
              sourceLogId: logId,
              originalPrediction: log.predictedLabel,
              originalConfidence: log.confidenceScore,
              createdAt: FieldValue.serverTimestamp(),
            },
            { merge: true },
        );

        tx.update(logRef, {
          corrected: true,
          correctedLabel: correctLabel,
          correctedCategory: correctCategory,
          correctedAt: FieldValue.serverTimestamp(),
        });

        // Keep per-category aggregates truthful without touching totalScans —
        // a correction re-labels a scan, it does not add one.
        if (previousCategory && previousCategory !== correctCategory) {
          tx.set(
              statsRef,
              {
                categoryCounts: {
                  [previousCategory]: FieldValue.increment(-1),
                  [correctCategory]: FieldValue.increment(1),
                },
              },
              { merge: true },
          );
        }
      });

      return { success: true, correctedLabel: correctLabel, correctedCategory: correctCategory };
    },
);
