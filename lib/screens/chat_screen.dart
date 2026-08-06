import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:veil/export.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String otherUserId;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserId,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  Map<String, dynamic>? _otherUser;
  bool _loadingUser = true;

  String getDisplayName(Map<String, dynamic>? user) {
    if (user == null) return 'User';

    final displayName = user['username']?.toString().trim();
    final username = user['display_name']?.toString().trim();

    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    if (username != null && username.isNotEmpty) {
      return '@$username';
    }

    return 'User';
  }

  @override
  void initState() {
    super.initState();
    _loadOtherUser();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollToBottom(force: true),
    );
  }

  Future<void> _loadOtherUser() async {
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('id, username, display_name, avatar_url')
          .eq('id', widget.otherUserId)
          .single();

      if (mounted) {
        setState(() {
          _otherUser = response;
          _loadingUser = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingUser = false);
    }
  }

  void _scrollToBottom({bool force = false}) {
    if (!_scrollController.hasClients) return;

    final max = _scrollController.position.maxScrollExtent;
    if (force || _scrollController.offset > max - 120) {
      _scrollController.animateTo(
        max,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messagesState = ref.watch(messagesProvider(widget.conversationId));
    final notifier = ref.read(messagesProvider(widget.conversationId).notifier);

    // Auto scroll when new messages arrive
    ref.listen(messagesProvider(widget.conversationId), (prev, next) {
      if (next.messages.length > (prev?.messages.length ?? 0)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom(force: true);
        });
      }
    });

    final avatarUrl = _otherUser?['avatar_url'] as String?;
    final displayName = getDisplayName(_otherUser);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B0B0B),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: _loadingUser
            ? const Text('Chat', style: TextStyle(color: Colors.white))
            : GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(
                        userId: widget.otherUserId,
                        isRoot: false,
                      ),
                    ),
                  );
                },
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFF9B59B6), Color(0xFF3498DB)],
                        ),
                      ),
                      child: avatarUrl != null && avatarUrl.isNotEmpty
                          ? ClipOval(
                              child: Image.network(
                                avatarUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _buildInitial(displayName),
                              ),
                            )
                          : _buildInitial(displayName),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_otherUser?['display_name'] != null)
                            Text(
                              '@${_otherUser!['display_name']}',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: messagesState.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white54),
                  )
                : messagesState.error != null
                ? Center(
                    child: Text(
                      messagesState.error!,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  )
                : messagesState.messages.isEmpty
                ? const Center(
                    child: Text(
                      'Say hello 👋',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    itemCount: messagesState.messages.length,
                    itemBuilder: (context, index) {
                      final msg = messagesState.messages[index];
                      final isMe =
                          msg['sender_id'] == ref.read(authProvider).user?.id;

                      final showTime =
                          index == 0 ||
                          _shouldShowTime(
                            messagesState.messages[index - 1]['created_at'],
                            msg['created_at'],
                          );

                      return Column(
                        children: [
                          if (showTime)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                _formatFullTime(
                                  DateTime.parse(msg['created_at']),
                                ),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          _buildBubble(
                            content: msg['content'] ?? '',
                            isMe: isMe,
                            time: DateTime.parse(msg['created_at']),
                          ),
                        ],
                      );
                    },
                  ),
          ),

          // Input bar
          _buildInputBar(notifier),
        ],
      ),
    );
  }

  Widget _buildBubble({
    required String content,
    required bool isMe,
    required DateTime time,
  }) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: isMe
                ? const LinearGradient(
                    colors: [Color(0xFF9B59B6), Color(0xFF3498DB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isMe ? null : const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMe ? 18 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                content,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatTime(time),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar(MessagesNotifier notifier) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.05)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  maxLines: 5,
                  minLines: 1,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Message...',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  onSubmitted: (value) => _send(notifier),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () => _send(notifier),
              child: Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF9B59B6), Color(0xFF3498DB)],
                  ),
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _send(MessagesNotifier notifier) {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    notifier.sendMessage(text);
    _controller.clear();
    _focusNode.requestFocus();
  }

  Widget _buildInitial(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }

  bool _shouldShowTime(String prev, String current) {
    final prevTime = DateTime.parse(prev);
    final currTime = DateTime.parse(current);
    return currTime.difference(prevTime).inMinutes > 8;
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatFullTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(time.year, time.month, time.day);

    if (messageDay == today) {
      return 'Today ${_formatTime(time)}';
    } else if (messageDay == today.subtract(const Duration(days: 1))) {
      return 'Yesterday ${_formatTime(time)}';
    } else {
      return '${time.day}/${time.month}/${time.year} ${_formatTime(time)}';
    }
  }
}
