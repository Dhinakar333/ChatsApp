import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatProvider extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String chatIdForSorted(String uid1, String uid2) {
    if (uid1.compareTo(uid2) < 0) {
      return '${uid1}_$uid2';
    } else {
      return '${uid2}_$uid1';
    }
  }

  Stream<QuerySnapshot> messagesStream(String chatId) {
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> sendMessage(String chatId, String senderId, String text, String senderName) async {
    final chatDoc = _db.collection('chats').doc(chatId);
    final doc = await chatDoc.get();
    if (!doc.exists) {
      await chatDoc.set({'participants': chatId.split('_')});
    }
    await chatDoc.collection('messages').add({
      'text': text,
      'senderId': senderId,
      'senderName': senderName,   // ← Important for future features
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}