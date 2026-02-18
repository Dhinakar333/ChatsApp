import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/chat_message.dart';
import '../models/chat_summary.dart';

abstract interface class ChatRepository {
  String chatIdForSorted(String uid1, String uid2);

  Stream<List<AppUser>> watchUsers();
  Stream<List<ChatSummary>> watchChatSummaries(String myUid);
  Stream<List<ChatMessage>> watchMessages(String chatId, {required int limit});
  Future<List<ChatMessage>> fetchOlderMessages({
    required String chatId,
    required int limit,
    required Timestamp startAfterTimestamp,
    required String startAfterId,
  });

  Future<void> sendTextMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String text,
    Map<String, dynamic>? replyTo,
  });

  Future<void> markChatRead({
    required String chatId,
    required String uid,
  });

  Future<void> markMessageRead({
    required String chatId,
    required String messageId,
    required String uid,
  });

  Future<void> markMessageDelivered({
    required String chatId,
    required String messageId,
    required String uid,
  });

  Future<void> markMessagesDelivered({
    required String chatId,
    required String uid,
    required List<String> messageIds,
  });

  Future<void> markMessagesRead({
    required String chatId,
    required String uid,
    required List<String> messageIds,
  });

  Future<void> editTextMessage({
    required String chatId,
    required String messageId,
    required String editorUid,
    required String newText,
  });

  Future<void> deleteMessageForEveryone({
    required String chatId,
    required String messageId,
    required String deleterUid,
  });

  Future<void> deleteMessageForMe({
    required String chatId,
    required String messageId,
    required String uid,
  });

  Stream<Timestamp?> watchTypingUntil({
    required String chatId,
    required String uid,
  });

  Future<void> setTypingUntil({
    required String chatId,
    required String uid,
    Timestamp? typingUntil,
  });

  Future<DocumentSnapshot<Map<String, dynamic>>> getUserDoc(String uid);
}
