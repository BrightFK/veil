import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:veil/export.dart';

class ExploreScreen extends ConsumerStatefulWidget {
  final String initialQuery;

  const ExploreScreen({super.key, this.initialQuery = ''});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery.isNotEmpty) {
      _searchController.text = widget.initialQuery;
      // ✅ Delay search until after the first frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performSearch(widget.initialQuery);
      });
    }
  }

  void _performSearch(String query) {
    if (query.trim().isEmpty) {
      setState(() => _isSearching = false);
      ref.read(searchProvider.notifier).clear();
      return;
    }
    setState(() => _isSearching = true);
    ref.read(searchProvider.notifier).search(query.trim());
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(searchProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ---- Search Bar ----
            Container(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[800]!),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (value) {
                    if (value.isEmpty) {
                      setState(() => _isSearching = false);
                      ref.read(searchProvider.notifier).clear();
                    } else {
                      _performSearch(value);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: '🔍 Search posts, users, hashtags...',
                    hintStyle: const TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _isSearching = false;
                                ref.read(searchProvider.notifier).clear();
                              });
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),

            // ---- Results ----
            Expanded(
              child: _isSearching
                  ? searchState.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : searchState.errorMessage != null
                        ? _buildErrorWidget(searchState.errorMessage!)
                        : _buildResults(searchState)
                  : _buildEmptyState(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_outlined, color: Colors.grey[700], size: 80),
          const SizedBox(height: 16),
          Text(
            'Seek something new…',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Search for posts, users, and hashtags',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.grey[700], size: 60),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildResults(SearchState state) {
    final hasUsers = state.users.isNotEmpty;
    final hasPosts = state.posts.isNotEmpty;
    final hasHashtags = state.hashtags.isNotEmpty;

    if (!hasUsers && !hasPosts && !hasHashtags) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, color: Colors.grey[700], size: 60),
            const SizedBox(height: 16),
            Text(
              'No results found for "${_searchController.text}"',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // ---- Users ----
        if (hasUsers) ...[
          _buildSectionTitle('Users'),
          ...state.users.map((user) => _buildUserTile(user)),
          const SizedBox(height: 16),
        ],
        // ---- Posts ----
        if (hasPosts) ...[
          _buildSectionTitle('Posts'),
          ...state.posts.map((post) => _buildPostTile(post)),
          const SizedBox(height: 16),
        ],
        // ---- Hashtags ----
        if (hasHashtags) ...[
          _buildSectionTitle('Hashtags'),
          ...state.hashtags.map((tag) => _buildHashtagTile(tag)),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    final username = user['display_name'] ?? 'Unknown';
    final displayName = user['username'] ?? username;
    final avatarUrl = user['avatar_url'];

    return ListTile(
      leading: avatarUrl != null && avatarUrl.isNotEmpty
          ? ClipOval(
              child: Image.network(
                avatarUrl,
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildAvatarFallback(username),
              ),
            )
          : _buildAvatarFallback(username),
      title: Text(displayName, style: const TextStyle(color: Colors.white)),
      subtitle: Text('@$username', style: const TextStyle(color: Colors.grey)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple.shade400, Colors.blue.shade400],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Follow',
          style: TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfileScreen(userId: user['id'], isRoot: false),
          ),
        );
      },
    );
  }

  Widget _buildAvatarFallback(String username) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.purple, Colors.blue]),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          username[0].toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildPostTile(PostModel post) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.username,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    post.content ?? '',
                    style: const TextStyle(color: Colors.white),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (post.hashtags.isNotEmpty)
                    Wrap(
                      spacing: 4,
                      children: post.hashtags.take(3).map((tag) {
                        return GestureDetector(
                          behavior: HitTestBehavior
                              .opaque, // Prevents parent tap from firing
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ExploreScreen(initialQuery: tag),
                              ),
                            );
                          },
                          child: Text(
                            '#$tag',
                            style: TextStyle(
                              color: Colors.blue[400],
                              fontSize: 12,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
            if (post.imageUrls.isNotEmpty)
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.image, color: Colors.grey, size: 30),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHashtagTile(String tag) {
    if (tag.trim().isEmpty) return const SizedBox.shrink();
    return ListTile(
      leading: const Icon(Icons.tag, color: Colors.blue),
      title: Text('#$tag', style: const TextStyle(color: Colors.white)),
      onTap: () {
        setState(() {
          _searchController.text = tag;
          _performSearch(tag);
        });
      },
    );
  }
}
