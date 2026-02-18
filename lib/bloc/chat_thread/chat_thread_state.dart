import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/chat_message.dart';

enum ChatThreadStatus { initial, loading, success, failure }

class ChatThreadState extends Equatable {
  final ChatThreadStatus status;
  final List<ChatMessage> messages;
  final bool isSending;
  final bool isLoadingMore;
  final bool hasMore;
  final Timestamp? peerTypingUntil;
  final String? replyToMessageId;
  final String? replyToSenderId;
  final String? replyToTextSnippet;
  final String? editingMessageId;
  final String? errorMessage;

  const ChatThreadState({
    required this.status,
    this.messages = const [],
    this.isSending = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.peerTypingUntil,
    this.replyToMessageId,
    this.replyToSenderId,
    this.replyToTextSnippet,
    this.editingMessageId,
    this.errorMessage,
  });

  const ChatThreadState.initial() : this(status: ChatThreadStatus.initial);

  ChatThreadState copyWith({
    ChatThreadStatus? status,
    List<ChatMessage>? messages,
    bool? isSending,
    bool? isLoadingMore,
    bool? hasMore,
    Timestamp? peerTypingUntil,
    String? replyToMessageId,
    String? replyToSenderId,
    String? replyToTextSnippet,
    String? editingMessageId,
    String? errorMessage,
  }) {
    return ChatThreadState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      isSending: isSending ?? this.isSending,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      peerTypingUntil: peerTypingUntil ?? this.peerTypingUntil,
      replyToMessageId: replyToMessageId,
      replyToSenderId: replyToSenderId,
      replyToTextSnippet: replyToTextSnippet,
      editingMessageId: editingMessageId,
      errorMessage: errorMessage,
    );
  }

  bool get isPeerTyping {
    final ts = peerTypingUntil;
    if (ts == null) return false;
    return ts.toDate().isAfter(DateTime.now());
  }

  @override
  List<Object?> get props => [
        status,
        messages,
        isSending,
        isLoadingMore,
        hasMore,
        peerTypingUntil,
        replyToMessageId,
        replyToSenderId,
        replyToTextSnippet,
        editingMessageId,
        errorMessage,
      ];
}
