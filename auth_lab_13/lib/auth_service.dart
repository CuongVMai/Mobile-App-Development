import 'package:firebase_auth/firebase_auth.dart';

////// the "front desk": every account action goes through this one class //////
class AuthService {
  ////// one shared instance so the auth stream stays stable (not recreated) //////
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  ////// stable stream: created once, reused by AuthGate on every rebuild //////
  late final Stream<User?> authStateChanges = _auth.authStateChanges();

  ////// current-user getter //////
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> register(String email, String password) {
    return _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> signIn(String email, String password) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() {
    return _auth.signOut();
  }

  Future<void> changePassword(String newPassword) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('A signed-in user is required to change a password.');
    }
    await user.updatePassword(newPassword);
  }

  ////// re-check the CURRENT password when Firebase says the login is too old //////
  Future<void> reauthenticate(String currentPassword) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw StateError('No signed-in user with an email was found.');
    }
    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
  }

  ////// turn Firebase error codes into helpful messages (no raw exception text) //////
  static String friendlyMessage(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'That email address doesn\'t look right.';
        case 'email-already-in-use':
          return 'An account already exists for that email. Try signing in.';
        case 'weak-password':
          return 'That password is too weak. Use at least 6 characters.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          ////// same message for both so we don't reveal which emails have accounts //////
          return 'Email or password is incorrect.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'too-many-requests':
          return 'Too many attempts. Wait a bit and try again.';
        case 'network-request-failed':
          return 'No connection. Check your internet and try again.';
        case 'requires-recent-login':
          return 'Please confirm your current password to continue.';
        case 'user-mismatch':
          return 'That password belongs to a different account.';
        case 'operation-not-allowed':
          return 'Email/password sign-in is not enabled for this project.';
        default:
          return 'Something went wrong (${error.code}). Please try again.';
      }
    }
    if (error is StateError) {
      return 'You need to be signed in to do that. Please sign in again.';
    }
    return 'Something went wrong. Please try again.';
  }
}
