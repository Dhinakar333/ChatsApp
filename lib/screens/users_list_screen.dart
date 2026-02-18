import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_event.dart';
import '../bloc/chats/chats_cubit.dart';
import '../bloc/chats/chats_state.dart';
import '../bloc/chat_thread/chat_thread_cubit.dart';
import '../bloc/users/users_cubit.dart';
import '../bloc/users/users_state.dart';
import '../domain/repositories/chat_repository.dart';
import 'chat_screen.dart';

class _FocusSearchIntent extends Intent {
  const _FocusSearchIntent();
}

class _ClearSearchIntent extends Intent {
  const _ClearSearchIntent();
}

class _SwitchTabIntent extends Intent {
  final int index;
  const _SwitchTabIntent(this.index);
}

class UsersListScreen extends StatefulWidget {
  static const routeName = '/users';
  const UsersListScreen({super.key});

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _chatsSearchCtrl = TextEditingController();
  final TextEditingController _usersSearchCtrl = TextEditingController();
  final FocusNode _chatsSearchFocus = FocusNode();
  final FocusNode _usersSearchFocus = FocusNode();
  String _chatsQuery = '';
  String _usersQuery = '';
  String? _selectedChatId;
  String? _selectedPeerId;
  String? _selectedPeerName;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _chatsSearchCtrl.addListener(() {
      final v = _chatsSearchCtrl.text.trim();
      if (v != _chatsQuery) setState(() => _chatsQuery = v);
    });
    _usersSearchCtrl.addListener(() {
      final v = _usersSearchCtrl.text.trim();
      if (v != _usersQuery) setState(() => _usersQuery = v);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _chatsSearchCtrl.dispose();
    _usersSearchCtrl.dispose();
    _chatsSearchFocus.dispose();
    _usersSearchFocus.dispose();
    super.dispose();
  }

  String _formatTimestamp(BuildContext context, Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    if (isToday) return TimeOfDay.fromDateTime(dt).format(context);
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final myUid = authState.uid ?? '';
    final myName = authState.displayName ?? 'User';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;
        final isDesktop = kIsWeb ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux;
        final compact = isDesktop && isWide;
        final leftPaneWidth = constraints.maxWidth >= 1200 ? 420.0 : 360.0;

        final tabViews = <Widget>[
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: TextField(
                  controller: _chatsSearchCtrl,
                  focusNode: _chatsSearchFocus,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: isDesktop ? 'Search chats (Ctrl+K)' : 'Search chats',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              Expanded(
                child: BlocBuilder<ChatsCubit, ChatsState>(
                  builder: (context, state) {
                    if (state.status == ChatsStatus.loading || state.status == ChatsStatus.initial) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (state.status == ChatsStatus.failure) {
                      return Center(child: Text(state.errorMessage ?? 'Failed to load chats'));
                    }
                    final q = _chatsQuery.toLowerCase();
                    final chats = q.isEmpty
                        ? state.chats
                        : state.chats.where((c) {
                            return c.peerName.toLowerCase().contains(q) ||
                                c.peerEmail.toLowerCase().contains(q) ||
                                c.lastMessage.toLowerCase().contains(q);
                          }).toList(growable: false);

                    if (chats.isEmpty) {
                      return const Center(child: Text('No chats yet. Start one from Users.'));
                    }

                    return ListView.builder(
                      itemCount: chats.length,
                      itemBuilder: (context, i) {
                        final chat = chats[i];
                        return ListTile(
                          selected: isWide && _selectedChatId == chat.chatId,
                          dense: compact,
                          visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
                          contentPadding: compact ? const EdgeInsets.symmetric(horizontal: 12, vertical: 0) : null,
                          hoverColor: Colors.blue.withValues(alpha: 0.06),
                          mouseCursor: SystemMouseCursors.click,
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            child: Text(
                              chat.peerName.isNotEmpty ? chat.peerName[0].toUpperCase() : '?',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(chat.peerName, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            chat.lastMessage.isEmpty ? chat.peerEmail : chat.lastMessage,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _formatTimestamp(context, chat.lastMessageAt),
                                style: const TextStyle(fontSize: 12, color: Colors.black54),
                              ),
                              const SizedBox(height: 6),
                              if (chat.unreadCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade700,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    chat.unreadCount > 99 ? '99+' : chat.unreadCount.toString(),
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                ),
                            ],
                          ),
                          onTap: () async {
                            await context.read<ChatsCubit>().markChatRead(chat.chatId);
                            if (!context.mounted) return;
                            final chatRepo = context.read<ChatRepository>();
                            if (isWide) {
                              setState(() {
                                _selectedChatId = chat.chatId;
                                _selectedPeerId = chat.peerId;
                                _selectedPeerName = chat.peerName;
                              });
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BlocProvider(
                                    create: (_) => ChatThreadCubit(
                                      chatRepository: chatRepo,
                                      chatId: chat.chatId,
                                      myUid: myUid,
                                      myName: myName,
                                    )..start(),
                                    child: ChatScreen(peerUserId: chat.peerId, peerName: chat.peerName),
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: TextField(
                  controller: _usersSearchCtrl,
                  focusNode: _usersSearchFocus,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: isDesktop ? 'Search users (Ctrl+K)' : 'Search users',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              Expanded(
                child: BlocBuilder<UsersCubit, UsersState>(
                  builder: (context, state) {
                    if (state.status == UsersStatus.loading || state.status == UsersStatus.initial) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (state.status == UsersStatus.failure) {
                      return Center(child: Text(state.errorMessage ?? 'Failed to load users'));
                    }
                    final q = _usersQuery.toLowerCase();
                    final users = state.users
                        .where((u) => u.uid != myUid)
                        .where((u) {
                          if (q.isEmpty) return true;
                          return u.name.toLowerCase().contains(q) || u.email.toLowerCase().contains(q);
                        })
                        .toList(growable: false);

                    if (users.isEmpty) {
                      return const Center(child: Text('No users found.'));
                    }

                    return ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (context, i) {
                        final user = users[i];
                        return ListTile(
                          dense: compact,
                          visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
                          contentPadding: compact ? const EdgeInsets.symmetric(horizontal: 12, vertical: 0) : null,
                          hoverColor: Colors.blue.withValues(alpha: 0.06),
                          mouseCursor: SystemMouseCursors.click,
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            child: Text(
                              user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(user.name),
                          subtitle: Text(user.email),
                          onTap: () {
                            final chatRepo = context.read<ChatRepository>();
                            final chatId = chatRepo.chatIdForSorted(myUid, user.uid);
                            if (isWide) {
                              setState(() {
                                _selectedChatId = chatId;
                                _selectedPeerId = user.uid;
                                _selectedPeerName = user.name;
                              });
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BlocProvider(
                                    create: (_) => ChatThreadCubit(
                                      chatRepository: chatRepo,
                                      chatId: chatId,
                                      myUid: myUid,
                                      myName: myName,
                                    )..start(),
                                    child: ChatScreen(peerUserId: user.uid, peerName: user.name),
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ];

        final rightPane = _selectedChatId == null || _selectedPeerId == null || _selectedPeerName == null
            ? Container(
                color: Colors.blueGrey.shade50,
                child: const Center(child: Text('Select a chat to start messaging')),
              )
            : BlocProvider(
                key: ValueKey<String>(_selectedChatId!),
                create: (context) => ChatThreadCubit(
                  chatRepository: context.read<ChatRepository>(),
                  chatId: _selectedChatId!,
                  myUid: myUid,
                  myName: myName,
                )..start(),
                child: ChatScreen(
                  peerUserId: _selectedPeerId!,
                  peerName: _selectedPeerName!,
                  embedded: true,
                ),
              );

        return Shortcuts(
          shortcuts: <LogicalKeySet, Intent>{
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyK): const _FocusSearchIntent(),
            LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyK): const _FocusSearchIntent(),
            LogicalKeySet(LogicalKeyboardKey.escape): const _ClearSearchIntent(),
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit1): const _SwitchTabIntent(0),
            LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit2): const _SwitchTabIntent(1),
            LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.digit1): const _SwitchTabIntent(0),
            LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.digit2): const _SwitchTabIntent(1),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              _FocusSearchIntent: CallbackAction<_FocusSearchIntent>(
                onInvoke: (intent) {
                  if (!isDesktop) return null;
                  if (_tabController.index == 0) {
                    FocusScope.of(context).requestFocus(_chatsSearchFocus);
                  } else {
                    FocusScope.of(context).requestFocus(_usersSearchFocus);
                  }
                  return null;
                },
              ),
              _ClearSearchIntent: CallbackAction<_ClearSearchIntent>(
                onInvoke: (intent) {
                  if (!isDesktop) return null;
                  if (_tabController.index == 0) {
                    _chatsSearchCtrl.clear();
                  } else {
                    _usersSearchCtrl.clear();
                  }
                  return null;
                },
              ),
              _SwitchTabIntent: CallbackAction<_SwitchTabIntent>(
                onInvoke: (intent) {
                  if (!isDesktop) return null;
                  if (intent.index < 0 || intent.index > 1) return null;
                  _tabController.animateTo(intent.index);
                  return null;
                },
              ),
            },
            child: Focus(
              autofocus: true,
              child: Scaffold(
                backgroundColor: isWide ? Colors.blueGrey.shade100 : null,
                appBar: isWide
                    ? null
                    : AppBar(
                        backgroundColor: Colors.blue.shade300,
                        title: Row(
                          children: const [
                            CircleAvatar(
                              backgroundImage: AssetImage("assets/chatsapplogo.png"),
                              radius: 18,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'ChatsApp',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        actions: [
                          IconButton(
                            tooltip: isDesktop ? 'Search (Ctrl+K)' : null,
                            icon: const Icon(Icons.search),
                            onPressed: () {
                              if (_tabController.index == 0) {
                                FocusScope.of(context).requestFocus(_chatsSearchFocus);
                              } else {
                                FocusScope.of(context).requestFocus(_usersSearchFocus);
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.logout),
                            onPressed: () => context.read<AuthBloc>().add(const AuthLogoutRequested()),
                          )
                        ],
                        bottom: TabBar(
                          controller: _tabController,
                          tabs: const [
                            Tab(text: 'Chats'),
                            Tab(text: 'Users'),
                          ],
                        ),
                      ),
                body: myUid.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : isWide
                        ? Builder(
                            builder: (context) {
                              final viewportHeight = constraints.maxHeight.isFinite
                                  ? constraints.maxHeight
                                  : MediaQuery.sizeOf(context).height;
                              final frameHeight = (viewportHeight - 32.0).clamp(0.0, double.infinity).toDouble();

                              final leftPane = Column(
                                children: [
                                  Material(
                                    color: Colors.blue.shade300,
                                    child: SafeArea(
                                      bottom: false,
                                      child: SizedBox(
                                        height: 56,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          child: Row(
                                            children: [
                                              const CircleAvatar(
                                                backgroundImage: AssetImage("assets/chatsapplogo.png"),
                                                radius: 18,
                                              ),
                                              const SizedBox(width: 10),
                                              const Expanded(
                                                child: Text(
                                                  'ChatsApp',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                              IconButton(
                                                tooltip: isDesktop ? 'Search (Ctrl+K)' : null,
                                                icon: const Icon(Icons.search, color: Colors.white),
                                                onPressed: () {
                                                  if (_tabController.index == 0) {
                                                    FocusScope.of(context).requestFocus(_chatsSearchFocus);
                                                  } else {
                                                    FocusScope.of(context).requestFocus(_usersSearchFocus);
                                                  }
                                                },
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.logout, color: Colors.white),
                                                onPressed: () => context.read<AuthBloc>().add(const AuthLogoutRequested()),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Material(
                                    color: Colors.white,
                                    child: TabBar(
                                      controller: _tabController,
                                      labelColor: Colors.blue.shade800,
                                      tabs: const [
                                        Tab(text: 'Chats'),
                                        Tab(text: 'Users'),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: TabBarView(
                                      controller: _tabController,
                                      children: tabViews,
                                    ),
                                  ),
                                ],
                              );

                              final frame = Row(
                                children: [
                                  SizedBox(width: leftPaneWidth, child: leftPane),
                                  const VerticalDivider(width: 1),
                                  Expanded(child: rightPane),
                                ],
                              );

                              return Container(
                                color: Colors.blueGrey.shade100,
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 1400),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Material(
                                        color: Colors.white,
                                        elevation: 2,
                                        borderRadius: BorderRadius.circular(12),
                                        clipBehavior: Clip.antiAlias,
                                        child: SizedBox(height: frameHeight, child: frame),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          )
                        : TabBarView(
                            controller: _tabController,
                            children: tabViews,
                          ),
              ),
            ),
          ),
        );
      },
    );
  }
}
