import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  StreamSubscription<User?>? _authSub;

  AuthBloc({required AuthRepository authRepository})
      : _authRepository = authRepository,
        super(const AuthState.unknown()) {
    on<AuthSubscriptionRequested>(_onSubscriptionRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthSignupRequested>(_onSignupRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthPasswordResetRequested>(_onPasswordResetRequested);
  }

  Future<void> _onSubscriptionRequested(
    AuthSubscriptionRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading, errorMessage: null));

    await _authSub?.cancel();
    _authSub = _authRepository.authStateChanges().listen(
      (user) {
        if (isClosed) return;
        if (user == null) {
          emit(const AuthState(status: AuthStatus.unauthenticated));
          return;
        }

        emit(AuthState(status: AuthStatus.authenticated, uid: user.uid));

        unawaited(_authRepository.ensurePushToken(uid: user.uid));
        unawaited(
          _authRepository.getDisplayName(user.uid).then((name) {
            if (isClosed) return;
            if (state.uid != user.uid) return;
            emit(state.copyWith(status: AuthStatus.authenticated, displayName: name, errorMessage: null));
          }),
        );
      },
      onError: (_, __) {
        if (isClosed) return;
        emit(const AuthState(status: AuthStatus.unauthenticated));
      },
    );
  }

  Future<void> _onLoginRequested(AuthLoginRequested event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.loading, errorMessage: null));
    try {
      await _authRepository.login(email: event.email, password: event.password);
      emit(state.copyWith(status: AuthStatus.loading, errorMessage: null));
    } on FirebaseAuthException catch (e) {
      emit(state.copyWith(status: AuthStatus.unauthenticated, errorMessage: _friendlyFirebaseAuthError(e)));
    } catch (e) {
      emit(state.copyWith(status: AuthStatus.unauthenticated, errorMessage: e.toString()));
    }
  }

  Future<void> _onSignupRequested(AuthSignupRequested event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.loading, errorMessage: null));
    try {
      await _authRepository.signup(name: event.name, email: event.email, password: event.password);
      emit(state.copyWith(status: AuthStatus.loading, errorMessage: null));
    } on FirebaseAuthException catch (e) {
      emit(state.copyWith(status: AuthStatus.unauthenticated, errorMessage: _friendlyFirebaseAuthError(e)));
    } catch (e) {
      emit(state.copyWith(status: AuthStatus.unauthenticated, errorMessage: e.toString()));
    }
  }

  Future<void> _onLogoutRequested(AuthLogoutRequested event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.loading, errorMessage: null));
    try {
      await _authRepository.logout();
      emit(const AuthState(status: AuthStatus.unauthenticated));
    } catch (e) {
      emit(state.copyWith(status: AuthStatus.unauthenticated, errorMessage: e.toString()));
    }
  }

  Future<void> _onPasswordResetRequested(
    AuthPasswordResetRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading, errorMessage: null));
    try {
      await _authRepository.sendPasswordResetEmail(event.email);
      emit(state.copyWith(status: AuthStatus.unauthenticated, errorMessage: null));
    } on FirebaseAuthException catch (e) {
      emit(state.copyWith(status: AuthStatus.unauthenticated, errorMessage: _friendlyFirebaseAuthError(e)));
    } catch (e) {
      emit(state.copyWith(status: AuthStatus.unauthenticated, errorMessage: e.toString()));
    }
  }

  String _friendlyFirebaseAuthError(FirebaseAuthException e) {
    final code = e.code.toLowerCase();
    return switch (code) {
      'invalid-email' => 'Enter a valid email address',
      'invalid-credential' => 'Invalid email or password',
      'wrong-password' => 'Invalid email or password',
      'user-not-found' => 'No account found for this email',
      'user-disabled' => 'This account is disabled',
      'email-already-in-use' => 'Email is already in use',
      'weak-password' => 'Password is too weak (min 6 characters)',
      'too-many-requests' => 'Too many attempts. Try again later',
      _ => (e.message?.trim().isNotEmpty == true) ? e.message!.trim() : 'Authentication failed ($code)',
    };
  }

  @override
  Future<void> close() async {
    await _authSub?.cancel();
    return super.close();
  }
}
