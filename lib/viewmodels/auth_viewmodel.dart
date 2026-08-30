import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/firebase_service.dart';

enum GoogleSignInResult { success, cancelled, failed }

class AuthViewModel extends ChangeNotifier {
  final GamaBackend _backend;

  AuthViewModel({GamaBackend? backend}) : _backend = backend ?? FirebaseService();

  bool _isLoading = false;
  bool _isSigningOut = false;

  bool get isLoading => _isLoading;
  bool get isSigningOut => _isSigningOut;
  AppUser? get user => _backend.currentUser;

  Future<GoogleSignInResult> signInWithGoogle() async {
    // Guard against a second tap while the chooser is already open.
    if (_isLoading) return GoogleSignInResult.cancelled;

    _isLoading = true;
    notifyListeners();

    try {
      final credential = await _backend.signInWithGoogle();
      return credential != null
          ? GoogleSignInResult.success
          : GoogleSignInResult.cancelled;
    } catch (e) {
      return GoogleSignInResult.failed;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Returns true when the user was actually signed out. A failed sign-out
  /// used to be completely silent, leaving the user apparently still logged in
  /// with no explanation.
  Future<bool> signOut() async {
    if (_isSigningOut) return false;

    _isSigningOut = true;
    notifyListeners();
    try {
      await _backend.signOut();
      return true;
    } catch (e) {
      return false;
    } finally {
      _isSigningOut = false;
      notifyListeners();
    }
  }
}
