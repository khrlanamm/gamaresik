import 'dart:io';

import 'package:gamaresik/models/app_user.dart';
import 'package:gamaresik/models/classification_result.dart';
import 'package:gamaresik/models/scan_record.dart';
import 'package:gamaresik/models/user_stats.dart';
import 'package:gamaresik/models/waste_category.dart';
import 'package:gamaresik/services/gama_backend.dart';

/// In-memory [GamaBackend] so screens can be widget-tested without Firebase.
class FakeBackend implements GamaBackend {
  FakeBackend({
    this.user = const AppUser(
      uid: 'test-uid',
      displayName: 'Mahasiswa UGM',
      email: 'mahasiswa@ugm.ac.id',
    ),
    UserStats? stats,
    List<ScanRecord>? history,
    this.statsError,
    this.historyError,
  })  : stats = stats ?? UserStats.empty(),
        history = history ?? const [];

  AppUser? user;
  UserStats stats;
  List<ScanRecord> history;

  /// When set, the matching call throws instead of returning.
  Object? statsError;
  Object? historyError;

  int statsCalls = 0;
  int historyCalls = 0;
  final List<({String logId, WasteCategory category})> corrections = [];

  @override
  AppUser? get currentUser => user;

  @override
  Future<AppUser?> signInWithGoogle() async => user;

  @override
  Future<void> signOut() async {
    user = null;
  }

  @override
  String newScanRequestId() => 'fake-scan-id';

  @override
  Future<({String storagePath, String imageUrl})> uploadScanImage(
    File imageFile, {
    required String scanId,
  }) async =>
      (storagePath: 'scans/test-uid/$scanId.jpg', imageUrl: 'https://example.test/$scanId.jpg');

  @override
  Future<ClassificationResult> classifyWaste({
    required String storagePath,
    required String imageUrl,
    required String scanId,
  }) async =>
      ClassificationResult(
        logId: scanId,
        category: WasteCategory.organic,
        label: WasteCategory.organic.classificationLabel,
        confidenceScore: 0.87,
        reasoning: 'Sisa makanan terlihat jelas.',
        usedFewShot: false,
        fewShotExampleCount: 0,
        mode: 'selective',
        escalated: false,
        zeroShotConfidence: 0.87,
        confidenceThreshold: 0.5,
        modelId: 'gemini-3.6-flash',
        latencyMs: 1800,
        totalTokens: 1540,
        thoughtsTokens: 300,
        totalScans: 1,
      );

  @override
  Future<void> submitCorrection({
    required String logId,
    required WasteCategory correctCategory,
  }) async {
    corrections.add((logId: logId, category: correctCategory));
  }

  @override
  Future<UserStats> getUserStats() async {
    statsCalls++;
    if (statsError != null) throw statsError!;
    return stats;
  }

  @override
  Future<List<ScanRecord>> getScanHistory({int limit = 50}) async {
    historyCalls++;
    if (historyError != null) throw historyError!;
    return history.take(limit).toList();
  }
}
