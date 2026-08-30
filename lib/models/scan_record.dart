import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/formatters.dart';
import 'waste_category.dart';

/// One past classification, read back from `users/{uid}/classifications`.
class ScanRecord {
  final String id;

  /// Category as originally predicted by the model.
  final WasteCategory category;
  final String predictedLabel;
  final double confidenceScore;
  final String? reasoning;
  final String? imageUrl;

  /// Which configured strategy produced this result.
  final String classificationMode;
  final bool usedFewShot;

  final bool corrected;
  final WasteCategory? correctedCategory;
  final DateTime? timestamp;

  const ScanRecord({
    required this.id,
    required this.category,
    required this.predictedLabel,
    required this.confidenceScore,
    required this.reasoning,
    required this.imageUrl,
    required this.classificationMode,
    required this.usedFewShot,
    required this.corrected,
    required this.correctedCategory,
    required this.timestamp,
  });

  factory ScanRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final corrected = data['corrected'] as bool? ?? false;
    final correctedId = data['correctedCategory'] as String?;

    return ScanRecord(
      id: doc.id,
      category: WasteCategory.fromId(data['category'] as String?),
      predictedLabel: data['predictedLabel'] as String? ?? '',
      confidenceScore: (data['confidenceScore'] as num?)?.toDouble() ?? 0,
      reasoning: data['reasoning'] as String?,
      imageUrl: data['imageUrl'] as String?,
      classificationMode: data['classificationMode'] as String? ?? 'selective',
      usedFewShot: data['usedFewShot'] as bool? ?? false,
      corrected: corrected,
      correctedCategory:
          corrected && correctedId != null ? WasteCategory.fromId(correctedId) : null,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
    );
  }

  /// The category that should be shown to the user: a human correction wins
  /// over the model's original guess.
  WasteCategory get effectiveCategory => correctedCategory ?? category;

  String get confidencePercentText => formatConfidence(confidenceScore);
}
