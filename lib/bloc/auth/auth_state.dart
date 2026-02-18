import 'package:equatable/equatable.dart';

enum AuthStatus { unknown, unauthenticated, authenticated, loading }

class AuthState extends Equatable {
  final AuthStatus status;
  final String? uid;
  final String? displayName;
  final String? errorMessage;

  const AuthState({
    required this.status,
    this.uid,
    this.displayName,
    this.errorMessage,
  });

  const AuthState.unknown() : this(status: AuthStatus.unknown);

  AuthState copyWith({
    AuthStatus? status,
    String? uid,
    String? displayName,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, uid, displayName, errorMessage];
}

