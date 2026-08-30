/**
 * Pure classification logic for Gamaresik.
 *
 * Deliberately free of Firebase and Gemini imports: inference and example
 * lookup are injected, so the zero-shot / few-shot / selective decision
 * making can be tested deterministically without network access or quota.
 */

/** Labels Gemini is prompted to return, mapped to stored category ids. */
const CATEGORY_TO_ID = {
  "Organik Terpilah": "organic",
  "Recycle Bersih Terpilah": "recyclable",
  "Residu Terpilah": "residual",
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
 * @param {object} args
 * @param {function(Array):Promise<object>} args.runInference Called with the
 *   few-shot examples to ground the prompt with (empty array = zero-shot).
 * @param {function(number):Promise<Array>} args.fetchExamples Loads validated
 *   examples; may return fewer than requested.
 * @param {string} args.mode
 * @param {number} args.threshold
 * @param {number} args.fewShotCount
 * @return {Promise<object>} final result plus a trace of what actually ran.
 */
async function classify({ runInference, fetchExamples, mode, threshold, fewShotCount }) {
  if (mode === "few-shot") {
    const examples = await fetchExamples(fewShotCount);
    const result = await runInference(examples);
    return {
      ...result,
      usedFewShot: examples.length > 0,
      fewShotExampleCount: examples.length,
      zeroShotLabel: null,
      zeroShotConfidence: null,
      escalated: false,
    };
  }

  const zeroShot = await runInference([]);
  const base = {
    zeroShotLabel: zeroShot.label,
    zeroShotConfidence: zeroShot.confidenceScore,
  };

  if (mode === "zero-shot" || zeroShot.confidenceScore >= threshold) {
    return {
      ...zeroShot,
      ...base,
      usedFewShot: false,
      fewShotExampleCount: 0,
      escalated: false,
    };
  }

  // --- selective escalation ---
  const examples = await fetchExamples(fewShotCount);
  if (examples.length === 0) {
    // Nothing validated to escalate with yet: keep the zero-shot answer rather
    // than pretending a few-shot pass happened.
    return {
      ...zeroShot,
      ...base,
      usedFewShot: false,
      fewShotExampleCount: 0,
      escalated: true,
    };
  }

  const reRun = await runInference(examples);
  return {
    ...reRun,
    ...base,
    usedFewShot: true,
    fewShotExampleCount: examples.length,
    escalated: true,
  };
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
};
