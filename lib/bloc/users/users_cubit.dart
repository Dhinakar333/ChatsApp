import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../domain/repositories/chat_repository.dart';
import 'users_state.dart';

class UsersCubit extends Cubit<UsersState> {
  final ChatRepository _chatRepository;
  StreamSubscription? _sub;

  UsersCubit({required ChatRepository chatRepository})
      : _chatRepository = chatRepository,
        super(const UsersState.initial());

  void start() {
    emit(state.copyWith(status: UsersStatus.loading, errorMessage: null));
    _sub?.cancel();
    _sub = _chatRepository.watchUsers().listen(
      (users) => emit(state.copyWith(status: UsersStatus.success, users: users, errorMessage: null)),
      onError: (e) => emit(state.copyWith(status: UsersStatus.failure, errorMessage: e.toString())),
    );
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}

