import '../utils/formatters.dart';
import 'waste_category.dart';

/// The result of a `classifyWaste` Cloud Function call.
///
/// Every field mirrors what the function returns; the confidence here is the
/// *final* score (after a selective few-shot re-inference, when one happened),
/// never the intermediate zero-shot value.
class ClassificationResult {
  final String logId;
  final WasteCategory category;
  final String label;
  final double confidenceScore;
  final String? reasoning;

  /// True when the returned label came from a few-shot prompt.
  final bool usedFewShot;
  final int fewShotExampleCount;

  /// Configured mode that actually ran ('zero-shot' | 'few-shot' | 'selective').
  final String mode;

  /// Selective mode only: whether confidence fell below the threshold and an
  /// escalation was attempted.
  final bool escalated;

  /// Selective mode only: the pre-escalation score, kept for the thesis's
  /// before/after comparison.
  final double? zeroShotConfidence;

  /// Total scans after this one, when the function reported it.
  final int? totalScans;

  const ClassificationResult({
    required this.logId,
    required this.category,
    required this.label,
    required this.confidenceScore,
    required this.reasoning,
    required this.usedFewShot,
    required this.fewShotExampleCount,
    required this.mode,
    required this.escalated,
    required this.zeroShotConfidence,
    required this.totalScans,
  });

  factory ClassificationResult.fromCallableData(Object? data) {
    if (data is! Map) {
      throw const FormatException('Respons klasifikasi tidak valid.');
    }
    final map = Map<String, dynamic>.from(data);
    return ClassificationResult(
      logId: map['logId'] as String,
      category: WasteCategory.fromId(map['category'] as String?),
      label: map['label'] as String? ?? '',
      confidenceScore: (map['confidenceScore'] as num?)?.toDouble() ?? 0,
      reasoning: map['reasoning'] as String?,
      usedFewShot: map['usedFewShot'] as bool? ?? false,
      fewShotExampleCount: (map['fewShotExampleCount'] as num?)?.toInt() ?? 0,
      mode: map['mode'] as String? ?? 'selective',
      escalated: map['escalated'] as bool? ?? false,
      zeroShotConfidence: (map['zeroShotConfidence'] as num?)?.toDouble(),
      totalScans: (map['totalScans'] as num?)?.toInt(),
    );
  }

  String get confidencePercentText => formatConfidence(confidenceScore);
}
