import 'package:flutter/material.dart';
import '../services/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum GoogleSignInResult { success, cancelled, failed }

class AuthViewModel extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = false;

  bool get isLoading => _isLoading;
  User? get user => _firebaseService.currentUser;

  Future<GoogleSignInResult> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();

    try {
      final credential = await _firebaseService.signInWithGoogle();
      _isLoading = false;
      notifyListeners();
      return credential != null
          ? GoogleSignInResult.success
          : GoogleSignInResult.cancelled;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return GoogleSignInResult.failed;
    }
  }

  Future<void> signOut() async {
    await _firebaseService.signOut();
    notifyListeners();
  }
}
