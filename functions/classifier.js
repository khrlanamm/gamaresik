/**
 * Pure classification logic for Gamaresik.
 *
 * Deliberately free of Firebase and Gemini imports: inference and example
 * lookup are injected, so the zero-shot / few-shot / selective decision
 * making can be tested deterministically without network access or quota.
 */

/**
 * Labels Gemini is prompted to return, mapped to stored category ids.
 *
 * The label strings are fixed by Tabel 4.1 of the thesis (Blok A), which is the
 * approved design document — keep them byte-identical to it, and to
 * `classificationLabel` in lib/models/waste_category.dart.
 */
const CATEGORY_TO_ID = {
  "organik": "organic",
  "recycle": "recyclable",
  "residu": "residual",
};
const CATEGORIES = Object.keys(CATEGORY_TO_ID);
const CATEGORY_IDS = Object.values(CATEGORY_TO_ID);

const VALID_MODES = ["zero-shot", "few-shot", "selective"];
const DEFAULT_MODE = "selective";
const DEFAULT_THRESHOLD = 0.5;
const DEFAULT_FEW_SHOT_COUNT = 3;
const MAX_FEW_SHOT_COUNT = 10;

function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value));
}

/**
 * Normalizes the app_config/settings document.
 *
 * Invalid values fall back to documented defaults and every fallback is
 * reported through `warn`, so a misconfigured mode is never bypassed silently.
 * @param {object} data Raw config document data.
 * @param {function(string):void} warn Warning sink.
 * @return {{mode: string, threshold: number, fewShotCount: number}}
 */
function normalizeConfig(data, warn = () => {}) {
  const config = data || {};

  let mode = config.classification_mode;
  if (!VALID_MODES.includes(mode)) {
    warn(`classification_mode "${mode}" is not one of ${VALID_MODES.join("|")}; ` +
        `falling back to "${DEFAULT_MODE}".`);
    mode = DEFAULT_MODE;
  }

  let threshold = config.confidence_threshold;
  if (typeof threshold !== "number" || Number.isNaN(threshold)) {
    warn(`confidence_threshold is not a number; using ${DEFAULT_THRESHOLD}.`);
    threshold = DEFAULT_THRESHOLD;
  }
  threshold = clamp(threshold, 0, 1);

  let fewShotCount = config.few_shot_count;
  if (typeof fewShotCount !== "number" ||
      !Number.isInteger(fewShotCount) ||
      fewShotCount < 0) {
    warn(`few_shot_count is invalid; using ${DEFAULT_FEW_SHOT_COUNT}.`);
    fewShotCount = DEFAULT_FEW_SHOT_COUNT;
  }
  if (fewShotCount > MAX_FEW_SHOT_COUNT) {
    warn(`few_shot_count ${fewShotCount} exceeds cap; clamping to ${MAX_FEW_SHOT_COUNT}.`);
    fewShotCount = MAX_FEW_SHOT_COUNT;
  }

  return { mode, threshold, fewShotCount };
}

/**
 * Runs the configured classification strategy.
 *
 * Selective mode is the core thesis mechanism: zero-shot always runs first,
 * and a few-shot re-inference happens only when that first confidence lands
 * below the configured threshold.
 *
 * Every inference pass is recorded in `passes` with its own latency and token
 * usage, and the totals are summed across passes. Section 4.6 of the thesis
 * compares the cost of an escalated scan against a plain one, which is only
 * answerable if each pass is measured separately rather than in aggregate.
 *
 * @param {object} args
 * @param {function(Array, string):Promise<object>} args.runInference Called with
 *   the few-shot examples to ground the prompt with (empty array = zero-shot)
 *   and a label for the pass. Must resolve to `{label, confidenceScore,
 *   reasoning, latencyMs, usage}`.
 * @param {function(number):Promise<Array>} args.fetchExamples Loads validated
 *   examples; may return fewer than requested.
 * @param {string} args.mode
 * @param {number} args.threshold
 * @param {number} args.fewShotCount
 * @return {Promise<object>} final result plus a trace of what actually ran.
 */
