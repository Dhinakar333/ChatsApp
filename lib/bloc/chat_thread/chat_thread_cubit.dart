import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/chat_message.dart';
import '../../domain/repositories/chat_repository.dart';
import 'chat_thread_state.dart';

class ChatThreadCubit extends Cubit<ChatThreadState> {
  final ChatRepository _chatRepository;
  final String chatId;
  final String myUid;
  final String myName;
  static const int _liveLimit = 50;
  static const int _pageSize = 50;

  StreamSubscription? _messagesSub;
  StreamSubscription? _typingSub;
  DateTime? _lastTypingWriteAt;
  bool _isMarkingDelivered = false;
  bool _isLoadingMore = false;
  final List<ChatMessage> _olderMessages = [];
  final Set<String> _olderIds = {};
  List<ChatMessage> _lastLiveMessages = const [];

  ChatThreadCubit({
    required ChatRepository chatRepository,
    required this.chatId,
    required this.myUid,
    required this.myName,
  })  : _chatRepository = chatRepository,
        super(const ChatThreadState.initial());

  String get peerUid {
    final parts = chatId.split('_');
    if (parts.length < 2) return '';
    if (parts[0] == myUid) return parts[1];
    if (parts[1] == myUid) return parts[0];
    return parts.firstWhere((p) => p != myUid, orElse: () => parts[0]);
  }

  void start() {
    emit(state.copyWith(status: ChatThreadStatus.loading, errorMessage: null));
    _messagesSub?.cancel();
    _messagesSub = _chatRepository.watchMessages(chatId, limit: _liveLimit).listen(
      (messages) async {
        _lastLiveMessages = messages;
        final combined = _mergeLiveWithOlder(messages);
        emit(state.copyWith(status: ChatThreadStatus.success, messages: combined));
        await _markDeliveredIfNeeded(messages);
      },
      onError: (e) => emit(state.copyWith(status: ChatThreadStatus.failure, errorMessage: e.toString())),
    );

    _typingSub ??= _chatRepository.watchTypingUntil(chatId: chatId, uid: peerUid).listen(
      (typingUntil) => emit(state.copyWith(peerTypingUntil: typingUntil)),
      onError: (_) {},
    );
  }

  Future<void> _markDeliveredIfNeeded(List<ChatMessage> messages) async {
    if (_isMarkingDelivered) return;
    final ids = <String>[];
    for (final m in messages) {
      if (ids.length >= 20) break;
      if (m.senderId == myUid) continue;
      if (m.deliveredAt.containsKey(myUid)) continue;
      ids.add(m.id);
    }
    if (ids.isEmpty) return;
    _isMarkingDelivered = true;
    try {
      await _chatRepository.markMessagesDelivered(chatId: chatId, uid: myUid, messageIds: ids);
    } finally {
      _isMarkingDelivered = false;
    }
  }

  List<ChatMessage> _mergeLiveWithOlder(List<ChatMessage> live) {
    if (_olderMessages.isEmpty) return live;
    final liveIds = live.map((m) => m.id).toSet();
    final merged = <ChatMessage>[...live];
    for (final m in _olderMessages) {
      if (!liveIds.contains(m.id)) merged.add(m);
    }
    return merged;
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !state.hasMore) return;
    final combined = state.messages;
    if (combined.isEmpty) return;
    final oldest = combined.last;
    final ts = oldest.createdAt;
    if (ts == null) return;

    _isLoadingMore = true;
    emit(state.copyWith(isLoadingMore: true, errorMessage: null));
    try {
      final older = await _chatRepository.fetchOlderMessages(
        chatId: chatId,
        limit: _pageSize,
        startAfterTimestamp: ts,
        startAfterId: oldest.id,
      );

      for (final m in older) {
        if (_olderIds.add(m.id)) {
          _olderMessages.add(m);
        }
      }

      final merged = _mergeLiveWithOlder(_lastLiveMessages);
      emit(
        state.copyWith(
          messages: merged,
          isLoadingMore: false,
          hasMore: older.length == _pageSize,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoadingMore: false, errorMessage: e.toString()));
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> onInputChanged(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await _chatRepository.setTypingUntil(chatId: chatId, uid: myUid, typingUntil: null);
      return;
    }

    final now = DateTime.now();
    final last = _lastTypingWriteAt;
    if (last != null && now.difference(last) < const Duration(milliseconds: 900)) {
      return;
    }
    _lastTypingWriteAt = now;
    await _chatRepository.setTypingUntil(
      chatId: chatId,
      uid: myUid,
      typingUntil: Timestamp.fromDate(now.add(const Duration(seconds: 5))),
    );
  }

  void setReplyTo(ChatMessage message) {
    emit(
      state.copyWith(
        replyToMessageId: message.id,
        replyToSenderId: message.senderId,
        replyToTextSnippet: message.deletedAt != null ? 'Message deleted' : message.text,
        editingMessageId: null,
      ),
    );
  }

  void clearReplyTo() {
    emit(state.copyWith(replyToMessageId: null, replyToSenderId: null, replyToTextSnippet: null));
  }

  void beginEdit(ChatMessage message) {
    if (message.senderId != myUid) return;
    if (message.deletedAt != null) return;
    emit(
      state.copyWith(
        editingMessageId: message.id,
        replyToMessageId: null,
        replyToSenderId: null,
        replyToTextSnippet: null,
      ),
    );
  }

  void cancelEdit() {
    emit(state.copyWith(editingMessageId: null));
  }

  Future<void> submitInput(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    emit(state.copyWith(isSending: true, errorMessage: null));
    try {
      await _chatRepository.setTypingUntil(chatId: chatId, uid: myUid, typingUntil: null);
      final editingId = state.editingMessageId;
      if (editingId != null) {
        await _chatRepository.editTextMessage(
          chatId: chatId,
          messageId: editingId,
          editorUid: myUid,
          newText: trimmed,
        );
        emit(state.copyWith(isSending: false, editingMessageId: null));
        return;
      }

      final replyToId = state.replyToMessageId;
      Map<String, dynamic>? reply;
      if (replyToId != null) {
        reply = {
          'messageId': replyToId,
          'senderId': state.replyToSenderId,
          'textSnippet': state.replyToTextSnippet ?? '',
        };
      }

      await _chatRepository.sendTextMessage(
        chatId: chatId,
        senderId: myUid,
        senderName: myName,
        text: trimmed,
        replyTo: reply,
      );
      emit(state.copyWith(isSending: false));
      clearReplyTo();
    } catch (e) {
      emit(state.copyWith(isSending: false, errorMessage: e.toString()));
    }
  }

  Future<void> markChatRead() {
    final ids = <String>[];
    for (final m in state.messages) {
      if (ids.length >= 20) break;
      if (m.senderId == myUid) continue;
      if (m.readAt.containsKey(myUid)) continue;
      ids.add(m.id);
    }
    return Future.wait([
      _chatRepository.markChatRead(chatId: chatId, uid: myUid),
      _chatRepository.markMessagesRead(chatId: chatId, uid: myUid, messageIds: ids),
    ]);
  }

  Future<void> deleteForMe(String messageId) {
    return _chatRepository.deleteMessageForMe(chatId: chatId, messageId: messageId, uid: myUid);
  }

  Future<void> deleteForEveryone(String messageId) {
    return _chatRepository.deleteMessageForEveryone(chatId: chatId, messageId: messageId, deleterUid: myUid);
  }

  @override
  Future<void> close() async {
    await _messagesSub?.cancel();
    await _typingSub?.cancel();
    await _chatRepository.setTypingUntil(chatId: chatId, uid: myUid, typingUntil: null);
    return super.close();
  }
}
