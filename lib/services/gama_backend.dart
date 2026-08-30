import 'dart:io';

import '../models/app_user.dart';
import '../models/classification_result.dart';
import '../models/scan_record.dart';
import '../models/user_stats.dart';
import '../models/waste_category.dart';

/// Raised for problems we can describe to the user in Indonesian. Anything
/// else bubbles up as a generic failure.
class ScanException implements Exception {
  final String message;
  const ScanException(this.message);
  @override
  String toString() => message;
}

/// Everything the app needs from the backend.
///
/// View models depend on this rather than on [FirebaseService] directly, so
/// screens can be widget-tested against a fake without initialising Firebase.
abstract class GamaBackend {
  AppUser? get currentUser;

  /// Returns null when the user cancelled the Google chooser, as opposed to
  /// throwing, which signals a real failure.
  Future<AppUser?> signInWithGoogle();

  Future<void> signOut();

  /// A stable id for one scan attempt, reused across retries so the backend
  /// can treat a repeat as idempotent.
  String newScanRequestId();

  Future<({String storagePath, String imageUrl})> uploadScanImage(
    File imageFile, {
    required String scanId,
  });

  Future<ClassificationResult> classifyWaste({
    required String storagePath,
    required String imageUrl,
    required String scanId,
  });

  Future<void> submitCorrection({
    required String logId,
    required WasteCategory correctCategory,
  });

  Future<UserStats> getUserStats();

  Future<List<ScanRecord>> getScanHistory({int limit});
}
