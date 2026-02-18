import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum MessageType { text, image, voice }

class ChatMessage extends Equatable {
  final String id;
  final String chatId;
  final String senderId;
  final MessageType type;
  final String text;
  final String? mediaUrl;
  final Timestamp? createdAt;
  final Timestamp? editedAt;
  final String? replyToMessageId;
  final String? replyToSenderId;
  final String? replyToTextSnippet;
  final Map<String, List<String>> reactions;
  final Map<String, Timestamp?> deliveredAt;
  final Map<String, Timestamp?> readAt;
  final Map<String, bool> deletedFor;
  final Timestamp? deletedAt;

  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.type,
    required this.text,
    this.mediaUrl,
    this.createdAt,
    this.editedAt,
    this.replyToMessageId,
    this.replyToSenderId,
    this.replyToTextSnippet,
    this.reactions = const {},
    this.deliveredAt = const {},
    this.readAt = const {},
    this.deletedFor = const {},
    this.deletedAt,
  });

  factory ChatMessage.fromDoc({
    required String chatId,
    required DocumentSnapshot<Map<String, dynamic>> doc,
  }) {
    final data = doc.data() ?? const <String, dynamic>{};
    final typeStr = (data['type'] as String?) ?? 'text';
    final type = switch (typeStr) {
      'image' => MessageType.image,
      'voice' => MessageType.voice,
      _ => MessageType.text,
    };

    final rawReactions = (data['reactions'] as Map?) ?? const {};
    final reactions = <String, List<String>>{};
    for (final entry in rawReactions.entries) {
      final key = entry.key.toString();
      final value = entry.value;
      if (value is List) {
        reactions[key] = value.map((e) => e.toString()).toList();
      }
    }

    final rawReadAt = (data['readAt'] as Map?) ?? const {};
    final readAt = <String, Timestamp?>{};
    for (final entry in rawReadAt.entries) {
      readAt[entry.key.toString()] = entry.value is Timestamp ? entry.value as Timestamp : null;
    }

    final rawDeliveredAt = (data['deliveredAt'] as Map?) ?? const {};
    final deliveredAt = <String, Timestamp?>{};
    for (final entry in rawDeliveredAt.entries) {
      deliveredAt[entry.key.toString()] = entry.value is Timestamp ? entry.value as Timestamp : null;
    }

    final rawDeletedFor = (data['deletedFor'] as Map?) ?? const {};
    final deletedFor = <String, bool>{};
    for (final entry in rawDeletedFor.entries) {
      deletedFor[entry.key.toString()] = entry.value == true;
    }

    final replyTo = (data['replyTo'] as Map?)?.cast<String, dynamic>();

    return ChatMessage(
      id: doc.id,
      chatId: chatId,
      senderId: (data['senderId'] as String?) ?? '',
      type: type,
      text: (data['text'] as String?) ?? '',
      mediaUrl: data['mediaUrl'] as String?,
      createdAt: data['createdAt'] as Timestamp? ?? data['timestamp'] as Timestamp?,
      editedAt: data['editedAt'] as Timestamp?,
      replyToMessageId: replyTo?['messageId'] as String? ?? data['replyTo'] as String?,
      replyToSenderId: replyTo?['senderId'] as String?,
      replyToTextSnippet: replyTo?['textSnippet'] as String?,
      reactions: reactions,
      deliveredAt: deliveredAt,
      readAt: readAt,
      deletedFor: deletedFor,
      deletedAt: data['deletedAt'] as Timestamp?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        chatId,
        senderId,
        type,
        text,
        mediaUrl,
        createdAt,
        editedAt,
        replyToMessageId,
        replyToSenderId,
        replyToTextSnippet,
        reactions,
        deliveredAt,
        readAt,
        deletedFor,
        deletedAt,
      ];
}
