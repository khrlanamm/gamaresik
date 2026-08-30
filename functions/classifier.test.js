/**
 * Tests for the zero-shot / few-shot / selective decision logic.
 *
 * Inference and example lookup are injected, so these run offline with no
 * Gemini quota — the selective escalation rule is the thesis's core claim and
 * must be verifiable independently of the model being reachable.
 *
 * Run with: node --test functions/
 */
const test = require("node:test");
const assert = require("node:assert");

const {
  normalizeConfig,
  classify,
  CATEGORIES,
  CATEGORY_TO_ID,
  CATEGORY_IDS,
  DEFAULT_THRESHOLD,
  DEFAULT_FEW_SHOT_COUNT,
  MAX_FEW_SHOT_COUNT,
} = require("./classifier");

/** Builds an inference stub that returns the queued results in order. */
function stubInference(...results) {
  const calls = [];
  const fn = async (examples) => {
    calls.push(examples);
    const next = results[calls.length - 1];
    if (!next) throw new Error(`unexpected inference call #${calls.length}`);
    return next;
  };
  fn.calls = calls;
  return fn;
}

function stubExamples(count) {
  const fn = async (requested) => {
    fn.requested = requested;
    return Array.from({ length: Math.min(count, requested) }, (_, i) => ({
      label: CATEGORIES[i % CATEGORIES.length],
      base64: "x",
      mimeType: "image/jpeg",
    }));
  };
  fn.requested = null;
  return fn;
}

const HIGH = { label: "Organik Terpilah", confidenceScore: 0.9, reasoning: "jelas" };
const LOW = { label: "Organik Terpilah", confidenceScore: 0.3, reasoning: "ragu" };
const FEWSHOT = { label: "Residu Terpilah", confidenceScore: 0.8, reasoning: "kotor" };

test("category vocabulary matches the Flutter WasteCategory contract", () => {
  assert.deepStrictEqual(CATEGORIES, [
    "Organik Terpilah",
    "Recycle Bersih Terpilah",
    "Residu Terpilah",
  ]);
  assert.deepStrictEqual(CATEGORY_IDS, ["organic", "recyclable", "residual"]);
  assert.strictEqual(CATEGORY_TO_ID["Organik Terpilah"], "organic");
});

test("normalizeConfig accepts a valid document unchanged", () => {
  const config = normalizeConfig({
    classification_mode: "few-shot",
    confidence_threshold: 0.75,
    few_shot_count: 5,
  });
  assert.deepStrictEqual(config, { mode: "few-shot", threshold: 0.75, fewShotCount: 5 });
});

test("normalizeConfig falls back and warns on an unknown mode", () => {
  const warnings = [];
  const config = normalizeConfig({ classification_mode: "magic" }, (m) => warnings.push(m));
  assert.strictEqual(config.mode, "selective");
  assert.strictEqual(config.threshold, DEFAULT_THRESHOLD);
  assert.strictEqual(config.fewShotCount, DEFAULT_FEW_SHOT_COUNT);
  // The fallback must be loud, never silent.
  assert.ok(warnings.some((w) => w.includes("magic")));
});

test("normalizeConfig clamps an out-of-range threshold and caps few_shot_count", () => {
  assert.strictEqual(normalizeConfig({ confidence_threshold: 4 }).threshold, 1);
  assert.strictEqual(normalizeConfig({ confidence_threshold: -2 }).threshold, 0);
  assert.strictEqual(
      normalizeConfig({ few_shot_count: 999 }).fewShotCount,
      MAX_FEW_SHOT_COUNT,
  );
  assert.strictEqual(normalizeConfig({ few_shot_count: 2.5 }).fewShotCount,
      DEFAULT_FEW_SHOT_COUNT);
  assert.strictEqual(normalizeConfig({}).mode, "selective");
  assert.strictEqual(normalizeConfig(undefined).mode, "selective");
});

test("zero-shot mode never fetches examples, even at low confidence", async () => {
  const runInference = stubInference(LOW);
  const fetchExamples = stubExamples(5);

  const result = await classify({
    runInference, fetchExamples, mode: "zero-shot", threshold: 0.5, fewShotCount: 3,
  });

  assert.strictEqual(runInference.calls.length, 1);
  assert.deepStrictEqual(runInference.calls[0], []);
  assert.strictEqual(fetchExamples.requested, null, "must not query the few-shot pool");
  assert.strictEqual(result.usedFewShot, false);
  assert.strictEqual(result.escalated, false);
  assert.strictEqual(result.confidenceScore, 0.3);
});

