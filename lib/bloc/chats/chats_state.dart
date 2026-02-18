import 'package:equatable/equatable.dart';

import '../../domain/models/chat_summary.dart';

enum ChatsStatus { initial, loading, success, failure }

class ChatsState extends Equatable {
  final ChatsStatus status;
  final List<ChatSummary> chats;
  final String? errorMessage;

  const ChatsState({
    required this.status,
    this.chats = const [],
    this.errorMessage,
  });

  const ChatsState.initial() : this(status: ChatsStatus.initial);

  ChatsState copyWith({
    ChatsStatus? status,
    List<ChatSummary>? chats,
    String? errorMessage,
  }) {
    return ChatsState(
      status: status ?? this.status,
      chats: chats ?? this.chats,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, chats, errorMessage];
}

