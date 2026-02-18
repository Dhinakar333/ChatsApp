import 'dart:math' as math;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';

import '../bloc/chat_thread/chat_thread_cubit.dart';
import '../bloc/chat_thread/chat_thread_state.dart';

class ChatScreen extends StatefulWidget {
  final String peerUserId;
  final String peerName;
  final bool embedded;
  const ChatScreen({
    required this.peerUserId,
    required this.peerName,
    this.embedded = false,
    super.key,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _inputFocus = FocusNode();
  final FocusNode _keyHandlerFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDesktop) return;
      FocusScope.of(context).requestFocus(_keyHandlerFocus);
      FocusScope.of(context).requestFocus(_inputFocus);
    });
    _scrollCtrl.addListener(() {
      if (!_scrollCtrl.hasClients) return;
      final max = _scrollCtrl.position.maxScrollExtent;
      final current = _scrollCtrl.position.pixels;
      if (current >= max - 200) {
        context.read<ChatThreadCubit>().loadMore();
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    _inputFocus.dispose();
    _keyHandlerFocus.dispose();
    super.dispose();
  }

  bool get _isDesktop {
    return kIsWeb ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;
  }

  @override
  Widget build(BuildContext context) {
    final body = Column(
        children: [
          if (widget.embedded)
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
                        CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          child: Text(
                            widget.peerName.isNotEmpty ? widget.peerName[0].toUpperCase() : '?',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: BlocBuilder<ChatThreadCubit, ChatThreadState>(
                            buildWhen: (p, n) => p.peerTypingUntil != n.peerTypingUntil,
                            builder: (context, state) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.peerName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  if (state.isPeerTyping)
                                    const Text(
                                      'typing…',
                                      style: TextStyle(fontSize: 12, color: Colors.white),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: BlocBuilder<ChatThreadCubit, ChatThreadState>(
              builder: (context, state) {
                if (state.status == ChatThreadStatus.loading || state.status == ChatThreadStatus.initial) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.status == ChatThreadStatus.failure) {
                  return Center(child: Text(state.errorMessage ?? 'Failed to load messages'));
                }
                final cubit = context.read<ChatThreadCubit>();
                final myUid = cubit.myUid;
                final peerUid = cubit.peerUid;
                final visible = state.messages.where((m) => m.deletedFor[myUid] != true).toList(growable: false);
                if (visible.isEmpty) return const Center(child: Text('No messages yet'));

                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  if (!_scrollCtrl.hasClients) return;
                  if (_scrollCtrl.position.pixels <= 40) {
                    await context.read<ChatThreadCubit>().markChatRead();
                  }
                });

                return ListView.builder(
                  controller: _scrollCtrl,
                  reverse: true,
                  itemCount: visible.length + 1,
                  itemBuilder: (context, i) {
                    if (i == visible.length) {
                      if (!state.hasMore) {
                        return const SizedBox(height: 24);
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: state.isLoadingMore
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Pull up to load more', style: TextStyle(fontSize: 12, color: Colors.black54)),
                        ),
                      );
                    }

                    final m = visible[i];
                    final ts = m.createdAt;
                    final time = ts != null ? TimeOfDay.fromDateTime(ts.toDate()).format(context) : '';
                    final isMe = m.senderId == myUid;
                    final isDeleted = m.deletedAt != null;
                    final maxBubbleWidth = math.min(560.0, MediaQuery.of(context).size.width * 0.78);
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: maxBubbleWidth,
                            ),
                            child: GestureDetector(
                              onLongPress: () async {
                                await showModalBottomSheet<void>(
                                  context: context,
                                  builder: (sheetContext) {
                                    final canEdit = isMe && !isDeleted;
                                    return SafeArea(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ListTile(
                                            leading: const Icon(Icons.reply),
                                            title: const Text('Reply'),
                                            onTap: () {
                                              Navigator.pop(sheetContext);
                                              context.read<ChatThreadCubit>().setReplyTo(m);
                                            },
                                          ),
                                          if (!isDeleted)
                                            ListTile(
                                              leading: const Icon(Icons.copy),
                                              title: const Text('Copy'),
                                              onTap: () async {
                                                Navigator.pop(sheetContext);
                                                await Clipboard.setData(ClipboardData(text: m.text));
                                              },
                                            ),
                                          if (canEdit)
                                            ListTile(
                                              leading: const Icon(Icons.edit),
                                              title: const Text('Edit'),
                                              onTap: () {
                                                Navigator.pop(sheetContext);
                                                _ctrl.text = m.text;
                                                _ctrl.selection = TextSelection.fromPosition(TextPosition(offset: _ctrl.text.length));
                                                context.read<ChatThreadCubit>().beginEdit(m);
                                              },
                                            ),
                                          ListTile(
                                            leading: const Icon(Icons.delete_outline),
                                            title: const Text('Delete for me'),
                                            onTap: () async {
                                              Navigator.pop(sheetContext);
                                              await context.read<ChatThreadCubit>().deleteForMe(m.id);
                                            },
                                          ),
                                          if (isMe)
                                            ListTile(
                                              leading: const Icon(Icons.delete),
                                              title: const Text('Delete for everyone'),
                                              onTap: () async {
                                                Navigator.pop(sheetContext);
                                                await context.read<ChatThreadCubit>().deleteForEveryone(m.id);
                                              },
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isMe ? Colors.blue.shade200 : Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (m.replyToTextSnippet != null && m.replyToTextSnippet!.isNotEmpty)
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        margin: const EdgeInsets.only(bottom: 8),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.06),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          m.replyToTextSnippet!,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                                        ),
                                      ),
                                    Text(
                                      isDeleted ? 'Message deleted' : m.text,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,
                                        color: isDeleted ? Colors.black54 : Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(time, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                              if (m.editedAt != null && !isDeleted) ...[
                                const SizedBox(width: 6),
                                const Text('edited', style: TextStyle(fontSize: 10, color: Colors.black54)),
                              ],
                              if (isMe) ...[
                                const SizedBox(width: 6),
                                Icon(
                                  m.readAt.containsKey(peerUid)
                                      ? Icons.done_all
                                      : m.deliveredAt.containsKey(peerUid)
                                          ? Icons.done_all
                                          : Icons.done,
                                  size: 14,
                                  color: m.readAt.containsKey(peerUid)
                                      ? Colors.blue.shade700
                                      : Colors.black54,
                                ),
                              ],
                            ],
                          ),
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BlocBuilder<ChatThreadCubit, ChatThreadState>(
                    buildWhen: (p, n) =>
                        p.replyToMessageId != n.replyToMessageId ||
                        p.editingMessageId != n.editingMessageId ||
                        p.replyToTextSnippet != n.replyToTextSnippet,
                    builder: (context, state) {
                      if (state.editingMessageId == null && state.replyToMessageId == null) {
                        return const SizedBox.shrink();
                      }
                      final label = state.editingMessageId != null ? 'Editing message' : 'Replying';
                      final snippet = state.editingMessageId != null ? _ctrl.text : (state.replyToTextSnippet ?? '');
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Text(
                                    snippet,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                if (state.editingMessageId != null) {
                                  context.read<ChatThreadCubit>().cancelEdit();
                                } else {
                                  context.read<ChatThreadCubit>().clearReplyTo();
                                }
                                _ctrl.clear();
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Focus(
                          focusNode: _keyHandlerFocus,
                          onKeyEvent: (node, event) {
                            if (!_isDesktop) return KeyEventResult.ignored;
                            if (event is! KeyDownEvent) return KeyEventResult.ignored;

                            if (event.logicalKey == LogicalKeyboardKey.escape) {
                              final state = context.read<ChatThreadCubit>().state;
                              if (state.editingMessageId != null) {
                                context.read<ChatThreadCubit>().cancelEdit();
                                _ctrl.clear();
                                return KeyEventResult.handled;
                              }
                              if (state.replyToMessageId != null) {
                                context.read<ChatThreadCubit>().clearReplyTo();
                                return KeyEventResult.handled;
                              }
                              return KeyEventResult.ignored;
                            }

                            if (event.logicalKey == LogicalKeyboardKey.enter ||
                                event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                              if (HardwareKeyboard.instance.isShiftPressed) {
                                return KeyEventResult.ignored;
                              }
                              final text = _ctrl.text.trim();
                              if (text.isEmpty) return KeyEventResult.handled;
                              final cubit = context.read<ChatThreadCubit>();
                              unawaited(
                                cubit.submitInput(text).then((_) {
                                  if (mounted) _ctrl.clear();
                                }),
                              );
                              return KeyEventResult.handled;
                            }

                            return KeyEventResult.ignored;
                          },
                          child: TextField(
                            focusNode: _inputFocus,
                            controller: _ctrl,
                            decoration: InputDecoration(
                                hintText: _isDesktop ? 'Message (Enter to send, Shift+Enter new line)' : 'Type a message',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20)
                                )),
                            minLines: 1,
                            maxLines: 4,
                            onChanged: (v) => context.read<ChatThreadCubit>().onInputChanged(v),
                          ),
                        ),
                      ),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _ctrl,
                        builder: (context, value, _) {
                          final isSending = context.select((ChatThreadCubit c) => c.state.isSending);
                          final editing = context.select((ChatThreadCubit c) => c.state.editingMessageId != null);
                          final canSend = value.text.trim().isNotEmpty && !isSending;
                          return IconButton(
                            icon: isSending
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : Icon(editing ? Icons.check : Icons.send),
                            onPressed: !canSend
                                ? null
                                : () async {
                                    final text = _ctrl.text.trim();
                                    if (text.isEmpty) return;
                                    await context.read<ChatThreadCubit>().submitInput(text);
                                    _ctrl.clear();
                                  },
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          )
        ],
      );

    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(
          backgroundColor: Colors.blue.shade300,
          title: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue.shade100,
                child: Text(
                  widget.peerName.isNotEmpty ? widget.peerName[0].toUpperCase() : '?',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: BlocBuilder<ChatThreadCubit, ChatThreadState>(
                  buildWhen: (p, n) => p.peerTypingUntil != n.peerTypingUntil,
                  builder: (context, state) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.peerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (state.isPeerTyping)
                          const Text(
                            'typing…',
                            style: TextStyle(fontSize: 12, color: Colors.white),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          )),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: body,
        ),
      ),
    );
  }
}
