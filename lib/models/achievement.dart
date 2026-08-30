import 'package:flutter/material.dart';

/// A scan-count milestone.
///
/// Milestones are derived from the persisted `totalScans` counter rather than
/// stored separately, so unlocked state can never drift out of sync with the
/// real scan count.
class Achievement {
  final int target;
  final String title;
  final String description;
  final IconData icon;

  const Achievement({
    required this.target,
    required this.title,
    required this.description,
    required this.icon,
  });

  /// Ordered ascending; [AchievementProgress.of] relies on that ordering.
  static const List<Achievement> all = [
    Achievement(
      target: 50,
      title: 'Pemilah Pemula',
      description: 'Selesaikan 50 kali scan sampah',
      icon: Icons.eco_rounded,
    ),
    Achievement(
      target: 100,
      title: 'Pejuang Pilah',
      description: 'Selesaikan 100 kali scan sampah',
      icon: Icons.recycling_rounded,
    ),
    Achievement(
      target: 500,
      title: 'Penjaga Kampus',
      description: 'Selesaikan 500 kali scan sampah',
      icon: Icons.workspace_premium_rounded,
    ),
    Achievement(
      target: 1000,
      title: 'Legenda Gamaresik',
      description: 'Selesaikan 1000 kali scan sampah',
      icon: Icons.emoji_events_rounded,
    ),
  ];

  bool isUnlockedAt(int totalScans) => totalScans >= target;
}

/// Snapshot of where a user sits along the milestone ladder.
class AchievementProgress {
  final int totalScans;
  final Achievement? next;
  final Achievement? lastUnlocked;

  const AchievementProgress({
    required this.totalScans,
    required this.next,
    required this.lastUnlocked,
  });

  factory AchievementProgress.of(int totalScans) {
    Achievement? next;
    Achievement? lastUnlocked;
    for (final achievement in Achievement.all) {
      if (achievement.isUnlockedAt(totalScans)) {
        lastUnlocked = achievement;
      } else {
        next ??= achievement;
      }
    }
    return AchievementProgress(
      totalScans: totalScans,
      next: next,
      lastUnlocked: lastUnlocked,
    );
  }

  /// True once every milestone has been reached.
  bool get isComplete => next == null;

  /// Scans still needed for [next]; 0 when every milestone is unlocked.
  int get remaining => next == null ? 0 : (next!.target - totalScans).clamp(0, 1 << 31);

  /// Progress through the *current band* (previous milestone → next one), so
  /// the bar restarts after each unlock instead of creeping toward 100% once.
  double get progress {
    if (next == null) return 1.0;
    final floor = lastUnlocked?.target ?? 0;
    final span = next!.target - floor;
    if (span <= 0) return 1.0;
    return ((totalScans - floor) / span).clamp(0.0, 1.0);
  }

  int get unlockedCount => Achievement.all.where((a) => a.isUnlockedAt(totalScans)).length;
}
