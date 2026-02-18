import 'package:firebase_auth/firebase_auth.dart';

abstract interface class AuthRepository {
  Stream<User?> authStateChanges();
  User? currentUser();

  Future<void> signup({
    required String name,
    required String email,
    required String password,
  });

  Future<void> login({
    required String email,
    required String password,
  });

  Future<void> logout();

  Future<void> sendPasswordResetEmail(String email);

  Future<String> getDisplayName(String uid);

  Future<void> ensurePushToken({
    required String uid,
  });

  Future<void> setPresence({
    required String uid,
    required bool isOnline,
  });
}
