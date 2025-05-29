import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Constructor to set persistence
  AuthService() {
    _initializePersistence();
  }

  // Initialize persistence
  Future<void> _initializePersistence() async {
    try {
      await _auth.setPersistence(Persistence.LOCAL);
      print('Persistence set to LOCAL at ${DateTime.now().toIso8601String()}');
    } catch (e) {
      print('Error setting Firebase persistence: $e at ${DateTime.now().toIso8601String()}');
      rethrow;
    }
  }

  // Refresh current user to ensure latest authentication state
  Future<void> refreshCurrentUser() async {
    await _auth.currentUser?.reload();
    print('Refreshed current user at ${DateTime.now().toIso8601String()}');
  }

  // Get current user with detailed debugging
  User? get currentUser {
    final user = _auth.currentUser;
    print('AuthService - Current user: ${user?.email ?? 'null'} at ${DateTime.now().toIso8601String()}');
    return user;
  }

  // Get current user ID
  Future<String?> getCurrentUserId() async {
    final user = _auth.currentUser;
    final uid = user?.uid;
    print('AuthService - Current user ID: ${uid ?? 'null'} at ${DateTime.now().toIso8601String()}');
    return uid;
  }

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('Signed in user: ${userCredential.user?.email} at ${DateTime.now().toIso8601String()}');
      await refreshCurrentUser(); // Refresh user state after sign-in
      return userCredential;
    } catch (e) {
      print('Sign-in error: $e at ${DateTime.now().toIso8601String()}');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
    print('User signed out at ${DateTime.now().toIso8601String()}');
    await refreshCurrentUser(); // Refresh state after sign-out
  }
}