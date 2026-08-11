import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/classification_result.dart';
import '../models/scan_record.dart';
import '../models/waste_category.dart';

/// Region the classifyWaste Cloud Function is deployed to. Must match
/// functions/index.js's onCall({ region: ... }) exactly, or calls 404.
const _kFunctionsRegion = 'asia-southeast2';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: _kFunctionsRegion);

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  /// Returns null if the user cancelled the Google sign-in chooser, as
  /// opposed to throwing, which signals an actual failure.
  Future<UserCredential?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return await _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// Uploads a captured photo to `scans/{uid}/{timestamp}.jpg` and returns
  /// both the Storage path (used server-side to re-read the bytes) and a
  /// public download URL (used to render the image in the app).
  Future<({String storagePath, String imageUrl})> uploadScanImage(File imageFile) async {
    final uid = currentUser?.uid;
    if (uid == null) throw StateError('Tidak ada pengguna yang login.');

    final storagePath = 'scans/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref(storagePath);
    await ref.putFile(imageFile, SettableMetadata(contentType: 'image/jpeg'));
    final imageUrl = await ref.getDownloadURL();

    return (storagePath: storagePath, imageUrl: imageUrl);
  }

  /// Calls the classifyWaste Cloud Function. The function itself decides
  /// zero-shot/few-shot/selective based on the live app_config/settings
  /// document, runs Gemini, and writes the resulting log document — this
  /// just uploads-then-invokes and returns what came back.
  Future<ClassificationResult> classifyWaste({
    required String storagePath,
    required String imageUrl,
  }) async {
    final callable = _functions.httpsCallable(
      'classifyWaste',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 90)),
    );
    final response = await callable.call(<String, dynamic>{
      'storagePath': storagePath,
      'imageUrl': imageUrl,
    });
    return ClassificationResult.fromCallableData(response.data);
  }

  /// Records a user's "Koreksi Hasil" correction: appends a validated
  /// example for future few-shot prompts and flags the original log entry.
  Future<void> submitCorrection({
    required String logId,
    required String storagePath,
    required String imageUrl,
    required WasteCategory correctCategory,
    String? originalPrediction,
    double? originalConfidence,
  }) async {
    final uid = currentUser?.uid;
    if (uid == null) throw StateError('Tidak ada pengguna yang login.');

    final batch = _firestore.batch();

    final fewShotRef = _firestore.collection('few_shot_data').doc();
    batch.set(fewShotRef, {
      'imageUrl': imageUrl,
      'storagePath': storagePath,
      'label': correctCategory.classificationLabel,
      'validated': true,
      'sourceUid': uid,
      'originalPrediction': originalPrediction,
      'originalConfidence': originalConfidence,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final logRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('classifications')
        .doc(logId);
    batch.update(logRef, {
      'corrected': true,
      'correctedLabel': correctCategory.classificationLabel,
    });

    await batch.commit();
  }

  Future<List<ScanRecord>> getScanHistory({int limit = 50}) async {
    final uid = currentUser?.uid;
    if (uid == null) return [];

    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('classifications')
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs.map(ScanRecord.fromDoc).toList();
  }

  Future<int> getClassificationCount() async {
    if (currentUser == null) return 0;

    final snapshot = await _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('classifications')
        .count()
        .get();

    return snapshot.count ?? 0;
  }

  Future<Map<WasteCategory, int>> getCategoryCounts() async {
    final Map<WasteCategory, int> counts = {
      for (final category in WasteCategory.values) category: 0,
    };

    if (currentUser == null) return counts;

    final snapshot = await _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('classifications')
        .get();

    for (final doc in snapshot.docs) {
      final categoryId = doc.data()['category'] as String?;
      if (categoryId == null) continue;
      final category = WasteCategory.fromId(categoryId);
      counts[category] = (counts[category] ?? 0) + 1;
    }

    return counts;
  }
}
