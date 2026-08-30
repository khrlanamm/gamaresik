/// The signed-in user, as the UI needs them.
///
/// Deliberately independent of `firebase_auth`'s `User` so views and view
/// models never depend on the Firebase SDK types — which also makes them
/// testable without a live Firebase app.
class AppUser {
  final String uid;
  final String? displayName;
  final String? email;
  final String? photoURL;

  const AppUser({
    required this.uid,
    this.displayName,
    this.email,
    this.photoURL,
  });
}
