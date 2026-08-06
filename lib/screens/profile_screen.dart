import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:veil/export.dart';

import 'chat_screen.dart';
import 'muted_users_screen.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final String userId;
  final bool isRoot;

  const ProfileScreen({super.key, required this.userId, this.isRoot = false});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<PostModel> _userPosts = [];
  List<PostModel> _mediaPosts = [];
  List<PostModel> _bookmarkedPosts = [];
  bool _isLoading = true;
  List<Map<String, dynamic>> _circleMembers = [];
  String? _error;
  int _lastRefreshCount = 0;
  bool _isCurrentUser = false;
  String? _circleStatus; // null, 'pending', 'accepted'
  String? _circleRequestId;
  bool _isCircleRequestSent = false;

  // Profile data
  String _username = '';
  String _displayName = '';
  String? _avatarUrl;
  String _bio = '';

  final List<Tab> _tabs = const [
    Tab(icon: Icon(Icons.grid_on), text: 'Posts'),
    Tab(icon: Icon(Icons.photo_library), text: 'Media'),
    Tab(icon: Icon(Icons.bookmark), text: 'Bookmarks'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfileData();
    });
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authUser = ref.read(authProvider).user;
      _isCurrentUser = authUser?.id == widget.userId;

      final postService = ref.read(postServiceProvider);

      // Ensure profile exists
      await postService.ensureProfileExists(widget.userId);
      if (_isCurrentUser) {
        _circleMembers = await postService.getCircleMembers();
      } else {
        _circleMembers = [];
      }

      final userPosts = await postService.getUserPosts(
        widget.userId,
        includePrivate: _isCurrentUser,
      );

      // Fetch profile
      final profile = await postService.getProfile(widget.userId);
      _username = profile['username'] ?? 'Unknown';
      _displayName = profile['display_name'] ?? _username;
      _avatarUrl = profile['avatar_url'];
      _bio = profile['bio'] ?? '';

      // Fetch circle status
      final circleData = await postService.getCircleRequestStatus(
        widget.userId,
      );
      if (circleData != null) {
        _circleStatus = circleData['status'] as String;
        _circleRequestId = circleData['id'] as String?;
        _isCircleRequestSent = circleData['isSent'] as bool;
      } else {
        _circleStatus = null;
        _circleRequestId = null;
        _isCircleRequestSent = false;
      }

      // Fetch user posts
      _userPosts = userPosts;

      _mediaPosts = userPosts
          .where((p) => p.imageUrls.isNotEmpty || p.videoUrl != null)
          .toList();

      if (_isCurrentUser) {
        final bookmarked = await postService.getBookmarkedPosts();
        _bookmarkedPosts = bookmarked;
      } else {
        _bookmarkedPosts = [];
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(refreshProfileProvider, (prev, next) {
      if (prev != next) {
        _loadProfileData();
      }
    });

    final currentRefresh = ref.watch(refreshProfileProvider);
    if (currentRefresh != _lastRefreshCount) {
      _lastRefreshCount = currentRefresh;
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: widget.isRoot
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  ref.read(mainTabProvider.notifier).state = 0;
                },
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
        centerTitle: true,
        actions: [
          if (!_isCurrentUser)
            IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: _startChat,
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz, color: Colors.white),
            color: Colors.grey[900],
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditProfileScreen(userId: widget.userId),
                    ),
                  );
                  break;
                case 'share':
                  Share.share(
                    'Check out @$_username on Veil!',
                    subject: 'Veil Profile',
                  );
                  break;
                case 'hidden':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HiddenPostsScreen(),
                    ),
                  );
                  break;
                case 'muted':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MutedUsersScreen()),
                  );
                  break;
                case 'blocked':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BlockedUsersScreen(),
                    ),
                  );
                  break;
                case 'settings':
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Settings coming soon')),
                  );
                  break;
                case 'logout':
                  _showLogoutDialog();
                  break;
              }
            },
            itemBuilder: (context) {
              final List<PopupMenuEntry<String>> items = [];

              if (_isCurrentUser) {
                items.addAll([
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, color: Colors.white, size: 20),
                        SizedBox(width: 12),
                        Text(
                          'Edit Profile',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'share',
                    child: Row(
                      children: [
                        Icon(Icons.share, color: Colors.white, size: 20),
                        SizedBox(width: 12),
                        Text(
                          'Share Profile',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'hidden',
                    child: Row(
                      children: [
                        Icon(Icons.hide_source, color: Colors.white, size: 20),
                        SizedBox(width: 12),
                        Text(
                          'Hidden Posts',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'muted',
                    child: Row(
                      children: [
                        Icon(Icons.volume_off, color: Colors.white, size: 20),
                        SizedBox(width: 12),
                        Text(
                          'Muted Users',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'blocked',
                    child: Row(
                      children: [
                        Icon(Icons.block, color: Colors.white, size: 20),
                        SizedBox(width: 12),
                        Text(
                          'Blocked Users',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'settings',
                    child: Row(
                      children: [
                        Icon(Icons.settings, color: Colors.white, size: 20),
                        SizedBox(width: 12),
                        Text('Settings', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem<String>(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, color: Colors.red, size: 20),
                        SizedBox(width: 12),
                        Text('Logout', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ]);
              } else {
                items.add(
                  const PopupMenuItem<String>(
                    value: 'share',
                    child: Row(
                      children: [
                        Icon(Icons.share, color: Colors.white, size: 20),
                        SizedBox(width: 12),
                        Text(
                          'Share Profile',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return items;
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.grey, size: 60),
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadProfileData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Profile header
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      _buildAvatar(),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  _username,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '@$_displayName',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                            // ----- BIO -----
                            if (_bio.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  _bio,
                                  style: TextStyle(
                                    color: Colors.grey[400],
                                    fontSize: 14,
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _buildStat('Posts', _userPosts.length),
                                const SizedBox(width: 20),
                                _buildStat('Media', _mediaPosts.length),
                                const SizedBox(width: 20),
                                _buildStat(
                                  'Bookmarks',
                                  _bookmarkedPosts.length,
                                ),
                                SizedBox(width: 5),
                                _buildStat('Circle', _circleMembers.length),
                              ],
                            ),
                            // Circle button (only for other users)
                            if (!_isCurrentUser) ...[
                              const SizedBox(height: 12),
                              _buildCircleButton(),
                              if (_isCurrentUser) ...[
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => CircleMembersScreen(),
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.group,
                                    color: Colors.purple,
                                  ),
                                  label: Text(
                                    'Circle Members (${_circleMembers.length})',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Tab bar
                TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  tabs: _tabs,
                ),
                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPostGrid(_userPosts),
                      _buildPostGrid(_mediaPosts),
                      _buildPostGrid(_bookmarkedPosts),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _startChat() async {
    try {
      final chatService = ref.read(chatServiceProvider);
      final conversationId = await chatService.createConversation(
        widget.userId,
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            conversationId: conversationId,
            otherUserId: widget.userId,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error starting chat: $e')));
    }
  }

  Widget _buildAvatar() {
    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FullscreenImage(imageUrl: _avatarUrl!),
            ),
          );
        },
        child: ClipOval(
          child: Image.network(
            _avatarUrl!,
            width: 80,
            height: 80,
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
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getAvatarColor(_username),
            _getAvatarColor(_username).withOpacity(0.5),
          ],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          _username[0].toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildStat(String label, int count) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          count.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildPostGrid(List<PostModel> posts) {
    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, color: Colors.grey[700], size: 60),
            const SizedBox(height: 12),
            Text('Nothing here yet', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _getAvatarColor(post.username),
                  _getAvatarColor(post.username).withOpacity(0.3),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: post.imageUrls.isNotEmpty
                  ? const Icon(Icons.image, color: Colors.white70, size: 30)
                  : post.videoUrl != null
                  ? const Icon(Icons.videocam, color: Colors.white70, size: 30)
                  : Text(
                      post.content?.substring(0, 1) ?? '',
                      style: const TextStyle(color: Colors.white, fontSize: 30),
                    ),
            ),
          ),
        );
      },
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

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Logout?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authProvider.notifier).signOut();
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ---------- Circle Button ----------
  Widget _buildCircleButton() {
    if (_circleStatus == 'accepted') {
      return _circleButton('In Circle', Colors.green, () {});
    } else if (_circleStatus == 'pending') {
      if (_isCircleRequestSent) {
        return _circleButton('Requested', Colors.orange, () {});
      } else {
        // Received a request – show Accept/Reject
        return Row(
          children: [
            Expanded(
              child: _circleButton('Accept', Colors.green, () async {
                await ref
                    .read(postServiceProvider)
                    .acceptCircleRequest(_circleRequestId!);
                setState(() {
                  _circleStatus = 'accepted';
                });
              }),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _circleButton('Reject', Colors.red, () async {
                await ref
                    .read(postServiceProvider)
                    .rejectCircleRequest(_circleRequestId!);
                setState(() {
                  _circleStatus = null;
                });
              }),
            ),
          ],
        );
      }
    } else {
      return _circleButton('Add to Circle', Colors.blue, () async {
        await ref.read(postServiceProvider).sendCircleRequest(widget.userId);
        setState(() {
          _circleStatus = 'pending';
          _isCircleRequestSent = true;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Circle request sent!')));
      });
    }
  }

  Widget _circleButton(String label, Color color, VoidCallback onTap) {
    return Container(
      width: double.infinity,
      height: 36,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.purple, Colors.blue]),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
