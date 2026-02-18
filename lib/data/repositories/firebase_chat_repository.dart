import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/app_user.dart';
import '../../domain/models/chat_message.dart';
import '../../domain/models/chat_summary.dart';
import '../../domain/repositories/chat_repository.dart';

class FirebaseChatRepository implements ChatRepository {
  final FirebaseFirestore _db;
  final Map<String, AppUser> _userCache = {};

  FirebaseChatRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  @override
  String chatIdForSorted(String uid1, String uid2) {
    if (uid1.compareTo(uid2) < 0) return '${uid1}_$uid2';
    return '${uid2}_$uid1';
  }

  @override
  Stream<List<AppUser>> watchUsers() {
    return _db.collection('users').orderBy('name').snapshots().map((snap) {
      return snap.docs.map((d) => AppUser.fromDoc(d)).toList(growable: false);
    });
  }

  @override
  Stream<List<ChatSummary>> watchChatSummaries(String myUid) {
    final chatsQuery = _db
        .collection('chats')
        .where('participants', arrayContains: myUid)
        .orderBy('lastMessageAt', descending: true);

    return chatsQuery.snapshots().asyncMap((snap) async {
      final results = <ChatSummary>[];
      for (final doc in snap.docs) {
        final data = doc.data();
        final participants = (data['participants'] as List?)?.cast<String>() ?? const <String>[];
        final peerId = participants.firstWhere((id) => id != myUid, orElse: () => '');
        if (peerId.isEmpty) continue;

        final user = await _getCachedUser(peerId);
        final lastMessage = (data['lastMessage'] as String?) ?? '';
        final lastMessageAt = data['lastMessageAt'] as Timestamp?;
        final unreadCounts = (data['unreadCounts'] as Map?)?.cast<String, dynamic>() ?? const {};
        final unread = unreadCounts[myUid];
        final unreadInt = unread is int ? unread : 0;

        results.add(
          ChatSummary(
            chatId: doc.id,
            peerId: peerId,
            peerName: user?.name ?? 'User',
            peerEmail: user?.email ?? '',
            lastMessage: lastMessage,
            lastMessageAt: lastMessageAt,
            unreadCount: unreadInt,
          ),
        );
      }
      return results;
    });
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String chatId, {required int limit}) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .orderBy(FieldPath.documentId, descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) => ChatMessage.fromDoc(chatId: chatId, doc: d)).toList(growable: false));
  }

  @override
  Future<List<ChatMessage>> fetchOlderMessages({
    required String chatId,
    required int limit,
    required Timestamp startAfterTimestamp,
    required String startAfterId,
  }) async {
    final snap = await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .orderBy(FieldPath.documentId, descending: true)
        .startAfter([startAfterTimestamp, startAfterId])
        .limit(limit)
        .get();

    return snap.docs.map((d) => ChatMessage.fromDoc(chatId: chatId, doc: d)).toList(growable: false);
  }

  @override
  Future<void> sendTextMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String text,
    Map<String, dynamic>? replyTo,
  }) async {
    final chatRef = _db.collection('chats').doc(chatId);
    final participants = chatId.split('_');
    final now = FieldValue.serverTimestamp();

    await _db.runTransaction((tx) async {
      final chatSnap = await tx.get(chatRef);
      final existing = chatSnap.data();
      final unreadCountsRaw = (existing?['unreadCounts'] as Map?) ?? const {};
      final unreadCounts = Map<String, dynamic>.from(unreadCountsRaw);

      for (final uid in participants) {
        if (uid == senderId) {
          unreadCounts[uid] = 0;
        } else {
          final current = unreadCounts[uid];
          unreadCounts[uid] = (current is int ? current : 0) + 1;
        }
      }

      if (!chatSnap.exists) {
        tx.set(chatRef, {'participants': participants}, SetOptions(merge: true));
      }

      tx.set(
        chatRef,
        {
          'lastMessage': text,
          'lastSenderId': senderId,
          'lastMessageAt': now,
          'unreadCounts': unreadCounts,
        },
        SetOptions(merge: true),
      );

      final msgRef = chatRef.collection('messages').doc();
      tx.set(chatRef, {'lastMessageId': msgRef.id}, SetOptions(merge: true));

      final payload = <String, dynamic>{
        'type': 'text',
        'text': text,
        'senderId': senderId,
        'senderName': senderName,
        'timestamp': now,
        'createdAt': now,
      };
      if (replyTo != null) {
        payload['replyTo'] = replyTo;
      }
      tx.set(msgRef, payload);
    });
  }

  @override
  Future<void> markChatRead({required String chatId, required String uid}) async {
    await _db.collection('chats').doc(chatId).set({'unreadCounts.$uid': 0}, SetOptions(merge: true));
  }

  @override
  Future<void> markMessageRead({required String chatId, required String messageId, required String uid}) async {
    await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .set({'readAt.$uid': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }

  @override
  Future<void> markMessageDelivered({required String chatId, required String messageId, required String uid}) async {
    await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .set({'deliveredAt.$uid': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }

  @override
  Future<void> markMessagesDelivered({
    required String chatId,
    required String uid,
    required List<String> messageIds,
  }) async {
    if (messageIds.isEmpty) return;
    final batch = _db.batch();
    for (final id in messageIds) {
      final ref = _db.collection('chats').doc(chatId).collection('messages').doc(id);
      batch.set(ref, {'deliveredAt.$uid': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    }
    await batch.commit();
  }

  @override
  Future<void> markMessagesRead({
    required String chatId,
    required String uid,
    required List<String> messageIds,
  }) async {
    if (messageIds.isEmpty) return;
    final batch = _db.batch();
    for (final id in messageIds) {
      final ref = _db.collection('chats').doc(chatId).collection('messages').doc(id);
      batch.set(ref, {'readAt.$uid': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    }
    await batch.commit();
  }

  @override
  Future<void> editTextMessage({
    required String chatId,
    required String messageId,
    required String editorUid,
    required String newText,
  }) async {
    final trimmed = newText.trim();
    if (trimmed.isEmpty) return;
    final chatRef = _db.collection('chats').doc(chatId);
    final msgRef = chatRef.collection('messages').doc(messageId);
    final now = FieldValue.serverTimestamp();

    await _db.runTransaction((tx) async {
      final msgSnap = await tx.get(msgRef);
      final msgData = msgSnap.data();
      final senderId = (msgData?['senderId'] as String?) ?? '';
      if (senderId != editorUid) return;

      tx.set(
        msgRef,
        {
          'text': trimmed,
          'editedAt': now,
        },
        SetOptions(merge: true),
      );

      final chatSnap = await tx.get(chatRef);
      final lastId = chatSnap.data()?['lastMessageId'] as String?;
      if (lastId == messageId) {
        tx.set(chatRef, {'lastMessage': trimmed}, SetOptions(merge: true));
      }
    });
  }

  @override
  Future<void> deleteMessageForEveryone({
    required String chatId,
    required String messageId,
    required String deleterUid,
  }) async {
    final chatRef = _db.collection('chats').doc(chatId);
    final msgRef = chatRef.collection('messages').doc(messageId);
    final now = FieldValue.serverTimestamp();

    await _db.runTransaction((tx) async {
      final msgSnap = await tx.get(msgRef);
      final msgData = msgSnap.data();
      final senderId = (msgData?['senderId'] as String?) ?? '';
      if (senderId != deleterUid) return;

      tx.set(
        msgRef,
        {
          'deletedAt': now,
          'deletedBy': deleterUid,
        },
        SetOptions(merge: true),
      );

      final chatSnap = await tx.get(chatRef);
      final lastId = chatSnap.data()?['lastMessageId'] as String?;
      if (lastId == messageId) {
        tx.set(chatRef, {'lastMessage': 'Message deleted'}, SetOptions(merge: true));
      }
    });
  }

  @override
  Future<void> deleteMessageForMe({
    required String chatId,
    required String messageId,
    required String uid,
  }) async {
    await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId)
        .set({'deletedFor.$uid': true}, SetOptions(merge: true));
  }

  @override
  Stream<Timestamp?> watchTypingUntil({required String chatId, required String uid}) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('members')
        .doc(uid)
        .snapshots()
        .map((snap) => (snap.data()?['typingUntil'] as Timestamp?));
  }

  @override
  Future<void> setTypingUntil({
    required String chatId,
    required String uid,
    Timestamp? typingUntil,
  }) async {
    final ref = _db.collection('chats').doc(chatId).collection('members').doc(uid);
    if (typingUntil == null) {
      await ref.set({'typingUntil': FieldValue.delete()}, SetOptions(merge: true));
      return;
    }
    await ref.set({'typingUntil': typingUntil}, SetOptions(merge: true));
  }

  @override
  Future<DocumentSnapshot<Map<String, dynamic>>> getUserDoc(String uid) {
    return _db.collection('users').doc(uid).get();
  }

  Future<AppUser?> _getCachedUser(String uid) async {
    final cached = _userCache[uid];
    if (cached != null) return cached;
    final doc = await getUserDoc(uid);
    if (!doc.exists) return null;
    final user = AppUser.fromDoc(doc);
    _userCache[uid] = user;
    return user;
  }
}
