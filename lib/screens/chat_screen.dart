// lib/screens/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
                      await chatProv.sendMessage(chatId, me.uid, text);
                      _ctrl.clear();
                    },
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
