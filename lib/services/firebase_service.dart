import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      print('Error signing in with Google: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<void> saveClassification(Map<String, dynamic> data) async {
    if (currentUser == null) return;
    
    await _firestore.collection('users').doc(currentUser!.uid).collection('classifications').add({
      ...data,
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

  Future<Map<String, int>> getCategoryCounts() async {
    if (currentUser == null) return {};
    
    final snapshot = await _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .collection('classifications')
        .get();
    
    Map<String, int> counts = {
      'Organik Terpilah': 0,
      'Recycle Bersih': 0,
      'Residu Terpilah': 0,
    };

    for (var doc in snapshot.docs) {
      final result = doc.data()['result'] as String?;
      if (result != null && counts.containsKey(result)) {
        counts[result] = (counts[result] ?? 0) + 1;
      }
    }
    
    return counts;
  }
}
