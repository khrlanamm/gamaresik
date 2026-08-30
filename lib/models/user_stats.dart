import 'package:cloud_firestore/cloud_firestore.dart';

import 'waste_category.dart';

/// Aggregate per-user counters kept in `users/{uid}`.
///
/// These are maintained server-side by the Cloud Functions (atomically, in the
/// same transaction that writes each scan log), so the app reads a single
/// document instead of counting the whole classifications collection.
class UserStats {
  final int totalScans;
  final Map<WasteCategory, int> categoryCounts;
  final DateTime? lastScanAt;

  const UserStats({
    required this.totalScans,
    required this.categoryCounts,
    required this.lastScanAt,
  });

  static Map<WasteCategory, int> get _emptyCounts => {
        for (final category in WasteCategory.values) category: 0,
      };

  /// Stats for a user who has never scanned (no document yet).
  factory UserStats.empty() => UserStats(
        totalScans: 0,
        categoryCounts: _emptyCounts,
        lastScanAt: null,
      );

  factory UserStats.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    if (!doc.exists) return UserStats.empty();
    final data = doc.data() ?? {};

    final raw = (data['categoryCounts'] as Map?) ?? {};
    final counts = _emptyCounts;
    for (final category in WasteCategory.values) {
      final value = raw[category.id];
      // Clamp at 0: a correction could in principle drive a stale counter
      // negative, and a negative count should never reach the UI.
      counts[category] = value is num ? value.toInt().clamp(0, 1 << 31) : 0;
    }

    return UserStats(
      totalScans: (data['totalScans'] as num?)?.toInt().clamp(0, 1 << 31) ?? 0,
      categoryCounts: counts,
      lastScanAt: (data['lastScanAt'] as Timestamp?)?.toDate(),
    );
  }
}
