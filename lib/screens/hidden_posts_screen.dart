import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:veil/export.dart';

class HiddenPostsScreen extends ConsumerStatefulWidget {
  const HiddenPostsScreen({super.key});

  @override
  ConsumerState<HiddenPostsScreen> createState() => _HiddenPostsScreenState();
}

class _HiddenPostsScreenState extends ConsumerState<HiddenPostsScreen> {
  List<Map<String, dynamic>> _hiddenPosts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHidden();
  }

  Future<void> _loadHidden() async {
    setState(() => _loading = true);
    try {
      final posts = await ref.read(postServiceProvider).getHiddenPosts();
      setState(() {
        _hiddenPosts = posts;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _unhide(String postId) async {
    try {
      await ref.read(postServiceProvider).unhidePost(postId);
      setState(() {
        _hiddenPosts.removeWhere((p) => p['posts']['id'] == postId);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Post unhidden')));
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
          'Hidden Posts',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _hiddenPosts.isEmpty
          ? const Center(
              child: Text(
                'No hidden posts',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: _hiddenPosts.length,
              itemBuilder: (context, index) {
                final data = _hiddenPosts[index];
                final post = data['posts'] as Map<String, dynamic>;
                final content = post['content'] ?? 'Untitled';
                final createdAt = DateTime.parse(post['created_at']);
                return ListTile(
                  leading: const Icon(Icons.hide_source, color: Colors.grey),
                  title: Text(
                    content.length > 60
                        ? '${content.substring(0, 60)}...'
                        : content,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    'Hidden ${_formatTime(createdAt)}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.visibility, color: Colors.blue),
                    onPressed: () => _unhide(post['id']),
                  ),
                  onTap: () {
                    // Navigate to post detail if needed
                  },
                );
              },
            ),
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