async function classify({ runInference, fetchExamples, mode, threshold, fewShotCount }) {
  const passes = [];

  /**
   * Runs one pass and records it in the trace.
   * @param {Array} examples Few-shot examples (empty = zero-shot prompt).
   * @param {string} kind Pass label kept in the trace.
   * @return {Promise<object>} The pass result.
   */
  async function pass(examples, kind) {
    const result = await runInference(examples, kind);
    passes.push({
      kind,
      label: result.label,
      confidenceScore: result.confidenceScore,
      exampleCount: examples.length,
      latencyMs: result.latencyMs ?? null,
      ...totalsOf(result.usage),
    });
    return result;
  }

  /**
   * Builds the aggregate returned to the caller.
   * @param {object} result Winning pass result.
   * @param {object} extra Trace fields.
   * @return {object}
   */
  function finish(result, extra) {
    return {
      ...result,
      ...extra,
      passes,
      inferenceCount: passes.length,
      usageTotals: sumUsage(passes),
      inferenceLatencyMs: passes.reduce((sum, p) => sum + (p.latencyMs || 0), 0),
    };
  }

  if (mode === "few-shot") {
    const examples = await fetchExamples(fewShotCount);
    const result = await pass(examples, "few-shot");
    return finish(result, {
      usedFewShot: examples.length > 0,
      fewShotExampleCount: examples.length,
      zeroShotLabel: null,
      zeroShotConfidence: null,
      escalated: false,
    });
  }

  const zeroShot = await pass([], "zero-shot");
  const base = {
    zeroShotLabel: zeroShot.label,
    zeroShotConfidence: zeroShot.confidenceScore,
  };

  if (mode === "zero-shot" || zeroShot.confidenceScore >= threshold) {
    return finish(zeroShot, {
      ...base,
      usedFewShot: false,
      fewShotExampleCount: 0,
      escalated: false,
    });
  }

  // --- selective escalation ---
  const examples = await fetchExamples(fewShotCount);
  if (examples.length === 0) {
    // Nothing validated to escalate with yet: keep the zero-shot answer rather
    // than pretending a few-shot pass happened.
    return finish(zeroShot, {
      ...base,
      usedFewShot: false,
      fewShotExampleCount: 0,
      escalated: true,
    });
  }

  const reRun = await pass(examples, "few-shot");
  return finish(reRun, {
    ...base,
    usedFewShot: true,
    fewShotExampleCount: examples.length,
    escalated: true,
  });
}

/**
 * Flattens one response's usage into the token fields stored per pass.
 *
 * `thoughtsTokenCount` is billed as output on Gemini 3.x and routinely dwarfs
 * the visible answer, so it is kept as its own column rather than folded into
 * a single total — equation 3.11 of the thesis cannot be evaluated otherwise.
 * @param {object} usage Raw `usageMetadata` from the model, if any.
 * @return {{promptTokens: number, thoughtsTokens: number, outputTokens: number, totalTokens: number}}
 */
function totalsOf(usage) {
  const u = usage || {};
  return {
    promptTokens: Number(u.promptTokenCount) || 0,
    thoughtsTokens: Number(u.thoughtsTokenCount) || 0,
    outputTokens: Number(u.candidatesTokenCount) || 0,
    totalTokens: Number(u.totalTokenCount) || 0,
  };
}

/**
 * Sums the per-pass token counts across every inference a scan required.
 * @param {Array<object>} passes Recorded passes.
 * @return {{promptTokens: number, thoughtsTokens: number, outputTokens: number, totalTokens: number}}
 */
function sumUsage(passes) {
  return passes.reduce(
      (acc, p) => ({
        promptTokens: acc.promptTokens + (p.promptTokens || 0),
        thoughtsTokens: acc.thoughtsTokens + (p.thoughtsTokens || 0),
        outputTokens: acc.outputTokens + (p.outputTokens || 0),
        totalTokens: acc.totalTokens + (p.totalTokens || 0),
      }),
      { promptTokens: 0, thoughtsTokens: 0, outputTokens: 0, totalTokens: 0 },
  );
}

module.exports = {
  CATEGORIES,
  CATEGORY_TO_ID,
  CATEGORY_IDS,
  VALID_MODES,
  DEFAULT_THRESHOLD,
  DEFAULT_FEW_SHOT_COUNT,
  MAX_FEW_SHOT_COUNT,
  clamp,
  normalizeConfig,
  classify,
  totalsOf,
  sumUsage,
};
