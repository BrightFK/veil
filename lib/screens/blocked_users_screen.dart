import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:veil/export.dart';

class BlockedUsersScreen extends ConsumerStatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  ConsumerState<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends ConsumerState<BlockedUsersScreen> {
  List<Map<String, dynamic>> _blockedUsers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBlocked();
  }

  Future<void> _loadBlocked() async {
    setState(() => _loading = true);
    try {
      final users = await ref.read(postServiceProvider).getBlockedUsers();
      setState(() {
        _blockedUsers = users;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _unBlock(String userId) async {
    try {
      await ref.read(postServiceProvider).unblockUser(userId);
      setState(() {
        _blockedUsers.removeWhere((u) => u['blocked_user_id'] == userId);
      });
      // Refresh feed to potentially show their posts again
      ref.read(feedProvider.notifier).fetchPosts(refresh: true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unblock user')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Blocked Users',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _blockedUsers.isEmpty
          ? const Center(
              child: Text(
                'No Blocked Users',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: _blockedUsers.length,
              itemBuilder: (context, index) {
                final data = _blockedUsers[index];
                final profile = data['profiles'] as Map<String, dynamic>;
                final name =
                    profile['display_name'] ?? profile['username'] ?? 'Unknown';
                final username = profile['username'] ?? '';
                final avatarUrl = profile['avatar_url'] as String?;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: avatarUrl != null
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: avatarUrl == null
                        ? Text(name[0].toUpperCase())
                        : null,
                  ),
                  title: Text(
                    name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    '@$username',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.volume_up, color: Colors.blue),
                    onPressed: () => _unBlock(profile['id']),
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ProfileScreen(userId: profile['id'], isRoot: false),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
