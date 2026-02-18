import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class ChatSummary extends Equatable {
  final String chatId;
  final String peerId;
  final String peerName;
  final String peerEmail;
  final String lastMessage;
  final Timestamp? lastMessageAt;
  final int unreadCount;

  const ChatSummary({
    required this.chatId,
    required this.peerId,
    required this.peerName,
    required this.peerEmail,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
  });

  @override
  List<Object?> get props => [
        chatId,
        peerId,
        peerName,
        peerEmail,
        lastMessage,
        lastMessageAt,
        unreadCount,
      ];
}

