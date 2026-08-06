import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:veil/export.dart';

import 'chat_screen.dart'; // your exports (ChatService, ChatScreen, etc.)

class NewChatScreen extends ConsumerStatefulWidget {
  const NewChatScreen({super.key});

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final currentUserId = supabase.auth.currentUser!.id;

      // Fetch all profiles except the current user
      final response = await supabase
          .from('profiles')
          .select('id, username, display_name, avatar_url')
          .neq('id', currentUserId)
          .order('display_name');

      setState(() {
        _users = List<Map<String, dynamic>>.from(response);
        _filteredUsers = _users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterUsers(String query) {
    final lower = query.toLowerCase().trim();
    setState(() {
      if (lower.isEmpty) {
        _filteredUsers = _users;
      } else {
        _filteredUsers = _users.where((user) {
          final name = (user['username'] ?? '').toString().toLowerCase();
          final username = (user['display_name'] ?? '')
              .toString()
              .toLowerCase();
          return name.contains(lower) || username.contains(lower);
        }).toList();
      }
    });
  }

  Future<void> _startChat(Map<String, dynamic> user) async {
    final otherUserId = user['id'] as String;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final chatService = ref.read(chatServiceProvider);
      final conversationId = await chatService.createConversation(otherUserId);

      if (!mounted) return;
      Navigator.pop(context); // close loading

      // Go to ChatScreen and remove NewChatScreen from stack
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: conversationId,
            otherUserId: otherUserId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // close loading
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to start chat: $e')));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'New Chat',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search users...',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: _filterUsers,
            ),
          ),

          // User list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  )
                : _filteredUsers.isEmpty
                ? const Center(
                    child: Text(
                      'No users found',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = _filteredUsers[index];
                      final displayName =
                          user['username'] ?? user['display_name'] ?? 'Unknown';
                      final username = user['display_name'] ?? '';
                      final avatarUrl = user['avatar_url'] as String?;

                      return ListTile(
                        onTap: () => _startChat(user),
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.purple, Colors.blue],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: avatarUrl != null && avatarUrl.isNotEmpty
                              ? ClipOval(
                                  child: Image.network(
                                    avatarUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _initial(displayName),
                                  ),
                                )
                              : _initial(displayName),
                        ),
                        title: Text(
                          displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '@$username',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                        trailing: const Icon(
                          Icons.chat_bubble_outline,
                          color: Colors.grey,
                          size: 20,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _initial(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }
}
