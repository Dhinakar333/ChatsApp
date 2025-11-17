import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? user;
  String? displayName;
  bool isLoading = true;
  String? error;

  AuthProvider() {
    _auth.authStateChanges().listen((u) async {
      user = u;
      if (u != null) {
        await _loadUserData();
        await _setupOneSignal();
      } else {
        OneSignal.logout(); // Clear on sign out
      }
      isLoading = false;
      notifyListeners();
    });
  }

  Future<void> _loadUserData() async {
    final snap = await _db.collection('users').doc(user!.uid).get();
    displayName = snap['name'] ?? user!.email ?? 'User';
  }

  Future<void> _setupOneSignal() async {
    if (user == null) return;

    OneSignal.login(user!.uid);
    OneSignal.User.addTagWithKey("user_id", user!.uid);

    // Get Player ID
    String? playerId = OneSignal.User.pushSubscription.id;
    if (playerId != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .update({'playerId': playerId});
      print("Saved Player ID: $playerId");
    }
  }

  Future<void> signup(String name, String email, String password) async {
    isLoading = true;
    notifyListeners();
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      user = cred.user;
      displayName = name;

      await _db.collection('users').doc(user!.uid).set({
        'name': name,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _setupOneSignal();
      error = null;
    } on FirebaseAuthException catch (e) {
      error = e.message;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    isLoading = true;
    notifyListeners();
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      user = cred.user;
      await _loadUserData();
      await _setupOneSignal();
      error = null;
    } on FirebaseAuthException catch (e) {
      error = e.message;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    OneSignal.logout();
    await _auth.signOut();
    user = null;
    displayName = null;
    notifyListeners();
  }
}