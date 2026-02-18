import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_state.dart';
import '../domain/repositories/auth_repository.dart';

class PresenceListener extends StatefulWidget {
  final Widget child;
  const PresenceListener({required this.child, super.key});

  @override
  State<PresenceListener> createState() => _PresenceListenerState();
}

class _PresenceListenerState extends State<PresenceListener> with WidgetsBindingObserver {
  String? _lastUid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final uid = _lastUid;
    if (uid != null) {
      context.read<AuthRepository>().setPresence(uid: uid, isOnline: false);
    }
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.watch<AuthBloc>().state;
    final uid = state.status == AuthStatus.authenticated ? state.uid : null;
    if (_lastUid != uid) {
      final prev = _lastUid;
      _lastUid = uid;
      if (prev != null) {
        context.read<AuthRepository>().setPresence(uid: prev, isOnline: false);
      }
      if (uid != null) {
        context.read<AuthRepository>().setPresence(uid: uid, isOnline: true);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final uid = _lastUid;
    if (uid == null) return;
    final repo = context.read<AuthRepository>();
    switch (state) {
      case AppLifecycleState.resumed:
        repo.setPresence(uid: uid, isOnline: true);
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        repo.setPresence(uid: uid, isOnline: false);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

