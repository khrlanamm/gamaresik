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

const HIGH = { label: "organik", confidenceScore: 0.9, reasoning: "jelas" };
const LOW = { label: "organik", confidenceScore: 0.3, reasoning: "ragu" };
const FEWSHOT = { label: "residu", confidenceScore: 0.8, reasoning: "kotor" };

test("category vocabulary matches the Flutter WasteCategory contract", () => {
  assert.deepStrictEqual(CATEGORIES, [
    "organik",
    "recycle",
    "residu",
  ]);
  assert.deepStrictEqual(CATEGORY_IDS, ["organic", "recyclable", "residual"]);
  assert.strictEqual(CATEGORY_TO_ID["organik"], "organic");
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
  assert.strictEqual(result.label, "residu");
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

// --- evaluation instrumentation -------------------------------------------
// Sections 3.6.2 and 4.6 report latency and token cost. Both are only
// recoverable if every inference pass is measured on its own, so these guard
// the shape the batch harness and the metrics script will read back.

/** Inference stub that also reports latency and token usage. */
function stubMetered(...results) {
  const calls = [];
  const fn = async (examples, kind) => {
    calls.push({ examples, kind });
    const next = results[calls.length - 1];
    if (!next) throw new Error(`unexpected inference call #${calls.length}`);
    return next;
  };
  fn.calls = calls;
  return fn;
}

const METERED_LOW = {
  ...LOW,
  latencyMs: 900,
  usage: {
    promptTokenCount: 1200,
    thoughtsTokenCount: 300,
    candidatesTokenCount: 40,
    totalTokenCount: 1540,
  },
};

const METERED_FEWSHOT = {
  ...FEWSHOT,
  latencyMs: 1600,
  usage: {
    promptTokenCount: 4100,
    thoughtsTokenCount: 250,
    candidatesTokenCount: 35,
    totalTokenCount: 4385,
  },
};

test("an unescalated scan records exactly one pass", async () => {
  const result = await classify({
    runInference: stubMetered({ ...METERED_LOW, confidenceScore: 0.9 }),
    fetchExamples: stubExamples(3),
    mode: "selective",
    threshold: 0.5,
    fewShotCount: 3,
  });

  assert.strictEqual(result.inferenceCount, 1);
  assert.strictEqual(result.passes.length, 1);
  assert.strictEqual(result.passes[0].kind, "zero-shot");
  assert.strictEqual(result.passes[0].exampleCount, 0);
  assert.strictEqual(result.inferenceLatencyMs, 900);
  assert.strictEqual(result.usageTotals.totalTokens, 1540);
});

test("an escalated scan sums latency and tokens across both passes", async () => {
  const result = await classify({
    runInference: stubMetered(METERED_LOW, METERED_FEWSHOT),
    fetchExamples: stubExamples(3),
    mode: "selective",
    threshold: 0.5,
    fewShotCount: 3,
  });

  assert.strictEqual(result.inferenceCount, 2, "zero-shot then few-shot");
  assert.deepStrictEqual(
      result.passes.map((p) => p.kind),
      ["zero-shot", "few-shot"],
  );
  assert.strictEqual(result.passes[1].exampleCount, 3);

  // The escalation is what section 4.6 weighs against the accuracy it buys.
  assert.strictEqual(result.inferenceLatencyMs, 2500, "900 + 1600");
  assert.strictEqual(result.usageTotals.promptTokens, 5300, "1200 + 4100");
  assert.strictEqual(result.usageTotals.thoughtsTokens, 550, "300 + 250");
  assert.strictEqual(result.usageTotals.outputTokens, 75, "40 + 35");
  assert.strictEqual(result.usageTotals.totalTokens, 5925);
});

test("thinking tokens stay separate from the visible answer", async () => {
  const result = await classify({
    runInference: stubMetered(METERED_LOW),
    fetchExamples: stubExamples(0),
    mode: "zero-shot",
    threshold: 0.5,
    fewShotCount: 3,
  });

  // Billed as output but reported apart, because equation 3.11 prices input
  // and output separately and thinking dwarfs the answer on Gemini 3.x.
  assert.strictEqual(result.usageTotals.thoughtsTokens, 300);
  assert.strictEqual(result.usageTotals.outputTokens, 40);
  assert.notStrictEqual(
      result.usageTotals.thoughtsTokens,
      result.usageTotals.outputTokens,
  );
});

test("a pass with no usage metadata degrades to zeroes, not NaN", async () => {
  const result = await classify({
    runInference: stubMetered({ ...LOW, confidenceScore: 0.9 }),
    fetchExamples: stubExamples(3),
    mode: "selective",
    threshold: 0.5,
    fewShotCount: 3,
  });

  assert.deepStrictEqual(result.usageTotals, {
    promptTokens: 0,
    thoughtsTokens: 0,
    outputTokens: 0,
    totalTokens: 0,
  });
  assert.strictEqual(result.inferenceLatencyMs, 0);
});
