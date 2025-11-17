import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'screens/login_screen.dart';
import 'screens/users_list_screen.dart';
import 'screens/chat_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// REPLACE WITH YOUR REAL VALUES FROM ONESIGNAL DASHBOARD
const String oneSignalAppId = "37eef40d-7708-489a-b9ba-bbddcbffb297";  // App ID
const String oneSignalRestApiKey = "os_v2_app_g7xpidlxbbejvon2xpo4x75ss45e4ip6d6euz2vya3kl5l2lbvbelsvwwhpawhcjnzjtrouqwj6u3esndnmyigpwibbuaayy7jrodhy";  // REST API Key (for sending)

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // OneSignal Initialization (for receiving)
  OneSignal.initialize(oneSignalAppId);
  OneSignal.Notifications.requestPermission(true);

  // Handle notification tap (all states: foreground, background, terminated)
  OneSignal.Notifications.addClickListener((event) {
    final data = event.notification.additionalData;
    if (data != null) {
      final String? chatId = data["chatId"] as String?;
      final String senderName = (data["senderName"] as String?) ?? "User";
      if (chatId != null) {
        _openChatFromNotification(chatId, senderName);
      }
    }
  });
  OneSignal.Notifications.addForegroundWillDisplayListener((event) {
    // Show as local notification
    // Use flutter_local_notifications to display event.notification
    print("Foreground notification: ${event.notification.body}");
    event.notification.display();  // Auto-show
  });

  runApp(const MyApp());
}

void _openChatFromNotification(String chatId, String senderName) async {
  // Delay to ensure context is ready
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = auth.user?.uid;
    if (currentUserId == null) return;

    final ids = chatId.split('_');
    final peerId = ids.firstWhere((id) => id != currentUserId, orElse: () => ids[0]);

    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          peerUserId: peerId,
          peerName: senderName,
        ),
      ),
    );
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'ChatsApp',
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
        home: const Root(),
        routes: {
          UsersListScreen.routeName: (_) => const UsersListScreen(),
        },
      ),
    );
  }
}

class Root extends StatefulWidget {
  const Root({super.key});

  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> {
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    if (auth.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    } else if (auth.user == null) {
      return const LoginScreen();
    } else {
      return const UsersListScreen();
    }
  }
}