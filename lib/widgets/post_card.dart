import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:veil/export.dart';

class PostCard extends ConsumerStatefulWidget {
  final PostModel post;
  final VoidCallback onShare;
  final VoidCallback onMore;
  final VoidCallback onTapProfile;
  final VoidCallback onTapCard;

  const PostCard({
    super.key,
    required this.post,
    required this.onShare,
    required this.onMore,
    required this.onTapProfile,
    required this.onTapCard,
  });

  @override
  ConsumerState<PostCard> createState() => _PostCardState();
}

class _PostCardState extends ConsumerState<PostCard> {
  bool _isExpanded = false;
  bool _isVoting = false;
  int? _votingOptionIndex;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTapCard,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.grey[800]!.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            if (widget.post.audience != 'Public') _buildAudienceIndicator(),
            if (widget.post.isSponsored) _buildSponsoredBadge(),
            if (widget.post.content != null && widget.post.content!.isNotEmpty)
              _buildTextContent(),
            if (widget.post.hashtags.isNotEmpty) _buildHashtags(),
            if (widget.post.location != null) _buildLocation(),
            if (widget.post.imageUrls.isNotEmpty) _buildImages(),
            if (widget.post.videoUrl != null) _buildVideoPlaceholder(),
            if (widget.post.audioUrl != null) _buildAudioPlaceholder(),
            if (widget.post.poll != null) _buildPoll(),
            if (widget.post.linkPreview != null) _buildLinkPreview(),
            if (widget.post.taggedUsers.isNotEmpty) _buildTaggedUsers(),
            if (widget.post.altText != null) _buildAltText(),
            if (widget.post.isNSFW) _buildNSFWWarning(),
            if (widget.post.reactions.isNotEmpty) _buildReactionsPreview(),
            _buildEngagementBar(),
            if (widget.post.communityNote != null) _buildCommunityNote(),
            if (widget.post.factCheckLabel != null) _buildFactCheck(),
            if (widget.post.musicAttribution != null) _buildMusicAttribution(),
            if (widget.post.copyrightNotice != null) _buildCopyright(),
            if (widget.post.isEdited || widget.post.isArchived)
              _buildStatusIndicators(),
            if (widget.post.isDeleted || widget.post.isBlocked)
              _buildDeletedBlocked(),
          ],
        ),
      ),
    );
  }

  // ========== HEADER WITH AVATAR ==========
  Widget _buildHeader() {
    return GestureDetector(
      onTap: widget.onTapProfile,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _buildAvatar(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          widget.post.username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (widget.post.isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified,
                          color: Colors.blue,
                          size: 16,
                        ),
                      ],
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '@${widget.post.displayName}',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        _getTimeAgo(widget.post.createdAt),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                      if (widget.post.isEdited) ...[
                        const SizedBox(width: 4),
                        const Text(
                          '· Edited',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                      if (widget.post.isPinned) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.push_pin,
                          color: Colors.grey,
                          size: 14,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.more_horiz, color: Colors.grey),
              onPressed: widget.onMore,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final avatarUrl = widget.post.avatarUrl;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return ClipOval(
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
            _getAvatarColor(widget.post.username),
            _getAvatarColor(widget.post.username).withOpacity(0.5),
          ],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          widget.post.username[0].toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
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

  Widget _buildAudienceIndicator() {
    final icon = widget.post.audience == 'Friends' ? Icons.people : Icons.lock;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey, size: 14),
          const SizedBox(width: 4),
          Text(
            widget.post.audience,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSponsoredBadge() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.spellcheck, color: Colors.amber, size: 14),
            SizedBox(width: 4),
            Text(
              'Sponsored',
              style: TextStyle(color: Colors.amber, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextContent() {
    String text = widget.post.content!;
    for (final emoji in widget.post.emojis) {
      text = text.replaceFirst(':', emoji);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.4,
            ),
            maxLines: _isExpanded ? null : 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (text.length > 120)
            GestureDetector(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Text(
                _isExpanded ? ' Show less' : ' Read more',
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHashtags() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Wrap(
        spacing: 6,
        children: widget.post.hashtags.map((tag) {
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
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ================================================================
  // IMAGES
  // ================================================================
  Widget _buildImages() {
    final images = widget.post.imageUrls;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        children: [
          if (images.length == 1)
            _buildSingleImage(images[0])
          else if (images.length == 2)
            Row(
              children: [
                Expanded(child: _buildImageTile(images[0])),
                const SizedBox(width: 4),
                Expanded(child: _buildImageTile(images[1])),
              ],
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: images.length == 3 ? 2 : 3,
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
          if (widget.post.isCarousel)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  images.length > 5 ? 5 : images.length,
                  (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == 0 ? Colors.white : Colors.grey[700],
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSingleImage(String image) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(aspectRatio: 1, child: _buildImageTile(image)),
    );
  }

  Widget _buildImageTile(String image) {
    if (image.isNotEmpty && image.startsWith('http')) {
      return Image.network(
        image,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          print('❌ Image error: $error');
          return _buildGradientPlaceholder(image);
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildGradientPlaceholder(image);
        },
      );
    }
    return _buildGradientPlaceholder(image);
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

  Widget _buildLocation() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: Colors.grey, size: 14),
          const SizedBox(width: 4),
          Text(
            widget.post.location!,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ========== VIDEO PLACEHOLDER ==========
  Widget _buildVideoPlaceholder() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 200,
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
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '▶️ Video',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ========== AUDIO PLACEHOLDER ==========
  Widget _buildAudioPlaceholder() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.music_note, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🎵 Audio Track',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  LinearProgressIndicator(
                    value: 0.5,
                    backgroundColor: Colors.grey[600],
                    color: Colors.blue[400],
                  ),
                ],
              ),
            ),
            const Icon(Icons.play_arrow, color: Colors.white),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // POLL – Interactive with ref
  // ================================================================
  Widget _buildPoll() {
    final poll = widget.post.poll!;
    final userVote = widget.post.userPollVoteIndex;
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
                              widget.post.id,
                              idx,
                              unvote: true,
                            );
                          } else {
                            await postService.votePoll(widget.post.id, idx);
                          }
                          final updatedPost = await postService.getPost(
                            widget.post.id,
                          );
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

  Widget _buildLinkPreview() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                    widget.post.linkPreview!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    'Open link',
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

  // ========== TAGGED USERS ==========
  Widget _buildTaggedUsers() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Wrap(
        spacing: 4,
        children: widget.post.taggedUsers.map((user) {
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

  // ========== ALT TEXT ==========
  Widget _buildAltText() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Row(
        children: [
          const Icon(Icons.alt_route, color: Colors.grey, size: 14),
          const SizedBox(width: 4),
          Text(
            'ALT: ${widget.post.altText}',
            style: const TextStyle(color: Colors.grey, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ========== NSFW WARNING ==========
  Widget _buildNSFWWarning() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.red,
              size: 14,
            ),
            const SizedBox(width: 4),
            const Text(
              'Sensitive Content',
              style: TextStyle(color: Colors.red, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  // ========== REACTIONS PREVIEW ==========
  Widget _buildReactionsPreview() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          ...widget.post.topReactions.map((emoji) {
            return Container(
              margin: const EdgeInsets.only(right: 2),
              child: Text(emoji, style: const TextStyle(fontSize: 16)),
            );
          }),
          const SizedBox(width: 6),
          Text(
            '${widget.post.reactions.values.reduce((a, b) => a + b)}',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ========== ENGAGEMENT BAR ==========
  Widget _buildEngagementBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(
        children: [
          Text(
            '${widget.post.likeCount} likes',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(width: 16),
          Text(
            '${widget.post.commentCount} comments',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const Spacer(),
          Text(
            '${widget.post.viewCount} views',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ========== COMMUNITY NOTE ==========
  Widget _buildCommunityNote() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(10),
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
                '📝 ${widget.post.communityNote}',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========== FACT CHECK ==========
  Widget _buildFactCheck() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(10),
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
              '⚠️ ${widget.post.factCheckLabel}',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  // ========== MUSIC ATTRIBUTION ==========
  Widget _buildMusicAttribution() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Row(
        children: [
          const Icon(Icons.music_note, color: Colors.grey, size: 14),
          const SizedBox(width: 4),
          Text(
            '🎵 ${widget.post.musicAttribution}',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ========== COPYRIGHT ==========
  Widget _buildCopyright() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Text(
        '© ${widget.post.copyrightNotice}',
        style: const TextStyle(color: Colors.grey, fontSize: 11),
      ),
    );
  }

  // ========== STATUS INDICATORS ==========
  Widget _buildStatusIndicators() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Wrap(
        spacing: 8,
        children: [
          if (widget.post.isEdited)
            const Text(
              '🖊️ Edited',
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
          if (widget.post.isArchived)
            const Text(
              '📁 Archived',
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
        ],
      ),
    );
  }

  // ========== DELETED/BLOCKED ==========
  Widget _buildDeletedBlocked() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              widget.post.isDeleted ? Icons.delete_outline : Icons.block,
              color: Colors.grey,
            ),
            const SizedBox(width: 8),
            Text(
              widget.post.isDeleted
                  ? 'This post has been deleted'
                  : 'Content unavailable',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
