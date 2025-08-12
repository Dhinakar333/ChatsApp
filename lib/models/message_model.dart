import 'package:cloud_firestore/cloud_firestore.dart';

class MessageModel {
  final String id;
  final String text;
  final String senderId;
  final DateTime? timestamp;

  MessageModel({
    required this.id,
    required this.text,
    required this.senderId,
    this.timestamp,
  });

  factory MessageModel.fromMap(String id, Map<String, dynamic> m) {
    return MessageModel(
      id: id,
      text: m['text'] ?? '',
      senderId: m['senderId'] ?? '',
      timestamp: m['timestamp'] != null
          ? (m['timestamp'] as Timestamp).toDate()
          : null,
    );
  }
}
