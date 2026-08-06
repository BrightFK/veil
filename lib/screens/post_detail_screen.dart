import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:veil/export.dart';

class PostDetailScreen extends ConsumerStatefulWidget {
  final PostModel post;
  const PostDetailScreen({super.key, required this.post});

  @override
  ConsumerState<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends ConsumerState<PostDetailScreen> {
  late PostModel _post;
  bool _isVoting = false;
  int? _votingOptionIndex;
  List<Map<String, dynamic>> _comments = [];
  bool _isLoadingComments = true;
  String? _commentError;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _loadComments();
    _incrementViewCount();
  }

  Future<void> _loadComments() async {
    setState(() {
      _isLoadingComments = true;
      _commentError = null;
    });
    try {
      final postService = ref.read(postServiceProvider);
      final comments = await postService.getCommentsForPost(_post.id);
      setState(() {
        _comments = comments;
        _isLoadingComments = false;
      });
    } catch (e) {
      setState(() {
        _commentError = e.toString();
        _isLoadingComments = false;
      });
    }
  }

  Future<void> _incrementViewCount() async {
    try {
      final postService = ref.read(postServiceProvider);
      await postService.incrementViewCount(_post.id);
    } catch (e) {
      // ignore – view count increment is non‑critical
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz, color: Colors.white),
            onPressed: () => _showMoreOptions(context, _post),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              if (_post.content != null && _post.content!.isNotEmpty)
                _buildContent(),
              if (_post.hashtags.isNotEmpty) _buildHashtags(),
              if (_post.location != null) _buildLocation(),
              const SizedBox(height: 12),
              if (_post.imageUrls.isNotEmpty) _buildImages(),
              if (_post.videoUrl != null) _buildVideo(),
              if (_post.audioUrl != null) _buildAudio(),
              if (_post.poll != null) _buildPoll(),
              if (_post.linkPreview != null) _buildLinkPreview(),
              if (_post.taggedUsers.isNotEmpty) _buildTaggedUsers(),
              if (_post.reactions.isNotEmpty) _buildReactions(),
              const SizedBox(height: 16),
              _buildEngagement(),
              const Divider(color: Colors.grey),
              _buildActionButtons(),
              const Divider(color: Colors.grey),
              if (_post.communityNote != null) _buildCommunityNote(),
              if (_post.factCheckLabel != null) _buildFactCheck(),
              if (_post.musicAttribution != null) _buildMusicAttribution(),
              if (_post.copyrightNotice != null) _buildCopyright(),
              const SizedBox(height: 24),
              // ---- Comments Section ----
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Comments (${_post.commentCount})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _showCommentDialog,
                    icon: const Icon(
                      Icons.add_comment,
                      color: Colors.purple,
                      size: 18,
                    ),
                    label: const Text(
                      'Add',
                      style: TextStyle(color: Colors.purple),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _isLoadingComments
                  ? const Center(child: CircularProgressIndicator())
                  : _commentError != null
                  ? Center(
                      child: Text(
                        'Failed to load comments',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : _comments.isEmpty
                  ? const Center(
                      child: Text(
                        'No comments yet. Be the first!',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : Column(
                      children: _comments.map((c) => _buildComment(c)).toList(),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- Header ----------
  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ProfileScreen(userId: _post.userId, isRoot: false),
              ),
            );
          },
          child: _buildAvatar(),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ProfileScreen(userId: _post.userId, isRoot: false),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    _post.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_post.isVerified) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.verified, color: Colors.blue, size: 16),
                  ],
                ],
              ),
              Text(
                '@${_post.username} · ${_getTimeAgo(_post.createdAt)}',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
        const Spacer(),
        if (_post.audience != 'Public')
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _post.audience,
              style: const TextStyle(color: Colors.grey, fontSize: 10),
            ),
          ),
      ],
    );
  }

  // ---------- Images (with Supabase detection) ----------
  Widget _buildImages() {
    final images = _post.imageUrls;
    if (images.isEmpty) return const SizedBox.shrink();
    int crossAxisCount = images.length == 1
        ? 1
        : images.length == 2
        ? 2
        : 3;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
          childAspectRatio: 1,
        ),
        itemCount: images.length > 9 ? 9 : images.length,
        itemBuilder: (context, index) {
          if (index == 8 && images.length > 9) {
            return _buildRemainingCount(images.length - 9);
          }
          return _buildImageTile(images[index]);
        },
      ),
    );
  }

  Widget _buildImageTile(String imageUrl) {
    if (imageUrl.contains('supabase.co') || imageUrl.contains('supabase')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FullscreenImage(imageUrl: imageUrl),
              ),
            );
          },
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => _buildGradientPlaceholder(imageUrl),
            loadingBuilder: (_, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return _buildGradientPlaceholder(imageUrl);
            },
          ),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: _buildGradientPlaceholder(imageUrl),
    );
  }

  // ---------- Comment ----------
  Widget _buildComment(Map<String, dynamic> commentData) {
    final user = commentData['profiles'] ?? {};
    final userId = commentData['user_id'] as String? ?? user['id'] as String?;
    final username = user['username'] ?? 'Unknown';
    final displayName = user['display_name'] ?? username;
    final avatarUrl = user['avatar_url'] as String?;
    final content = commentData['content'] ?? '';
    final time = _getTimeAgo(DateTime.parse(commentData['created_at']));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ----- Avatar (tappable) -----
          GestureDetector(
            onTap: () {
              if (userId != null && userId.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ProfileScreen(userId: userId, isRoot: false),
                  ),
                );
              }
            },
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [Colors.purple, Colors.blue]),
                image: avatarUrl != null && avatarUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(avatarUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: (avatarUrl == null || avatarUrl.isEmpty)
                  ? Center(
                      child: Text(
                        username[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          // ----- Comment content -----
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Display name (tappable)
                GestureDetector(
                  onTap: () {
                    if (userId != null && userId.isNotEmpty) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ProfileScreen(userId: userId, isRoot: false),
                        ),
                      );
                    }
                  },
                  child: Text(
                    displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(content, style: const TextStyle(color: Colors.white)),
                Text(
                  time,
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Add Comment Dialog ----------
  void _showCommentDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Add Comment', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Write a comment...',
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: Colors.grey[800],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(context);
                try {
                  final postService = ref.read(postServiceProvider);
                  await postService.addComment(_post.id, text);
                  // Reload comments
                  _loadComments();
                  // Update local post count
                  setState(() {
                    _post = _post.copyWith(
                      commentCount: _post.commentCount + 1,
                    );
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('💬 Comment added!')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Post'),
          ),
        ],
      ),
    );
  }

  // ---------- Action Buttons (No Repost) ----------
  Widget _buildActionButtons() {
    final notifier = ref.read(feedProvider.notifier);
    return Row(
      children: [
        _buildAnimatedLikeButton(notifier),
        IconButton(
          onPressed: _showCommentDialog,
          icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
        ),
        IconButton(
          onPressed: () {
            Share.share(
              '${_post.content}\n\nCheck out this post on Veil!',
              subject: 'Veil Post',
            );
          },
          icon: const Icon(Icons.share_outlined, color: Colors.white),
        ),
        const Spacer(),
        IconButton(
          onPressed: () {
            notifier.toggleBookmark(_post.id);
            setState(() {
              _post = _post.copyWith(
                isBookmarkedByUser: !_post.isBookmarkedByUser,
                saveCount: _post.isBookmarkedByUser
                    ? _post.saveCount - 1
                    : _post.saveCount + 1,
              );
            });
          },
          icon: Icon(
            _post.isBookmarkedByUser ? Icons.bookmark : Icons.bookmark_border,
            color: _post.isBookmarkedByUser ? Colors.blue : Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildAvatar() {
    final avatarUrl = _post.avatarUrl;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return ClipOval(
        child: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FullscreenImage(imageUrl: avatarUrl),
              ),
            );
          },
          child: Image.network(
            avatarUrl,
            width: 44,
            height: 44,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildFallbackAvatar(),
            loadingBuilder: (_, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return _buildFallbackAvatar();
            },
          ),
        ),
      );
    }
    return _buildFallbackAvatar();
  }

  Widget _buildFallbackAvatar() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getAvatarColor(_post.username),
            _getAvatarColor(_post.username).withOpacity(0.5),
          ],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          _post.username[0].toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildGradientPlaceholder(String image) {
    final colors = [
      [Colors.purple, Colors.pink],
      [Colors.blue, Colors.cyan],
      [Colors.orange, Colors.red],
      [Colors.green, Colors.teal],
      [Colors.indigo, Colors.purple],
    ];
    final index = image.hashCode.abs() % colors.length;
    final gradientColors = colors[index];

    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [gradientColors[0], gradientColors[1]],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_outlined,
                color: Colors.white.withOpacity(0.7),
                size: 32,
              ),
              const SizedBox(height: 4),
              Text(
                '📸',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRemainingCount(int count) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          '+$count',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Color _getAvatarColor(String username) {
    final colors = [
      Colors.purple,
      Colors.blue,
      Colors.pink,
      Colors.orange,
      Colors.green,
      Colors.teal,
      Colors.indigo,
      Colors.red,
    ];
    final index = username.hashCode.abs() % colors.length;
    return colors[index];
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inDays > 7) return '${diff.inDays ~/ 7}w ago';
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  Widget _buildAnimatedLikeButton(feedNotifier) {
    return StatefulBuilder(
      builder: (context, setState) {
        return GestureDetector(
          onTap: () {
            setState(() {
              _post = _post.copyWith(
                isLikedByUser: !_post.isLikedByUser,
                likeCount: _post.isLikedByUser
                    ? _post.likeCount - 1
                    : _post.likeCount + 1,
              );
              feedNotifier.toggleLike(widget.post.id);
            });
          },
          child: AnimatedScale(
            duration: const Duration(milliseconds: 150),
            scale: _post.isLikedByUser ? 1.2 : 1.0,
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: Icon(
                    _post.isLikedByUser
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: _post.isLikedByUser ? Colors.red : Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 4),
                TweenAnimationBuilder<int>(
                  tween: IntTween(
                    begin: _post.likeCount - (_post.isLikedByUser ? 1 : 0),
                    end: _post.likeCount,
                  ),
                  duration: const Duration(milliseconds: 300),
                  builder: (context, value, child) {
                    return Text(
                      value.toString(),
                      style: TextStyle(
                        color: _post.isLikedByUser ? Colors.red : Colors.grey,
                        fontSize: 14,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent() {
    return Text(
      _post.content!,
      style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.6),
    );
  }

  Widget _buildHashtags() {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 6,
        children: _post.hashtags.map((tag) {
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ExploreScreen(initialQuery: tag),
                ),
              );
            },
            child: Text(
              '#$tag',
              style: TextStyle(
                color: Colors.blue[400],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLocation() {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: Colors.grey, size: 14),
          const SizedBox(width: 4),
          Text(
            _post.location!,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ==============================================
  // IMAGES, VIDEO, AUDIO, POLL, LINK PREVIEW
  // ==============================================
  Widget _buildVideo() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 250,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.grey[800]!, Colors.grey[900]!],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '▶️ Video',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap to play',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAudio() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.music_note, color: Colors.white),
                SizedBox(width: 8),
                Text(
                  '🎵 Audio Track',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            '0:00',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: LinearProgressIndicator(
                                value: 0.4,
                                backgroundColor: Colors.grey[600],
                                color: Colors.blue[400],
                              ),
                            ),
                          ),
                          const Text(
                            '3:42',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _post.musicAttribution ?? 'Unknown Track',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow, color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkPreview() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[700]!),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.blue[400],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.link, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _post.linkPreview!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    'Open link →',
                    style: TextStyle(color: Colors.blue, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaggedUsers() {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 4,
        children: _post.taggedUsers.map((user) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '@$user',
              style: TextStyle(color: Colors.blue[400], fontSize: 12),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReactions() {
    return Wrap(
      spacing: 12,
      children: _post.reactions.entries.map((e) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(e.key, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 4),
              Text('${e.value}', style: const TextStyle(color: Colors.white)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEngagement() {
    return Row(
      children: [
        Text(
          '${_post.likeCount} likes',
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(width: 16),
        Text(
          '${_post.commentCount} comments',
          style: const TextStyle(color: Colors.grey),
        ),
        const SizedBox(width: 16),
        Text(
          '${_post.repostCount} reposts',
          style: const TextStyle(color: Colors.grey),
        ),
        const Spacer(),
        Text(
          '${_post.viewCount} views',
          style: const TextStyle(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildCommunityNote() {
    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Colors.orange, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '📝 ${_post.communityNote}',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFactCheck() {
    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.fact_check, color: Colors.red, size: 16),
          const SizedBox(width: 8),
          Text(
            '⚠️ ${_post.factCheckLabel}',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildMusicAttribution() {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          const Icon(Icons.music_note, color: Colors.grey, size: 14),
          const SizedBox(width: 4),
          Text(
            '🎵 ${_post.musicAttribution}',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyright() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        '© ${_post.copyrightNotice}',
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
    );
  }

  void _showMoreOptions(BuildContext context, PostModel post) {
    final currentUserId = ref.read(authProvider).user?.id;
    final isOwnPost = currentUserId == post.userId;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          expand: false,
          builder: (_, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[700],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ---- OWN POST ----
                    if (isOwnPost) ...[
                      _buildOption(Icons.edit, 'Edit', () {
                        _showEditDialog(context, post);
                      }),
                      _buildOption(
                        post.isPinned ? Icons.push_pin : Icons.push_pin,
                        post.isPinned ? 'Unpin' : 'Pin',
                        () async {
                          Navigator.pop(context);
                          await ref
                              .read(feedProvider.notifier)
                              .togglePin(post.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                post.isPinned ? 'Unpinned' : 'Pinned',
                              ),
                            ),
                          );
                        },
                      ),
                      _buildOption(Icons.delete, 'Delete', () {
                        ref.read(feedProvider.notifier).deletePost(post.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Post deleted')),
                        );
                        Navigator.pop(context); // close detail
                      }),
                      _buildOption(
                        post.isArchived ? Icons.unarchive : Icons.archive,
                        post.isArchived ? 'Unarchive' : 'Archive',
                        () async {
                          Navigator.pop(context);
                          await ref
                              .read(feedProvider.notifier)
                              .toggleArchive(post.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                post.isArchived ? 'Unarchived' : 'Archived',
                              ),
                            ),
                          );
                        },
                      ),
                    ],

                    // ---- OTHERS' POST ----
                    if (!isOwnPost) ...[
                      _buildOption(Icons.report, 'Report', () {
                        Navigator.pop(context);
                        _showReportDialog(context, post);
                      }),
                      _buildOption(Icons.visibility_off, 'Hide', () {
                        Navigator.pop(context);
                        ref.read(feedProvider.notifier).hidePost(post.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Post hidden')),
                        );
                        Navigator.pop(context);
                      }),
                      _buildOption(
                        Icons.volume_off,
                        'Mute @${post.username}',
                        () async {
                          Navigator.pop(context);
                          await ref
                              .read(feedProvider.notifier)
                              .muteUser(post.userId);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Muted @${post.username}')),
                          );
                          ref
                              .read(feedProvider.notifier)
                              .fetchPosts(refresh: true);
                        },
                      ),
                      _buildOption(
                        Icons.block,
                        'Block @${post.username}',
                        () async {
                          Navigator.pop(context);
                          await ref
                              .read(feedProvider.notifier)
                              .blockUser(post.userId);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Blocked @${post.username}'),
                            ),
                          );
                          ref
                              .read(feedProvider.notifier)
                              .fetchPosts(refresh: true);
                        },
                      ),
                    ],

                    // ---- COMMON ----
                    if (post.imageUrls.isNotEmpty)
                      _buildOption(Icons.download, 'Download media', () {
                        Navigator.pop(context);
                        _downloadImage(post.imageUrls.first);
                      }),
                    _buildOption(Icons.copy, 'Copy link', () {
                      Navigator.pop(context);
                      _copyLink(context, post.id);
                    }),
                    if (post.hasDonation)
                      _buildOption(Icons.volunteer_activism, 'Donate', () {
                        Navigator.pop(context);
                        _openUrl(post.donationUrl!);
                      }),
                    if (post.hasShop)
                      _buildOption(Icons.shopping_bag, 'Shop now', () {
                        Navigator.pop(context);
                        _openUrl(post.shopUrl!);
                      }),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOption(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  Widget _buildPoll() {
    final poll = _post.poll!;
    final userVote = _post.userPollVoteIndex;
    final totalVotes = poll.options.fold<int>(0, (sum, o) => sum + o.votes);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              poll.question,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            ...poll.options.asMap().entries.map((entry) {
              final idx = entry.key;
              final option = entry.value;
              final percent = totalVotes > 0
                  ? (option.votes / totalVotes * 100)
                  : 0.0;
              final isVoted = userVote == idx;
              final bool isLoading = _votingOptionIndex == idx;
              return GestureDetector(
                onTap: (_isVoting || isLoading)
                    ? null
                    : () async {
                        setState(() {
                          _isVoting = true;
                          _votingOptionIndex = idx;
                        });
                        try {
                          final postService = ref.read(postServiceProvider);
                          if (isVoted) {
                            await postService.votePoll(
                              _post.id,
                              idx,
                              unvote: true,
                            );
                          } else {
                            await postService.votePoll(_post.id, idx);
                          }
                          // Fetch updated post with fresh vote data
                          final updatedPost = await postService.getPost(
                            _post.id,
                          );
                          setState(() {
                            _post = updatedPost;
                          });
                          // Also update feed provider (if open)
                          ref
                              .read(feedProvider.notifier)
                              .updatePost(updatedPost);
                        } catch (e) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        } finally {
                          setState(() {
                            _isVoting = false;
                            _votingOptionIndex = null;
                          });
                        }
                      },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  height: 32,
                  decoration: BoxDecoration(
                    color: isVoted
                        ? Colors.blue.withOpacity(0.3)
                        : Colors.grey[700],
                    borderRadius: BorderRadius.circular(8),
                    border: isVoted
                        ? Border.all(color: Colors.blue, width: 2)
                        : null,
                  ),
                  child: Stack(
                    children: [
                      FractionallySizedBox(
                        widthFactor: percent / 100,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue[400]!, Colors.purple[400]!],
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              option.text,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                            Row(
                              children: [
                                if (isLoading)
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                else
                                  Text(
                                    '${percent.round()}%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 4),
            Text(
              '$totalVotes votes · ${_getTimeAgo(poll.endsAt)} remaining',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, PostModel post) {
    final controller = TextEditingController(text: post.content);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Edit Post', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Update your post...',
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: Colors.grey[800],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final content = controller.text.trim();
              if (content.isNotEmpty) {
                await ref
                    .read(feedProvider.notifier)
                    .editPost(post.id, content);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Post updated!')));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context, PostModel post) {
    final reasons = ['Spam', 'Harassment', 'Inappropriate content', 'Other'];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Report Post', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: reasons.map((r) {
            return ListTile(
              title: Text(r, style: const TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                await ref
                    .read(feedProvider.notifier)
                    .reportPost(post.id, reason: r);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Report submitted')),
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _downloadImage(String url) {
    // Use image_gallery_saver or just show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Downloading... (feature coming soon)')),
    );
  }

  void _copyLink(BuildContext context, String postId) {
    Clipboard.setData(ClipboardData(text: 'https://veil.app/post/$postId'));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Link copied to clipboard!')));
  }

  void _openUrl(String url) async {
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open URL')));
    }
  }
}
