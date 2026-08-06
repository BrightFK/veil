import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:veil/export.dart';

import 'chat_screen.dart';

class EchoesScreen extends ConsumerStatefulWidget {
  const EchoesScreen({super.key});

  @override
  ConsumerState<EchoesScreen> createState() => _EchoesScreenState();
}

class _EchoesScreenState extends ConsumerState<EchoesScreen> {
  List<Map<String, dynamic>> _suggestedUsers = [];
  bool _loadingSuggestions = true;

  List<Map<String, dynamic>> _pendingRequests = [];
  bool _loadingRequests = true;

  // Map to store circle status for each user: {userId: 'status'}
  Map<String, String> _circleStatusMap = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([_loadPendingRequests(), _loadSuggestedUsers()]);
  }

  Future<void> _loadPendingRequests() async {
    setState(() => _loadingRequests = true);
    try {
      final requests = await ref
          .read(postServiceProvider)
          .getPendingCircleRequests();
      setState(() {
        _pendingRequests = requests;
        _loadingRequests = false;
      });
    } catch (e) {
      setState(() => _loadingRequests = false);
    }
  }

  Future<void> _loadSuggestedUsers() async {
    setState(() => _loadingSuggestions = true);
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser!.id;

      // Fetch all profiles except current user
      final response = await Supabase.instance.client
          .from('profiles')
          .select('id, username, display_name, avatar_url')
          .neq('id', currentUserId)
          .limit(20);

      List<Map<String, dynamic>> users = List<Map<String, dynamic>>.from(
        response,
      );

      // Fetch circle connections to build status map
      final connections = await Supabase.instance.client
          .from('circle_connections')
          .select('user_id, circle_user_id, status')
          .or('user_id.eq.$currentUserId,circle_user_id.eq.$currentUserId');

      Map<String, String> statusMap = {};
      for (final conn in connections) {
        final uid = conn['user_id'] as String;
        final cid = conn['circle_user_id'] as String;
        final other = uid == currentUserId ? cid : uid;
        final status = conn['status'] as String;
        // Only set if not already accepted or pending (prefer accepted)
        if (status == 'accepted') {
          statusMap[other] = 'accepted';
        } else if (status == 'pending' && !statusMap.containsKey(other)) {
          statusMap[other] = 'pending';
        }
      }
      _circleStatusMap = statusMap;

      setState(() {
        _suggestedUsers = users;
        _loadingSuggestions = false;
      });
    } catch (e) {
      setState(() => _loadingSuggestions = false);
    }
  }

  // Send circle request
  Future<void> _sendCircleRequest(String userId) async {
    try {
      await ref.read(postServiceProvider).sendCircleRequest(userId);
      // Update local status
      setState(() {
        _circleStatusMap[userId] = 'pending';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Circle request sent')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  // Accept/Reject request
  Future<void> _handleRequestAction(String requestId, String action) async {
    try {
      if (action == 'accept') {
        await ref.read(postServiceProvider).acceptCircleRequest(requestId);
      } else {
        await ref.read(postServiceProvider).rejectCircleRequest(requestId);
      }
      await _loadData(); // refresh everything
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(action == 'accept' ? 'Accepted!' : 'Rejected')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final convState = ref.watch(conversationsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // App Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Text(
                    'Echoes',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.edit_note, color: Colors.white),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NewChatScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // ---- Circle Requests Section ----
            if (_pendingRequests.isNotEmpty) ...[_buildRequestsSection()],

            // ---- Suggested Connections ----
            _buildSuggestedSection(),

            // ---- Conversations ----
            Expanded(
              child: convState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : convState.error != null
                  ? Center(
                      child: Text(
                        convState.error!,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  : convState.conversations.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            color: Colors.grey,
                            size: 60,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'No chats yet',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: convState.conversations.length,
                      itemBuilder: (context, index) {
                        final chat = convState.conversations[index];
                        return _buildChatTile(
                          context,
                          chat['conversation_id'] as String,
                          chat['other_username'] as String? ?? 'Unknown',
                          chat['other_display_name'] as String? ?? '',
                          chat['other_avatar_url'] as String?,
                          chat['last_message'] as String? ?? '',
                          chat['last_message_time'] as String?,
                          chat['unread_count'] as int? ?? 0,
                          chat['other_user_id'] as String,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Requests Section ----------
  Widget _buildRequestsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Circle Requests',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        SizedBox(
          height: 80,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: _pendingRequests.map((req) {
              final sender = req['profiles'] as Map<String, dynamic>;
              final name =
                  sender['username'] ?? sender['display_name'] ?? 'Unknown';
              final avatarUrl = sender['avatar_url'] as String?;
              final requestId = req['id'] as String;

              return Container(
                width: 250,
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: avatarUrl != null
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: avatarUrl == null
                          ? Text(name[0].toUpperCase())
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const Text(
                            'wants to join',
                            style: TextStyle(color: Colors.grey, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.check,
                            color: Colors.green,
                            size: 18,
                          ),
                          onPressed: () =>
                              _handleRequestAction(requestId, 'accept'),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.red,
                            size: 18,
                          ),
                          onPressed: () =>
                              _handleRequestAction(requestId, 'reject'),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ---------- Suggested Section ----------
  Widget _buildSuggestedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Suggested Connections',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        _loadingSuggestions
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(color: Colors.white54),
                ),
              )
            : _suggestedUsers.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No users found',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            : SizedBox(
                height: 100,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: _suggestedUsers.map((user) {
                    final displayName = user['username'] ?? 'Unknown';
                    final username = user['display_name'] ?? '';
                    final avatarUrl = user['avatar_url'] as String?;
                    final userId = user['id'] as String;

                    final status = _circleStatusMap[userId] ?? 'none';

                    return Container(
                      width: 210,
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProfileScreen(
                                    userId: userId,
                                    isRoot: false,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [Colors.purple, Colors.blue],
                                ),
                              ),
                              child: avatarUrl != null && avatarUrl.isNotEmpty
                                  ? ClipOval(
                                      child: Image.network(
                                        avatarUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Center(
                                          child: Text(
                                            displayName[0].toUpperCase(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                  : Center(
                                      child: Text(
                                        displayName[0].toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  '@$username',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // ---- Action Button ----
                          if (status == 'none')
                            _actionButton(
                              'Add',
                              Colors.blue,
                              () => _sendCircleRequest(userId),
                            )
                          else if (status == 'pending')
                            _actionButton('Pending', Colors.orange, null)
                          else if (status == 'accepted')
                            _actionButton('DM', Colors.green, () {
                              _startChat(userId);
                            }),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Future<void> _startChat(String userId) async {
    try {
      final chatService = ref.read(chatServiceProvider);
      final conversationId = await chatService.createConversation(userId);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ChatScreen(conversationId: conversationId, otherUserId: userId),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error starting chat: $e')));
    }
  }

  // ---------- Chat Tile (unchanged) ----------
  Widget _buildChatTile(
    BuildContext context,
    String conversationId,
    String displayName,
    String username,
    String? avatarUrl,
    String lastMessage,
    String? lastMessageTime,
    int unreadCount,
    String otherUserId,
  ) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [Colors.purple, Colors.blue]),
          shape: BoxShape.circle,
        ),
        child: avatarUrl != null && avatarUrl.isNotEmpty
            ? ClipOval(
                child: Image.network(
                  avatarUrl,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Center(
                    child: Text(
                      displayName.isNotEmpty
                          ? displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              )
            : Center(
                child: Text(
                  displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
      ),
      title: Text(
        displayName,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        lastMessage.isNotEmpty ? lastMessage : 'Start chatting...',
        style: TextStyle(
          color: unreadCount > 0 ? Colors.white : Colors.grey[500],
          fontSize: 13,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            lastMessageTime != null
                ? _formatTime(DateTime.parse(lastMessageTime))
                : '',
            style: const TextStyle(color: Colors.grey, fontSize: 10),
          ),
          if (unreadCount > 0)
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.purple, Colors.blue],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              conversationId: conversationId,
              otherUserId: otherUserId,
            ),
          ),
        ).then((_) {
          ref.read(conversationsProvider.notifier).loadConversations();
        });
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${diff.inDays ~/ 7}w ago';
  }
}
