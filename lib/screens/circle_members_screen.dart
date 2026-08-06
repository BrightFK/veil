import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:veil/export.dart';

class CircleMembersScreen extends ConsumerStatefulWidget {
  const CircleMembersScreen({super.key});

  @override
  ConsumerState<CircleMembersScreen> createState() =>
      _CircleMembersScreenState();
}

class _CircleMembersScreenState extends ConsumerState<CircleMembersScreen> {
  List<Map<String, dynamic>> _members = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _loading = true);
    try {
      final members = await ref.read(postServiceProvider).getCircleMembers();
      setState(() {
        _members = members;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
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
          'Circle Members',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _members.isEmpty
          ? const Center(
              child: Text(
                'No circle members yet',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: _members.length,
              itemBuilder: (context, index) {
                final member = _members[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: member['avatar_url'] != null
                        ? NetworkImage(member['avatar_url'])
                        : null,
                    child: member['avatar_url'] == null
                        ? Text((member['display_name'] ?? 'U')[0].toUpperCase())
                        : null,
                  ),
                  title: Text(
                    member['display_name'] ?? 'Unknown',
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    '@${member['username']}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ProfileScreen(userId: member['id'], isRoot: false),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
