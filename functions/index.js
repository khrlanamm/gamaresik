const { onCall, HttpsError } = require("firebase-functions/v2/https");
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

const REGION = "asia-southeast2";

/** GCP project that owns both this function and the Vertex AI quota. */
const PROJECT_ID = process.env.GCLOUD_PROJECT || "gamaresik";

/**
 * Vertex location serving the model.
 *
 * Gemini 3.x publisher models are only exposed through the `global` endpoint —
 * regional endpoints (asia-southeast2 included) return NOT_FOUND for them, so
 * this is not a tunable. Verified against this project on 30 Aug 2026.
 */
const VERTEX_LOCATION = "global";

/**
 * Pinned model id.
 *
 * `gemini-2.5-flash` — the id the thesis was originally written around — was
 * withdrawn from the Gemini Developer API for new users in July 2026 and is
 * scheduled for full shutdown on 16 Oct 2026, so it is not a safe basis for
 * results that must stay reproducible after submission.
 */
const MODEL_ID = "gemini-3.6-flash";

/**
 * Thinking effort, pinned rather than left to the model default.
 *
 * Thinking tokens are billed as output and dominate both latency and cost:
 * a trivial prompt measured 429 thinking tokens on the default setting versus
 * 245 on "low". Leaving this implicit would let a silent change to Google's
 * default land between Tahap 1 and Tahap 2 and destroy their comparability.
 */
const THINKING_LEVEL = "low";

/** Safety rail so an oversized upload cannot blow up the function. */
const MAX_IMAGE_BYTES = 10 * 1024 * 1024;

/** Dataset tags accepted from the batch-evaluation harness. */
const VALID_DATASET_IDS = ["A", "B"];

/** Few-shot pool. Named as in section 4.4.3 of the thesis. */
const FEW_SHOT_COLLECTION = "data_fewshot";

