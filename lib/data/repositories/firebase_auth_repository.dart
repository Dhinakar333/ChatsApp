import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../domain/repositories/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final FirebaseMessaging _messaging;

  StreamSubscription<String>? _tokenRefreshSub;

  FirebaseAuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? db,
    FirebaseMessaging? messaging,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance,
        _messaging = messaging ?? FirebaseMessaging.instance;

  @override
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  @override
  User? currentUser() => _auth.currentUser;

  @override
  Future<void> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    final user = cred.user;
    if (user == null) throw StateError('Signup failed');

    await _db.collection('users').doc(user.uid).set({
      'name': name,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _setupFcmForUser(user.uid);
  }

  @override
  Future<void> login({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
    final user = cred.user;
    if (user == null) throw StateError('Login failed');

    await _setupFcmForUser(user.uid);
  }

  @override
  Future<void> logout() async {
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    await _auth.signOut();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  @override
  Future<String> getDisplayName(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    final data = snap.data();
    return (data?['name'] as String?) ?? (data?['email'] as String?) ?? 'User';
  }

  @override
  Future<void> ensurePushToken({required String uid}) => _setupFcmForUser(uid);

  @override
  Future<void> setPresence({required String uid, required bool isOnline}) async {
    await _db.collection('users').doc(uid).set(
      {
        'isOnline': isOnline,
        'lastSeenAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> dispose() async {
    await _tokenRefreshSub?.cancel();
  }

  Future<void> _setupFcmForUser(String uid) async {
    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
      final token = await _messaging.getToken();
      if (token != null) {
        await _db.collection('users').doc(uid).set({'fcmToken': token}, SetOptions(merge: true));
      }

      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = _messaging.onTokenRefresh.listen((newToken) async {
        await _db.collection('users').doc(uid).set({'fcmToken': newToken}, SetOptions(merge: true));
      });
    } catch (_) {
      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = null;
    }
  }
}
