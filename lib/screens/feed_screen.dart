import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:veil/export.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final ScrollController _scrollController = ScrollController();
  String _selectedFeedMode = 'World';
  double _appBarOpacity = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(feedProvider.notifier).fetchPosts();
    });
  }

  void _onScroll() {
    final state = ref.read(feedProvider);
    if (!state.isLoadingMore &&
        !state.hasReachedMax &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300) {
      ref.read(feedProvider.notifier).loadMore();
    }
    final offset = _scrollController.position.pixels;
    final newOpacity = (offset / 100).clamp(0.0, 0.9);
    if (_appBarOpacity != newOpacity) {
      setState(() {
        _appBarOpacity = newOpacity;
      });
    }
  }

  String _getFeedType(String tab) {
    switch (tab) {
      case 'World':
        return 'world';
      case 'Circle':
        return 'friends';
      case 'Private':
        return 'private';
      default:
        return 'world';
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(feedProvider);
    final notifier = ref.read(feedProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ---------- ONE APP BAR ----------
            _buildAppBar(),

            // ---------- FEED CONTENT ----------
            Expanded(
              child: feedState.isLoading && feedState.posts.isEmpty
                  ? _buildShimmerFeed()
                  : feedState.errorMessage != null && feedState.posts.isEmpty
                  ? _buildErrorWidget(feedState.errorMessage!)
                  : feedState.posts.isEmpty
                  ? _buildEmptyFeed(_selectedFeedMode.toLowerCase())
                  : RefreshIndicator(
                      onRefresh: () => notifier.fetchPosts(refresh: true),
                      color: Colors.white,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: feedState.hasReachedMax
                            ? feedState.posts.length + 1
                            : feedState.posts.length +
                                  (feedState.isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index >= feedState.posts.length) {
                            if (feedState.hasReachedMax) {
                              return _buildEndMessage();
                            }
                            return _buildLoadingIndicator();
                          }
                          final post = feedState.posts[index];
                          return PostCard(
                            post: post,
                            onShare: () => _handleShare(post),
                            onMore: () => _showMoreOptions(post),
                            onTapProfile: () => _navigateToProfile(post.userId),
                            onTapCard: () => _navigateToPostDetail(post),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------- APP BAR (only once) -------------------
  Widget _buildAppBar() {
    final tabs = ['World', 'Circle', 'Private'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[800]!, width: 0.3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: tabs.map((tab) {
                final isSelected = _selectedFeedMode == tab;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedFeedMode = tab;
                    });
                    ref
                        .read(feedProvider.notifier)
                        .fetchPosts(refresh: true, feedType: _getFeedType(tab));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isSelected ? Colors.white : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                    child: Text(
                      tab,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[400],
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontSize: 15,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          // Circle members icon
          IconButton(
            icon: const Icon(Icons.group, color: Colors.white),
            onPressed: _showCircleMembers,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // ------------------- SHIMMER / LOADING / ERROR / EMPTY -------------------
  Widget _buildShimmerFeed() {
    return ListView.builder(
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          height: 300,
          decoration: BoxDecoration(
            color: Colors.grey[800],
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.grey, size: 60),
          const SizedBox(height: 16),
          Text(
            "An Error Occurred",
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () =>
                ref.read(feedProvider.notifier).fetchPosts(refresh: true),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEndMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.grey, size: 40),
          const SizedBox(height: 8),
          const Text(
            'You\'ve reached the end',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Pull down to refresh',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFeed(String feedType) {
    String title, subtitle, buttonText, buttonRoute;
    IconData icon;
    Color gradientColor1, gradientColor2;

    switch (feedType) {
      case 'world':
        title = 'No posts yet';
        subtitle = 'Be the first to share something with the Veil community.';
        icon = Icons.public;
        gradientColor1 = Colors.blue;
        gradientColor2 = Colors.purple;
        buttonText = 'Create Post';
        buttonRoute = '/create-post';
        break;
      case 'friends': // Circle
        title = 'No circle posts';
        subtitle =
            'Connect with friends and see what they share in your circle.';
        icon = Icons.group;
        gradientColor1 = Colors.purple;
        gradientColor2 = Colors.pink;
        buttonText = 'Find Friends';
        buttonRoute = '/echoes';
        break;
      case 'private':
        title = 'Your private space';
        subtitle =
            'Write something only you can see. Private posts stay between you and your thoughts.';
        icon = Icons.lock;
        gradientColor1 = Colors.grey;
        gradientColor2 = Colors.blueGrey;
        buttonText = 'Write Private Post';
        buttonRoute = '/create-post';
        break;
      default:
        title = 'Nothing here';
        subtitle = 'Start exploring or create your first post.';
        icon = Icons.inbox;
        gradientColor1 = Colors.grey;
        gradientColor2 = Colors.grey;
        buttonText = 'Explore';
        buttonRoute = '/create-post';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [gradientColor1, gradientColor2],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                if (buttonRoute == '/create-post') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CreatePostScreen()),
                  );
                } else if (buttonRoute == '/echoes') {
                  ref.read(mainTabProvider.notifier).state = 2;
                }
              },
              icon: Icon(
                buttonRoute == '/create-post' ? Icons.add : Icons.people,
              ),
              label: Text(buttonText),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------- NAVIGATION -------------------
  void _navigateToProfile(String userId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileScreen(userId: userId, isRoot: false),
      ),
    );
  }

  void _navigateToPostDetail(PostModel post) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
    );
  }

  // ------------------- POST ACTIONS -------------------
  void _handleShare(PostModel post) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📤 Share functionality'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ------------------- MORE OPTIONS -------------------
  void _showMoreOptions(PostModel post) {
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
                      _buildMoreOption(Icons.edit, 'Edit', () {
                        _showEditDialog(context, post);
                      }),
                      _buildMoreOption(Icons.delete, 'Delete', () {
                        ref.read(feedProvider.notifier).deletePost(post.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Post deleted')),
                        );
                      }),
                    ],

                    // ---- OTHERS' POST ----
                    if (!isOwnPost) ...[
                      _buildMoreOption(Icons.report, 'Report', () {
                        _showReportDialog(context, post);
                      }),
                      _buildMoreOption(Icons.visibility_off, 'Hide', () {
                        _confirmHide(post);
                      }),
                      _buildMoreOption(
                        Icons.volume_off,
                        'Mute @${post.username}',
                        () {
                          _confirmMute(post);
                        },
                      ),
                      _buildMoreOption(
                        Icons.block,
                        'Block @${post.username}',
                        () {
                          _confirmBlock(post);
                        },
                      ),
                    ],

                    // ---- COMMON ----
                    if (post.imageUrls.isNotEmpty)
                      _buildMoreOption(Icons.copy, 'Copy link', () {
                        _copyLink(context, post.id);
                      }),
                    if (post.hasDonation)
                      _buildMoreOption(Icons.volunteer_activism, 'Donate', () {
                        Navigator.pop(context);
                        _openUrl(post.donationUrl!);
                      }),
                    if (post.hasShop)
                      _buildMoreOption(Icons.shopping_bag, 'Shop now', () {
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

  Widget _buildMoreOption(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  // ------------------- DIALOGS -------------------
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
                Navigator.pop(context);
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

  void _confirmHide(PostModel post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Hide post?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This post will be removed from your feed. You can\'t undo this.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(feedProvider.notifier).hidePost(post.id);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Post hidden')));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Hide'),
          ),
        ],
      ),
    );
  }

  void _confirmMute(PostModel post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          'Mute @${post.username}?',
          style: const TextStyle(color: Colors.white),
        ),
        content: const Text(
          'You won\'t see posts from this user in your feed.',
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
              await ref.read(feedProvider.notifier).muteUser(post.userId);
              ref.read(feedProvider.notifier).fetchPosts(refresh: true);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Muted @${post.username}')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Mute'),
          ),
        ],
      ),
    );
  }

  void _confirmBlock(PostModel post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text(
          'Block @${post.username}?',
          style: const TextStyle(color: Colors.white),
        ),
        content: const Text(
          'You won\'t see posts from this user. They won\'t know you blocked them.',
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
              await ref.read(feedProvider.notifier).blockUser(post.userId);
              ref.read(feedProvider.notifier).fetchPosts(refresh: true);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Blocked @${post.username}')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Block'),
          ),
        ],
      ),
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

  void _showCircleMembers() async {
    try {
      final members = await ref.read(postServiceProvider).getCircleMembers();
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
                child: Column(
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
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Circle Members',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Divider(color: Colors.grey),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: members.length,
                        itemBuilder: (context, index) {
                          final user = members[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: user['avatar_url'] != null
                                  ? NetworkImage(user['avatar_url'])
                                  : null,
                              child: user['avatar_url'] == null
                                  ? Text(
                                      (user['display_name'] ?? '?')[0]
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    )
                                  : null,
                            ),
                            title: Text(
                              user['display_name'] ??
                                  user['username'] ??
                                  'Unknown',
                              style: const TextStyle(color: Colors.white),
                            ),
                            subtitle: Text(
                              '@${user['username'] ?? ''}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              _navigateToProfile(user['id']);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load circle members: $e')),
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
