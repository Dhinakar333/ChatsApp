import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';

import 'firebase_options.dart';
import 'bloc/auth/auth_bloc.dart';
import 'bloc/auth/auth_event.dart';
import 'bloc/auth/auth_state.dart';
import 'bloc/chat_thread/chat_thread_cubit.dart';
import 'bloc/chats/chats_cubit.dart';
import 'bloc/users/users_cubit.dart';
import 'data/repositories/firebase_auth_repository.dart';
import 'data/repositories/firebase_chat_repository.dart';
import 'domain/repositories/auth_repository.dart';
import 'domain/repositories/chat_repository.dart';
import 'screens/login_screen.dart';
import 'screens/users_list_screen.dart';
import 'screens/chat_screen.dart';
import 'widgets/presence_listener.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel _messagesChannel = AndroidNotificationChannel(
  'chatsapp_messages',
  'Messages',
  description: 'Message notifications',
  importance: Importance.high,
);

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await _initLocalNotifications();
  runApp(const MyApp());
  unawaited(_initFirebaseMessagingHandlers());
}

Future<void> _initLocalNotifications() async {
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  const ios = DarwinInitializationSettings();
  const settings = InitializationSettings(android: android, iOS: ios);
  await _localNotifications.initialize(settings);

  final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.createNotificationChannel(_messagesChannel);
  await androidPlugin?.requestNotificationsPermission();
}

Future<void> _initFirebaseMessagingHandlers() async {
  final messaging = FirebaseMessaging.instance;
  await messaging.setAutoInitEnabled(true);
  await messaging.requestPermission(alert: true, badge: true, sound: true);
  await messaging.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);

  FirebaseMessaging.onMessage.listen((message) async {
    final notification = message.notification;
    final title = notification?.title;
    final body = notification?.body;
    if (title == null && body == null) return;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final androidDetails = AndroidNotificationDetails(
        _messagesChannel.id,
        _messagesChannel.name,
        channelDescription: _messagesChannel.description,
        importance: Importance.high,
        priority: Priority.high,
      );
      final details = NotificationDetails(android: androidDetails);

      await _localNotifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title ?? 'ChatsApp',
        body ?? '',
        details,
      );
    }
  });

  FirebaseMessaging.onMessageOpenedApp.listen(_handleRemoteMessageNavigation);

  final initialMessage = await messaging.getInitialMessage();
  if (initialMessage != null) {
    _handleRemoteMessageNavigation(initialMessage);
  }
}

void _handleRemoteMessageNavigation(RemoteMessage message) {
  final chatId = message.data['chatId'] as String?;
  final senderName = (message.data['senderName'] as String?) ?? 'User';
  if (chatId == null) return;

  WidgetsBinding.instance.addPostFrameCallback((_) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final ids = chatId.split('_');
    final peerId = ids.firstWhere((id) => id != currentUserId, orElse: () => ids[0]);

    final chatRepo = context.read<ChatRepository>();
    final authRepo = context.read<AuthRepository>();
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    Future(() async {
      final myName = await authRepo.getDisplayName(currentUserId);
      navigator.push(
        MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (_) => ChatThreadCubit(
              chatRepository: chatRepo,
              chatId: chatId,
              myUid: currentUserId,
              myName: myName,
            )..start(),
            child: ChatScreen(
              peerUserId: peerId,
              peerName: senderName,
            ),
          ),
        ),
      );
    });
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthRepository>(create: (_) => FirebaseAuthRepository()),
        RepositoryProvider<ChatRepository>(create: (_) => FirebaseChatRepository()),
      ],
      child: BlocProvider(
        create: (context) => AuthBloc(authRepository: context.read<AuthRepository>())
          ..add(const AuthSubscriptionRequested()),
        child: MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'ChatsApp',
          theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
          home: const PresenceListener(child: Root()),
        ),
      ),
    );
  }
}

class Root extends StatelessWidget {
  const Root({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state.status == AuthStatus.loading || state.status == AuthStatus.unknown) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (state.status == AuthStatus.unauthenticated) {
          return const LoginScreen();
        }
        final uid = state.uid;
        if (uid == null) {
          return const LoginScreen();
        }
        return MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (context) => ChatsCubit(
                chatRepository: context.read<ChatRepository>(),
                myUid: uid,
              )..start(),
            ),
            BlocProvider(
              create: (context) => UsersCubit(
                chatRepository: context.read<ChatRepository>(),
              )..start(),
            ),
          ],
          child: const UsersListScreen(),
        );
      },
    );
  }
}
