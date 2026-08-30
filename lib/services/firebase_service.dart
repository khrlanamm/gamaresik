import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/app_user.dart';
import '../models/classification_result.dart';
import '../models/scan_record.dart';
import '../models/user_stats.dart';
import '../models/waste_category.dart';
import 'gama_backend.dart';

export 'gama_backend.dart' show GamaBackend, ScanException;

/// Region the Cloud Functions are deployed to. Must match `REGION` in
/// functions/index.js — the client SDK defaults to us-central1 and calls
/// silently 404 if these drift apart.
const _kFunctionsRegion = 'asia-southeast2';

/// Mirrors MAX_IMAGE_BYTES in functions/index.js so oversized photos are
/// rejected before wasting an upload.
const int _kMaxImageBytes = 10 * 1024 * 1024;

AppUser? _toAppUser(User? user) => user == null
    ? null
    : AppUser(
        uid: user.uid,
        displayName: user.displayName,
        email: user.email,
        photoURL: user.photoURL,
      );

class FirebaseService implements GamaBackend {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: _kFunctionsRegion);

  @override
  AppUser? get currentUser => _toAppUser(_auth.currentUser);

  @override
  Future<AppUser?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final result = await _auth.signInWithCredential(credential);
    return _toAppUser(result.user);
  }

  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  @override
  String newScanRequestId() => _firestore.collection('users').doc().id;

  /// Rejects obviously unusable captures before spending an upload on them.
  Future<void> validateImage(File file) async {
    if (!await file.exists()) {
      throw const ScanException('File gambar tidak ditemukan. Coba ambil ulang.');
    }
    final length = await file.length();
    if (length == 0) {
      throw const ScanException('Gambar kosong atau rusak. Coba ambil ulang.');
    }
    if (length > _kMaxImageBytes) {
      throw const ScanException('Ukuran gambar melebihi 10 MB. Coba ambil ulang.');
    }
  }

  /// Uploads a captured photo to `scans/{uid}/{scanId}.jpg`.
  ///
  /// Keyed by [scanId] so retrying the same capture overwrites one object
  /// instead of littering Storage with orphans.
  @override
  Future<({String storagePath, String imageUrl})> uploadScanImage(
    File imageFile, {
    required String scanId,
  }) async {
    final uid = currentUser?.uid;
    if (uid == null) {
      throw const ScanException('Sesi Anda berakhir. Silakan login kembali.');
    }

    await validateImage(imageFile);

    final storagePath = 'scans/$uid/$scanId.jpg';
    final ref = _storage.ref(storagePath);

    try {
      // Bounded so a stalled upload surfaces a retry instead of spinning
      // indefinitely on a flaky connection.
      await ref
          .putFile(imageFile, SettableMetadata(contentType: 'image/jpeg'))
          .timeout(const Duration(seconds: 90));
      final imageUrl = await ref.getDownloadURL().timeout(const Duration(seconds: 30));
      return (storagePath: storagePath, imageUrl: imageUrl);
    } on TimeoutException {
      throw const ScanException(
        'Unggahan gambar terlalu lama. Periksa koneksi Anda lalu coba lagi.',
      );
    } on FirebaseException catch (e) {
      throw ScanException(
        e.code == 'unauthorized'
            ? 'Anda tidak berhak mengunggah gambar ini.'
            : 'Gagal mengunggah gambar. Periksa koneksi Anda lalu coba lagi.',
      );
    }
  }

  /// Calls the classifyWaste Cloud Function.
  ///
  /// The function decides zero-shot/few-shot/selective from the live
  /// app_config/settings document, runs Gemini, and writes both the scan log
  /// and the user's aggregate counters itself.
  @override
  Future<ClassificationResult> classifyWaste({
    required String storagePath,
    required String imageUrl,
    required String scanId,
  }) async {
    try {
      final callable = _functions.httpsCallable(
        'classifyWaste',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
      );
      final response = await callable.call<Object?>(<String, dynamic>{
        'storagePath': storagePath,
        'imageUrl': imageUrl,
        'clientRequestId': scanId,
      });
      return ClassificationResult.fromCallableData(response.data);
    } on FirebaseFunctionsException catch (e) {
      throw ScanException(_messageForFunctionsError(e));
    }
  }

  /// Records a "Laporan Hasil Tidak Tepat" correction.
  ///
  /// Goes through a Cloud Function rather than writing Firestore directly:
  /// the few-shot pool and the user's counters are both privileged data that
  /// clients must not be able to edit.
  @override
  Future<void> submitCorrection({
    required String logId,
    required WasteCategory correctCategory,
  }) async {
    try {
      final callable = _functions.httpsCallable(
        'submitCorrection',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
      );
      await callable.call<Object?>(<String, dynamic>{
        'logId': logId,
        'correctCategory': correctCategory.id,
      });
    } on FirebaseFunctionsException catch (e) {
      throw ScanException(_messageForFunctionsError(e));
    }
  }

  /// Turns a callable error into copy the user can act on. The Cloud Function
  /// already sends Indonesian messages for the cases it anticipates, so those
  /// are preferred over anything invented here.
  String _messageForFunctionsError(FirebaseFunctionsException e) {
    final serverMessage = e.message;
    if (serverMessage != null && serverMessage.isNotEmpty && e.code != 'internal') {
      return serverMessage;
    }
    switch (e.code) {
      case 'unauthenticated':
        return 'Sesi Anda berakhir. Silakan login kembali.';
      case 'permission-denied':
        return 'Anda tidak berhak melakukan tindakan ini.';
      case 'resource-exhausted':
        return 'Kuota layanan AI sedang habis. Silakan hubungi pengelola aplikasi.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Layanan sedang sibuk. Periksa koneksi Anda lalu coba lagi.';
      case 'not-found':
        return 'Data tidak ditemukan.';
      default:
        return 'Gagal memproses permintaan. Silakan coba lagi.';
    }
  }

  /// Aggregate counters for the signed-in user, maintained server-side.
  @override
  Future<UserStats> getUserStats() async {
    final uid = currentUser?.uid;
    if (uid == null) return UserStats.empty();

    final doc = await _firestore.collection('users').doc(uid).get();
    return UserStats.fromDoc(doc);
  }

  /// Most recent scans for the signed-in user, newest first.
  @override
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
}