test("few-shot mode always grounds the prompt, skipping the zero-shot pass", async () => {
  const runInference = stubInference(FEWSHOT);
  const fetchExamples = stubExamples(3);

  const result = await classify({
    runInference, fetchExamples, mode: "few-shot", threshold: 0.5, fewShotCount: 3,
  });

  assert.strictEqual(runInference.calls.length, 1, "exactly one inference pass");
  assert.strictEqual(runInference.calls[0].length, 3, "prompt carried examples");
  assert.strictEqual(fetchExamples.requested, 3);
  assert.strictEqual(result.usedFewShot, true);
  assert.strictEqual(result.fewShotExampleCount, 3);
  assert.strictEqual(result.label, "Residu Terpilah");
});

test("few-shot mode reports usedFewShot=false when the pool is empty", async () => {
  const runInference = stubInference(FEWSHOT);
  const result = await classify({
    runInference, fetchExamples: stubExamples(0), mode: "few-shot",
    threshold: 0.5, fewShotCount: 3,
  });
  assert.strictEqual(result.usedFewShot, false);
  assert.strictEqual(result.fewShotExampleCount, 0);
});

test("selective keeps the zero-shot answer when confidence meets the threshold", async () => {
  const runInference = stubInference(HIGH);
  const fetchExamples = stubExamples(5);

  const result = await classify({
    runInference, fetchExamples, mode: "selective", threshold: 0.5, fewShotCount: 3,
  });

  assert.strictEqual(runInference.calls.length, 1, "no re-inference");
  assert.strictEqual(fetchExamples.requested, null, "no pool query when confident");
  assert.strictEqual(result.escalated, false);
  assert.strictEqual(result.usedFewShot, false);
  assert.strictEqual(result.confidenceScore, 0.9);
});

test("selective treats confidence exactly at the threshold as sufficient", async () => {
  const runInference = stubInference({ ...HIGH, confidenceScore: 0.5 });
  const fetchExamples = stubExamples(5);

  const result = await classify({
    runInference, fetchExamples, mode: "selective", threshold: 0.5, fewShotCount: 3,
  });

  assert.strictEqual(result.escalated, false);
  assert.strictEqual(runInference.calls.length, 1);
  assert.strictEqual(fetchExamples.requested, null);
});

test("selective escalates to few-shot re-inference below the threshold", async () => {
  const runInference = stubInference(LOW, FEWSHOT);
  const fetchExamples = stubExamples(3);

  const result = await classify({
    runInference, fetchExamples, mode: "selective", threshold: 0.5, fewShotCount: 3,
  });

  assert.strictEqual(runInference.calls.length, 2, "zero-shot then few-shot");
  assert.deepStrictEqual(runInference.calls[0], [], "first pass is ungrounded");
  assert.strictEqual(runInference.calls[1].length, 3, "second pass carries examples");

  // The FINAL result must win — reporting the stale zero-shot value here was
  // the specific failure mode the spec calls out.
  assert.strictEqual(result.label, FEWSHOT.label);
  assert.strictEqual(result.confidenceScore, FEWSHOT.confidenceScore);
  assert.strictEqual(result.usedFewShot, true);
  assert.strictEqual(result.escalated, true);
  assert.strictEqual(result.fewShotExampleCount, 3);

  // ...while still preserving the pre-escalation trace for analysis.
  assert.strictEqual(result.zeroShotLabel, LOW.label);
  assert.strictEqual(result.zeroShotConfidence, 0.3);
});

test("selective falls back to the zero-shot answer when no examples exist", async () => {
  const runInference = stubInference(LOW);
  const fetchExamples = stubExamples(0);

  const result = await classify({
    runInference, fetchExamples, mode: "selective", threshold: 0.5, fewShotCount: 3,
  });

  assert.strictEqual(runInference.calls.length, 1, "no pointless second pass");
  assert.strictEqual(result.usedFewShot, false);
  assert.strictEqual(result.fewShotExampleCount, 0);
  // escalated=true records that the threshold *was* breached, even though the
  // pool could not satisfy it.
  assert.strictEqual(result.escalated, true);
  assert.strictEqual(result.confidenceScore, LOW.confidenceScore);
});

test("selective honours the configured few_shot_count when escalating", async () => {
  const runInference = stubInference(LOW, FEWSHOT);
  const fetchExamples = stubExamples(10);

  await classify({
    runInference, fetchExamples, mode: "selective", threshold: 0.9, fewShotCount: 7,
  });

  assert.strictEqual(fetchExamples.requested, 7);
  assert.strictEqual(runInference.calls[1].length, 7);
});

test("a threshold of 0 disables escalation entirely", async () => {
  const runInference = stubInference({ ...LOW, confidenceScore: 0 });
  const fetchExamples = stubExamples(3);

  const result = await classify({
    runInference, fetchExamples, mode: "selective", threshold: 0, fewShotCount: 3,
  });

  assert.strictEqual(result.escalated, false);
  assert.strictEqual(runInference.calls.length, 1);
});
