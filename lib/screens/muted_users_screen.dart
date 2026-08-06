import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:veil/export.dart';

class MutedUsersScreen extends ConsumerStatefulWidget {
  const MutedUsersScreen({super.key});

  @override
  ConsumerState<MutedUsersScreen> createState() => _MutedUsersScreenState();
}

class _MutedUsersScreenState extends ConsumerState<MutedUsersScreen> {
  List<Map<String, dynamic>> _mutedUsers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMuted();
  }

  Future<void> _loadMuted() async {
    setState(() => _loading = true);
    try {
      final users = await ref.read(postServiceProvider).getMutedUsers();
      setState(() {
        _mutedUsers = users;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _unmute(String userId) async {
    try {
      await ref.read(postServiceProvider).unmuteUser(userId);
      setState(() {
        _mutedUsers.removeWhere((u) => u['muted_user_id'] == userId);
      });
      // Refresh feed to potentially show their posts again
      ref.read(feedProvider.notifier).fetchPosts(refresh: true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unmuted user')));
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
          'Muted Users',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _mutedUsers.isEmpty
          ? const Center(
              child: Text(
                'No muted users',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: _mutedUsers.length,
              itemBuilder: (context, index) {
                final data = _mutedUsers[index];
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
                    onPressed: () => _unmute(profile['id']),
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