const RESPONSE_SCHEMA = {
  type: Type.OBJECT,
  properties: {
    // Penalaran diminta lebih dulu supaya model menimbang sebelum menilai;
    // urutan medan pada luaran terstruktur menentukan urutan pembangkitan.
    reasoning: { type: Type.STRING },
    // Skor dibagi ke KETIGA kategori, bukan satu angka untuk jawaban terpilih.
    // Pada skor tunggal model hampir selalu menjawab 0,95 atau 0,98 — dua nilai
    // pada 81 citra — sehingga ambang batas kehilangan resolusi. Membagi 100
    // poin memaksa model menimbang alternatif dan memunculkan sebaran.
    skor: {
      type: Type.OBJECT,
      properties: {
        organik: { type: Type.INTEGER },
        recycle: { type: Type.INTEGER },
        residu: { type: Type.INTEGER },
      },
      required: ["organik", "recycle", "residu"],
      propertyOrdering: ["organik", "recycle", "residu"],
    },
    label: { type: Type.STRING, enum: CATEGORIES },
  },
  required: ["skor", "label"],
  propertyOrdering: ["reasoning", "skor", "label"],
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

/**
 * Blok A of the prompt — the system instruction.
 *
 * Transcribed from Tabel 4.1 of the thesis, which is the approved design; the
 * category scopes and the four reasoning steps are reproduced verbatim so the
 * running system and the document that describes it cannot drift apart. Note
 * that tissue belongs to "organik" here, exactly as the Rector's circular
 * quoted in Bab I has it.
 *
 * @return {string} Blok A.
 */
function buildInstructionText() {
  return `Bertindaklah sebagai ahli klasifikasi sampah dan teknik lingkungan. Tugas Anda adalah menganalisis gambar input secara visual dan mengkategorikannya ke dalam salah satu dari tiga label kategori berikut: "organik", "recycle", atau "residu".

Definisi Kategori & Label:

1. Label: "organik" (Sampah Organik Terpilah)
Definisi: Sampah yang mudah terurai secara alami.
Cakupan: Sisa makanan, potongan ranting/daun, kulit buah, tisu, dan kemasan berbahan pulp kertas tanpa lapisan plastik seperti tatakan telur.
Catatan: Tisu tetap masuk kategori ini meskipun sudah terpakai atau terkena minyak dan sisa makanan, sebab bahannya tetap mudah terurai.
Pengecualian: Tidak termasuk bungkus makanan dari kertas berlapis plastik.

2. Label: "recycle" (Sampah Recycle Bersih Terpilah)
Definisi: Sampah anorganik yang memiliki nilai ekonomi tinggi, materialnya masih utuh, dan layak didaur ulang.
Cakupan: Botol plastik, kertas HVS/koran bersih, kaleng logam, botol kaca, kardus termasuk kotak lipat kecil, dan kemasan plastik keras.
Catatan: Debu atau tanah yang menempel di permukaan tidak menggugurkan kategori ini, sepanjang wadahnya sudah kosong dan kering.

3. Label: "residu" (Sampah Residu Terpilah)
Definisi: Sampah anorganik yang tidak memiliki nilai ekonomi, sulit didaur ulang, atau tercemar minyak dan lemak.
Cakupan: Kemasan sachet (multilayer), kemasan karton minuman berlapis, plastik lembaran atau kemasan lentur, peralatan makan sekali pakai seperti sendok, garpu, dan sedotan plastik, masker medis, kapas/kasa bekas, pembalut/diapers, kantong plastik kotor, styrofoam, puntung rokok, dan bungkus makanan berminyak.

Logika Penalaran:

Nilai kondisi objek sebagaimana terlihat pada gambar, bukan kondisi setelah dicuci atau dibersihkan. Wadah yang masih berisi atau berlumur sisa makanan dan minuman termasuk residu, meskipun materialnya sendiri sebenarnya dapat didaur ulang.

1. Analisis material objek. Apakah bersifat organik/hayati/mudah busuk? Jika YA maka labelnya "organik".
2. Jika TIDAK, periksa material dan nilai jualnya. Apakah berupa botol, kaleng, kaca, kertas/kardus, atau kemasan plastik KERAS yang sudah kosong dan kering? Plastik lembaran dan peralatan makan sekali pakai tidak termasuk. Jika YA maka labelnya "recycle".
3. Jika terkena minyak atau lemak yang meresap ke materialnya, berupa sachet, atau campuran material sulit pisah? Jika YA maka "residu".
4. Pastikan jawaban label diambil dari 3 kategori itu, jangan menyebut hal/kategori di luar ini. Cari yang mendekati di antara 3 kategori ini jika menurutmu sebenarnya tidak ada yang masuk.

Penjelasan Skor Keyakinan:

Berikan skor untuk KETIGA kategori sekaligus, berupa bilangan bulat yang jumlahnya tepat 100. Skor menyatakan seberapa besar kemungkinan sampah pada gambar termasuk kategori tersebut.
- Bila sebuah kategori benar-benar tidak mungkin, beri 0.
- Bila dua kategori sama-sama masuk akal dan gambar tidak cukup untuk memastikan, bagilah mendekati seimbang, misalnya 55 dan 45.
- Bila satu kategori jelas namun menyisakan sedikit keraguan, misalnya kondisi kebersihan yang tidak terlihat pasti, sisakan poin untuk kategori pesaingnya.
- Jangan memberi 100 pada satu kategori kecuali kedua kategori lain benar-benar mustahil.

Kemudian isi "label" dengan kategori yang skornya tertinggi.

Sertakan juga "reasoning": satu kalimat singkat dalam Bahasa Indonesia yang menjelaskan dasar keputusan Anda.`;
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
 * Fetches human-validated few-shot examples for Blok B.
 *
 * Section 4.4.3 asks for examples drawn *at random, one per category*, because
 * the point of the escalation is to make the model reason comparatively across
 * the three classes. Taking the most recent N instead — the obvious
 * implementation — can hand the model three residu examples and turn Blok B
 * into a bias rather than a comparison.
 *
 * Categories with no validated example yet are simply skipped, so the pool
 * degrades gracefully while it is still filling up.
 *
 * @param {number} count Max number of examples; distributed across categories.
 * @return {Promise<Array<{base64: string, mimeType: string, label: string}>>}
 */
async function fetchExamples(count) {
  if (count <= 0) return [];

  // Round-robin the budget over the categories: 3 examples over 3 categories is
  // one each, and an unusual few_shot_count of 5 becomes 2/2/1.
  const perCategory = new Map(CATEGORIES.map((label, i) => [
    label,
    Math.floor(count / CATEGORIES.length) + (i < count % CATEGORIES.length ? 1 : 0),
  ]));

  const picked = [];
  for (const label of CATEGORIES) {
    const want = perCategory.get(label);
    if (want <= 0) continue;

    let snap;
    try {
      // Sampling by a random cursor over a stored random key: Firestore has no
      // ORDER BY RANDOM(), and reading the whole pool to shuffle in memory
      // would grow linearly with every correction users submit.
      snap = await db
          .collection(FEW_SHOT_COLLECTION)
          .where("validated", "==", true)
          .where("label", "==", label)
          .where("randomKey", ">=", Math.random())
          .orderBy("randomKey")
          .limit(want)
          .get();
      if (snap.empty) {
        snap = await db
            .collection(FEW_SHOT_COLLECTION)
            .where("validated", "==", true)
            .where("label", "==", label)
            .orderBy("randomKey")
            .limit(want)
            .get();
      }
    } catch (err) {
      logger.error(`Failed to query ${FEW_SHOT_COLLECTION} for "${label}"`, err);
      continue;
    }
    picked.push(...snap.docs);
  }

  const examples = [];
  for (const doc of picked) {
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
    // On Vertex this is a project quota ceiling or a disabled billing account,
    // not the prepaid-credit wall the AI Studio key used to hit.
    logger.error("Vertex AI quota exhausted or billing inactive", err);
    return new HttpsError(
        "resource-exhausted",
        "Kuota layanan AI sedang habis. Silakan hubungi pengelola aplikasi.",
    );
  }
  if (status === 403 || /PERMISSION_DENIED|aiplatform\.googleapis\.com/i.test(message)) {
    logger.error(
        "Vertex AI rejected the call — check that aiplatform.googleapis.com is " +
        "enabled and the runtime service account holds roles/aiplatform.user",
        err,
    );
    return new HttpsError(
        "failed-precondition",
        "Layanan AI belum dikonfigurasi dengan benar. Silakan hubungi pengelola aplikasi.",
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
  // Blok A — system instruction.
  const parts = [{ text: buildInstructionText() }];

  // Blok B — validated reference examples, present only on an escalated pass.
  if (examples.length > 0) {
    parts.push({ text: "--- MULAI CONTOH REFERENSI ---" });
    examples.forEach((ex, i) => {
      parts.push({ text: `Contoh ${i + 1}:` });
      parts.push({ inlineData: { mimeType: ex.mimeType, data: ex.base64 } });
      parts.push({ text: `-> Label: "${ex.label}"` });
    });
    parts.push({ text: "--- SELESAI CONTOH REFERENSI ---" });
  }

  // Blok C — the user's image.
  parts.push({ text: "Sekarang, berikan analisis untuk gambar berikut sesuai format:" });
  parts.push({ inlineData: { mimeType: image.mimeType, data: image.base64 } });
  parts.push({
    text: "Klasifikasikan sampah ini berdasarkan instruksi yang telah diberikan.",
  });

  const startedAt = Date.now();
  const response = await ai.models.generateContent({
    model: MODEL_ID,
    contents: [{ role: "user", parts }],
    config: {
      responseMimeType: "application/json",
      responseSchema: RESPONSE_SCHEMA,
      temperature: 0.2,
      thinkingConfig: { thinkingLevel: THINKING_LEVEL },
    },
  });
  const latencyMs = Date.now() - startedAt;

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

  const skor = parsed.skor || {};
  const total = CATEGORIES.reduce((n, k) => n + (Number(skor[k]) || 0), 0);
  if (total <= 0) {
    logger.error("Gemini returned an unusable score distribution", parsed);
    throw new HttpsError("internal", "Model tidak mengembalikan hasil yang valid.");
  }
  const sebaran = {};
  CATEGORIES.forEach((k) => {
    sebaran[k] = (Number(skor[k]) || 0) / total;
  });

  // Label diambil dari skor tertinggi. Medan "label" model dipakai hanya bila
  // sepakat dengan skornya; kalau berbeda, skor yang menang karena itulah yang
  // dipakai menghitung keyakinan.
  const urut = [...CATEGORIES].sort((a, b) => sebaran[b] - sebaran[a]);
  const label = urut[0];
  if (parsed.label && parsed.label !== label) {
    logger.warn(`Label "${parsed.label}" tidak sesuai skor tertinggi "${label}"`);
  }

  return {
    label,
    confidenceScore: clamp(sebaran[label], 0, 1),
    // Selisih dengan kategori runner-up: sinyal keraguan kedua yang tidak
    // tersedia dari skor tunggal.
    margin: clamp(sebaran[urut[0]] - sebaran[urut[1]], 0, 1),
    distribution: sebaran,
    reasoning: typeof parsed.reasoning === "string" ? parsed.reasoning.trim() : null,
    latencyMs,
    usage: response.usageMetadata || null,
  };
}

/**
 * Shapes a stored classification doc into the callable's response.
 *
 * `confidenceThreshold` is part of the contract on purpose: without it the app
 * has no way to know when a score counts as low, and the "Prediksi Tingkat
 * Keyakinan Rendah" fail-safe promised in section 4.4.3 cannot be rendered.
 * @param {string} logId Scan document id.
 * @param {object} data Stored document data.
 * @return {object} Callable response payload.
 */
function toResponse(logId, data) {
  const usage = data.usageTotals || {};
  return {
    logId,
    label: data.predictedLabel,
    category: data.category,
    confidenceScore: data.confidenceScore,
    reasoning: data.reasoning,
    usedFewShot: data.usedFewShot,
    fewShotExampleCount: data.fewShotExampleCount || 0,
    mode: data.classificationMode,
    confidenceThreshold: data.confidenceThreshold ?? null,
    escalated: data.escalated || false,
    zeroShotConfidence: data.zeroShotConfidence,
    margin: data.margin ?? null,
    distribution: data.distribution || null,
    modelId: data.modelId || null,
    latencyMs: data.latencyMs ?? null,
    totalTokens: usage.totalTokens ?? null,
    thoughtsTokens: usage.thoughtsTokens ?? null,
    totalScans: data.totalScansAfter || null,
  };
}

exports.classifyWaste = onCall(
    {
      region: REGION,
      timeoutSeconds: 120,
      memory: "512MiB",
    },
    async (request) => {
      const requestStartedAt = Date.now();

      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Anda harus login untuk melakukan scan.");
      }
      const uid = request.auth.uid;

      const { storagePath, imageUrl, clientRequestId, groundTruth, datasetId } =
        request.data || {};

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
      // Optional evaluation metadata, supplied only by the batch harness. The
      // app never sends these; a scan without them simply has no ground truth,
      // which is what makes the confusion matrix computable for dataset runs
      // and absent for ordinary user scans.
      if (groundTruth !== undefined && groundTruth !== null &&
          !CATEGORY_IDS.includes(groundTruth)) {
        throw new HttpsError("invalid-argument", "groundTruth tidak valid.");
      }
      if (datasetId !== undefined && datasetId !== null &&
          !VALID_DATASET_IDS.includes(datasetId)) {
        throw new HttpsError("invalid-argument", "datasetId tidak valid.");
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
        // Vertex AI rather than the Gemini Developer API: the function
        // authenticates with its own runtime service account, so there is no
        // API key to store, rotate, or leak, and Vertex does not use the
        // uploaded images to improve Google's products — which matters because
        // these are the study's primary research data.
        const ai = new GoogleGenAI({
          vertexai: true,
          project: PROJECT_ID,
          location: VERTEX_LOCATION,
        });
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
        // Sebaran skor tiga kategori dan selisih dengan runner-up. Margin
        // adalah sinyal keraguan yang berdiri sendiri dari besaran keyakinan:
        // skor 0,6 dengan pesaing 0,35 jauh lebih goyah daripada 0,6 dengan
        // dua pesaing 0,2.
        distribution: result.distribution || null,
        margin: result.margin ?? null,
        imageUrl: typeof imageUrl === "string" ? imageUrl : null,
        storagePath,
        corrected: false,
        correctedLabel: null,
        correctedCategory: null,

        // --- evaluation instrumentation (Bab 3.6.2 and 4.6) ---
        // Which model and thinking setting produced this row. Recorded rather
        // than assumed, so a mid-study change is visible in the data instead of
        // silently mixing two populations.
        modelId: MODEL_ID,
        thinkingLevel: THINKING_LEVEL,
        provider: "vertex-ai",
        vertexLocation: VERTEX_LOCATION,
        // Latency: the model's own time, and the whole callable including
        // download and Firestore work. The thesis reports inference time; the
        // end-to-end figure is what the user actually waits for.
        inferenceLatencyMs: result.inferenceLatencyMs ?? null,
        latencyMs: Date.now() - requestStartedAt,
        // Token usage, summed and per pass. Equation 3.11 needs input and
        // output separately, and thinking tokens bill as output.
        usageTotals: result.usageTotals || null,
        passes: result.passes || [],
        inferenceCount: result.inferenceCount || 1,
        // Ground truth is present only for batch-harness rows.
        groundTruth: groundTruth || null,
        datasetId: datasetId || null,
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
      const fewShotRef = db.collection(FEW_SHOT_COLLECTION).doc(`${uid}_${logId}`);

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
              // Sort key that lets fetchExamples draw a random example per
              // category with a bounded read instead of scanning the pool.
              randomKey: Math.random(),
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
