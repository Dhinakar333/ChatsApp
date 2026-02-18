import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../domain/repositories/chat_repository.dart';
import 'chats_state.dart';

class ChatsCubit extends Cubit<ChatsState> {
  final ChatRepository _chatRepository;
  final String _myUid;
  StreamSubscription? _sub;

  ChatsCubit({
    required ChatRepository chatRepository,
    required String myUid,
  })  : _chatRepository = chatRepository,
        _myUid = myUid,
        super(const ChatsState.initial());

  void start() {
    emit(state.copyWith(status: ChatsStatus.loading, errorMessage: null));
    _sub?.cancel();
    _sub = _chatRepository.watchChatSummaries(_myUid).listen(
      (chats) => emit(state.copyWith(status: ChatsStatus.success, chats: chats, errorMessage: null)),
      onError: (e) => emit(state.copyWith(status: ChatsStatus.failure, errorMessage: e.toString())),
    );
  }

  Future<void> markChatRead(String chatId) async {
    await _chatRepository.markChatRead(chatId: chatId, uid: _myUid);
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}

