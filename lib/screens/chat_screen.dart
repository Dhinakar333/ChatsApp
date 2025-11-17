import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;  // ← ADD FOR REST API
import 'dart:convert';  // ← ADD FOR JSON

import '../main.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';

class ChatScreen extends StatefulWidget {
  final String peerUserId;
  final String peerName;
  const ChatScreen({required this.peerUserId, required this.peerName, super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final chatProv = Provider.of<ChatProvider>(context, listen: false);
    final me = auth.user!;
    final senderName = auth.displayName ?? 'User';
    final chatId = chatProv.chatIdForSorted(me.uid, widget.peerUserId);
    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.blue.shade300,
          title: Text(widget.peerName)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: chatProv.messagesStream(chatId),
              builder: (c, snap) {
                if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snap.data!.docs;
                if (docs.isEmpty) return const Center(child: Text('No messages yet'));
                return ListView.builder(
                  reverse: true,
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final m = docs[i].data()! as Map<String, dynamic>;
                    final text = m['text'] ?? '';
                    final sender = m['senderId'] ?? '';
                    final ts = m['timestamp'] as Timestamp?;
                    final time = ts != null ? TimeOfDay.fromDateTime(ts.toDate()).format(context) : '';
                    final isMe = sender == me.uid;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.blue[200] : Colors.grey[400],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(text),
                          ),
                          const SizedBox(height: 4),
                          Text(time, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      decoration: InputDecoration(
                          hintText: 'Type a message',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20)
                          )),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () async {
                      final text = _ctrl.text.trim();
                      if (text.isEmpty) return;

                      final senderName = auth.displayName ?? "User";

                      // 1. Save message to Firestore (triggers real-time sync)
                      await chatProv.sendMessage(chatId, me.uid, text, senderName);

                      // 2. Send push via OneSignal REST API (permanent v5 fix)
                      await _sendOneSignalNotification(senderName, text, chatId, widget.peerUserId);

                      _ctrl.clear();
                    },
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Future<String?> getPlayerIdFromFirestore(String peerId) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(peerId).get();
    return doc.data()?['playerId'];
  }

  Future<void> _sendOneSignalNotification(String senderName, String text, String chatId, String peerId) async {
    try {
      // Get peer's Player ID from dashboard or store it in Firestore
      String? playerId = await getPlayerIdFromFirestore(peerId); // You need this function

      if (playerId == null) {
        print("No player ID for $peerId");
        return;
      }

      final response = await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $oneSignalRestApiKey',
        },
        body: jsonEncode({
          "app_id": oneSignalAppId,
          "include_player_ids": [playerId], // ← USE THIS
          "headings": {"en": senderName},
          "contents": {"en": text.length > 100 ? "${text.substring(0, 97)}..." : text},
          "data": {"chatId": chatId, "senderName": senderName},
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        print("OneSignal success: ${jsonResponse['recipients']} recipients");
      } else {
        print("Error: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("Send failed: $e");
    }
  }
}