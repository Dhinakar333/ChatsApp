import 'package:equatable/equatable.dart';

import '../../domain/models/app_user.dart';

enum UsersStatus { initial, loading, success, failure }

class UsersState extends Equatable {
  final UsersStatus status;
  final List<AppUser> users;
  final String? errorMessage;

  const UsersState({
    required this.status,
    this.users = const [],
    this.errorMessage,
  });

  const UsersState.initial() : this(status: UsersStatus.initial);

  UsersState copyWith({
    UsersStatus? status,
    List<AppUser>? users,
    String? errorMessage,
  }) {
    return UsersState(
      status: status ?? this.status,
      users: users ?? this.users,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, users, errorMessage];
}

