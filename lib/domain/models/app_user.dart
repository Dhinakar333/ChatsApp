import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class AppUser extends Equatable {
  final String uid;
  final String name;
  final String email;
  final String? photoUrl;
  final Timestamp? createdAt;
  final Timestamp? lastSeenAt;
  final bool isOnline;

  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl,
    this.createdAt,
    this.lastSeenAt,
    this.isOnline = false,
  });

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return AppUser(
      uid: doc.id,
      name: (data['name'] as String?) ?? 'User',
      email: (data['email'] as String?) ?? '',
      photoUrl: data['photoUrl'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
      lastSeenAt: data['lastSeenAt'] as Timestamp?,
      isOnline: (data['isOnline'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (createdAt != null) 'createdAt': createdAt,
      if (lastSeenAt != null) 'lastSeenAt': lastSeenAt,
      'isOnline': isOnline,
    };
  }

  @override
  List<Object?> get props => [uid, name, email, photoUrl, createdAt, lastSeenAt, isOnline];
}

