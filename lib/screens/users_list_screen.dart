import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'chat_screen.dart';

class UsersListScreen extends StatelessWidget {
  static const routeName = '/users';
  const UsersListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final me = auth.user;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue.shade300,
        title:  Row(
          children: [
            CircleAvatar(
              backgroundImage: AssetImage("assets/chatsapplogo.png"),
              radius: 23,
            ),
            SizedBox(width: 10,),
            Text('ChatsApp',style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold
            ),),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => auth.logout(),
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users')
            .orderBy('name').snapshots(),
        builder: (c, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs.where((d) => d.id != me!.uid).toList();
          if (docs.isEmpty) {
            return const Center(child: Text('No other users found.'));
          }
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              final name = d['name'] ?? 'No name';
              return Container(
                margin: EdgeInsets.all(1),
                decoration: BoxDecoration(
                  border: BoxBorder.fromLTRB(
                    left: BorderSide.none,
                    right: BorderSide.none,
                    bottom: BorderSide(color: Colors.grey,width: 1)
                  )
                ),
                child: ListTile(
                  title: Text(name),
                  subtitle: Text(d['email'] ?? ''),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          peerUserId: docs[i].id,
                          peerName: name,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
