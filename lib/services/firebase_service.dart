import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/waste_category.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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

  Future<void> saveClassification(WasteCategory category, {String? imagePath}) async {
    if (currentUser == null) return;

    await _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('classifications')
        .add({
      'category': category.id,
      'imagePath': ?imagePath,
      'timestamp': FieldValue.serverTimestamp(),
    });
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
