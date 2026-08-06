import 'dart:core';

class PostModel {
  // Core
  final String id;
  final String userId;
  final String username;
  final String displayName;
  final bool isVerified;
  final String? avatarUrl;

  // Content
  final String? content;
  final List<String> hashtags;
  final List<String> mentions;
  final List<String> emojis;
  final List<String> imageUrls;
  final String? videoUrl;
  final String? audioUrl;
  final bool isCarousel;

  // Counts
  final int likeCount;
  final int commentCount;
  final int repostCount;
  final int shareCount;
  final int viewCount;
  final int reachCount;
  final int saveCount;

  // Reactions
  final Map<String, int> reactions;
  final List<String> topReactions;

  // Status
  final String audience;
  final bool isEdited;
  final bool isNSFW;
  final bool isSponsored;
  final bool isAIGenerated;
  final bool isPinned;
  final bool isArchived;
  final bool isDeleted;
  final bool isBlocked;
  final bool isMuted;
  final bool isReported;
  final bool isLikedByUser;
  final bool isBookmarkedByUser;
  final bool isRepostedByUser;
  final bool isMutedByUser;
  final bool isBlockedByUser;

  // Timestamps
  final DateTime createdAt;
  final DateTime? editedAt;

  // Location
  final String? location;

  // Engagement
  final double engagementRate;

  // Tags & links
  final List<String> taggedUsers;
  final String? linkPreview;
  final String? altText;
  final String? copyrightNotice;
  final String? musicAttribution;

  // Poll
  final PollData? poll;
  final int? userPollVoteIndex; // <-- added field

  // Badges
  final String? eventBadge;
  final String? challengeBadge;

  // Donation / Shop
  final bool hasDonation;
  final String? donationUrl;
  final bool hasShop;
  final String? shopUrl;

  // Product tags
  final List<String> productTags;

  // Flags
  final bool showTranslation;
  final bool showOriginal;
  final bool isPinnedComment;

  // Community
  final String? communityNote;
  final String? factCheckLabel;

  // Analytics
  final Map<String, dynamic>? analytics;

  // =====================================================================
  // CONSTRUCTOR
  // =====================================================================
  PostModel({
    required this.id,
    required this.userId,
    required this.username,
    required this.displayName,
    this.isVerified = false,
    this.avatarUrl,
    this.content,
    this.hashtags = const [],
    this.mentions = const [],
    this.emojis = const [],
    this.imageUrls = const [],
    this.videoUrl,
    this.audioUrl,
    this.isCarousel = false,
    this.likeCount = 0,
    this.commentCount = 0,
    this.repostCount = 0,
    this.shareCount = 0,
    this.viewCount = 0,
    this.reachCount = 0,
    this.saveCount = 0,
    this.reactions = const {},
    this.topReactions = const [],
    this.audience = 'Public',
    this.isEdited = false,
    this.isNSFW = false,
    this.isSponsored = false,
    this.isAIGenerated = false,
    this.isPinned = false,
    this.isArchived = false,
    this.isDeleted = false,
    this.isBlocked = false,
    this.isMuted = false,
    this.isReported = false,
    this.isLikedByUser = false,
    this.isBookmarkedByUser = false,
    this.isRepostedByUser = false,
    this.isMutedByUser = false,
    this.isBlockedByUser = false,
    required this.createdAt,
    this.editedAt,
    this.location,
    this.engagementRate = 0.0,
    this.taggedUsers = const [],
    this.linkPreview,
    this.altText,
    this.copyrightNotice,
    this.musicAttribution,
    this.poll,
    this.userPollVoteIndex,
    this.eventBadge,
    this.challengeBadge,
    this.hasDonation = false,
    this.donationUrl,
    this.hasShop = false,
    this.shopUrl,
    this.productTags = const [],
    this.showTranslation = false,
    this.showOriginal = true,
    this.isPinnedComment = false,
    this.communityNote,
    this.factCheckLabel,
    this.analytics,
  });

  // =====================================================================
  // copyWith
  // =====================================================================
  PostModel copyWith({
    String? id,
    String? userId,
    String? username,
    String? displayName,
    bool? isVerified,
    String? avatarUrl,
    String? content,
    List<String>? hashtags,
    List<String>? mentions,
    List<String>? emojis,
    List<String>? imageUrls,
    String? videoUrl,
    String? audioUrl,
    bool? isCarousel,
    int? likeCount,
    int? commentCount,
    int? repostCount,
    int? shareCount,
    int? viewCount,
    int? reachCount,
    int? saveCount,
    Map<String, int>? reactions,
    List<String>? topReactions,
    String? audience,
    bool? isEdited,
    bool? isNSFW,
    bool? isSponsored,
    bool? isAIGenerated,
    bool? isPinned,
    bool? isArchived,
    bool? isDeleted,
    bool? isBlocked,
    bool? isMuted,
    bool? isReported,
    bool? isLikedByUser,
    bool? isBookmarkedByUser,
    bool? isRepostedByUser,
    bool? isMutedByUser,
    bool? isBlockedByUser,
    DateTime? createdAt,
    DateTime? editedAt,
    String? location,
    double? engagementRate,
    List<String>? taggedUsers,
    String? linkPreview,
    String? altText,
    String? copyrightNotice,
    String? musicAttribution,
    PollData? poll,
    int? userPollVoteIndex,
    String? eventBadge,
    String? challengeBadge,
    bool? hasDonation,
    String? donationUrl,
    bool? hasShop,
    String? shopUrl,
    List<String>? productTags,
    bool? showTranslation,
    bool? showOriginal,
    bool? isPinnedComment,
    String? communityNote,
    String? factCheckLabel,
    Map<String, dynamic>? analytics,
  }) {
    return PostModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      isVerified: isVerified ?? this.isVerified,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      content: content ?? this.content,
      hashtags: hashtags ?? this.hashtags,
      mentions: mentions ?? this.mentions,
      emojis: emojis ?? this.emojis,
      imageUrls: imageUrls ?? this.imageUrls,
      videoUrl: videoUrl ?? this.videoUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      isCarousel: isCarousel ?? this.isCarousel,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      repostCount: repostCount ?? this.repostCount,
      shareCount: shareCount ?? this.shareCount,
      viewCount: viewCount ?? this.viewCount,
      reachCount: reachCount ?? this.reachCount,
      saveCount: saveCount ?? this.saveCount,
      reactions: reactions ?? this.reactions,
      topReactions: topReactions ?? this.topReactions,
      audience: audience ?? this.audience,
      isEdited: isEdited ?? this.isEdited,
      isNSFW: isNSFW ?? this.isNSFW,
      isSponsored: isSponsored ?? this.isSponsored,
      isAIGenerated: isAIGenerated ?? this.isAIGenerated,
      isPinned: isPinned ?? this.isPinned,
      isArchived: isArchived ?? this.isArchived,
      isDeleted: isDeleted ?? this.isDeleted,
      isBlocked: isBlocked ?? this.isBlocked,
      isMuted: isMuted ?? this.isMuted,
      isReported: isReported ?? this.isReported,
      isLikedByUser: isLikedByUser ?? this.isLikedByUser,
      isBookmarkedByUser: isBookmarkedByUser ?? this.isBookmarkedByUser,
      isRepostedByUser: isRepostedByUser ?? this.isRepostedByUser,
      isMutedByUser: isMutedByUser ?? this.isMutedByUser,
      isBlockedByUser: isBlockedByUser ?? this.isBlockedByUser,
      createdAt: createdAt ?? this.createdAt,
      editedAt: editedAt ?? this.editedAt,
      location: location ?? this.location,
      engagementRate: engagementRate ?? this.engagementRate,
      taggedUsers: taggedUsers ?? this.taggedUsers,
      linkPreview: linkPreview ?? this.linkPreview,
      altText: altText ?? this.altText,
      copyrightNotice: copyrightNotice ?? this.copyrightNotice,
      musicAttribution: musicAttribution ?? this.musicAttribution,
      poll: poll ?? this.poll,
      userPollVoteIndex: userPollVoteIndex ?? this.userPollVoteIndex,
      eventBadge: eventBadge ?? this.eventBadge,
      challengeBadge: challengeBadge ?? this.challengeBadge,
      hasDonation: hasDonation ?? this.hasDonation,
      donationUrl: donationUrl ?? this.donationUrl,
      hasShop: hasShop ?? this.hasShop,
      shopUrl: shopUrl ?? this.shopUrl,
      productTags: productTags ?? this.productTags,
      showTranslation: showTranslation ?? this.showTranslation,
      showOriginal: showOriginal ?? this.showOriginal,
      isPinnedComment: isPinnedComment ?? this.isPinnedComment,
      communityNote: communityNote ?? this.communityNote,
      factCheckLabel: factCheckLabel ?? this.factCheckLabel,
      analytics: analytics ?? this.analytics,
    );
  }

  // =====================================================================
  // FROM JSON
  // =====================================================================
  factory PostModel.fromJson(
    Map<String, dynamic> json, {
    int? userPollVote,
    bool? isLikedByUser,
    bool? isBookmarkedByUser,
  }) {
    final profile = json['profiles'] as Map<String, dynamic>? ?? {};

    String _s(dynamic val) => val?.toString() ?? '';
    bool _b(dynamic val) => val as bool? ?? false;
    int _i(dynamic val) => (val as num?)?.toInt() ?? 0;
    double _d(dynamic val) => (val as num?)?.toDouble() ?? 0.0;
    List<String> _list(dynamic val) {
      if (val is List) return val.map((e) => e.toString()).toList();
      return [];
    }

    Map<String, int> _map(dynamic val) {
      if (val is Map) {
        return val.map(
          (k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0),
        );
      }
      return {};
    }

    return PostModel(
      id: _s(json['id']),
      userId: _s(json['user_id']),
      username: _s(profile['username'] ?? json['username'] ?? 'Unknown'),
      displayName: _s(
        profile['display_name'] ?? json['display_name'] ?? 'User',
      ),
      isVerified: _b(profile['is_verified'] ?? json['is_verified']),
      avatarUrl:
          profile['avatar_url']?.toString() ?? json['avatar_url']?.toString(),
      content: json['content']?.toString(),
      hashtags: _list(json['hashtags']),
      mentions: _list(json['mentions']),
      emojis: _list(json['emojis']),
      imageUrls: _list(json['image_urls']),
      videoUrl: json['video_url']?.toString(),
      audioUrl: json['audio_url']?.toString(),
      isCarousel: _b(json['is_carousel']),
      likeCount: json['likes'] != null
          ? (json['likes'] as List).length
          : _i(json['like_count']),
      commentCount: json['comments'] != null
          ? (json['comments'] as List).length
          : _i(json['comment_count']),
      repostCount: json['reposts'] != null
          ? (json['reposts'] as List).length
          : _i(json['repost_count']),
      shareCount: _i(json['share_count']),
      viewCount: _i(json['view_count']),
      reachCount: _i(json['reach_count']),
      saveCount: json['bookmarks'] != null
          ? (json['bookmarks'] as List).length
          : _i(json['save_count']),
      reactions: _map(json['reactions']),
      topReactions: _list(json['top_reactions']),
      audience: _s(json['audience']),
      isEdited: _b(json['is_edited']),
      isNSFW: _b(json['is_nsfw']),
      isSponsored: _b(json['is_sponsored']),
      isAIGenerated: _b(json['is_ai_generated']),
      isPinned: _b(json['is_pinned']),
      isArchived: _b(json['is_archived']),
      isDeleted: _b(json['is_deleted']),
      isBlocked: _b(json['is_blocked']),
      isMuted: _b(json['is_muted']),
      isReported: _b(json['is_reported']),
      isLikedByUser: isLikedByUser ?? _b(json['is_liked_by_user']),
      isBookmarkedByUser:
          isBookmarkedByUser ?? _b(json['is_bookmarked_by_user']),
      isRepostedByUser: _b(json['is_reposted_by_user']),
      isMutedByUser: _b(json['is_muted_by_user']),
      isBlockedByUser: _b(json['is_blocked_by_user']),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      editedAt: json['edited_at'] != null
          ? DateTime.parse(json['edited_at'].toString())
          : null,
      location: json['location']?.toString(),
      engagementRate: _d(json['engagement_rate']),
      taggedUsers: _list(json['tagged_users']),
      linkPreview: json['link_preview']?.toString(),
      altText: json['alt_text']?.toString(),
      copyrightNotice: json['copyright_notice']?.toString(),
      musicAttribution: json['music_attribution']?.toString(),
      poll: json['poll'] != null
          ? PollData.fromJson(json['poll'] as Map<String, dynamic>)
          : null,
      userPollVoteIndex: userPollVote, // <-- passed from parameter
      eventBadge: json['event_badge']?.toString(),
      challengeBadge: json['challenge_badge']?.toString(),
      hasDonation: _b(json['has_donation']),
      donationUrl: json['donation_url']?.toString(),
      hasShop: _b(json['has_shop']),
      shopUrl: json['shop_url']?.toString(),
      productTags: _list(json['product_tags']),
      showTranslation: _b(json['show_translation']),
      showOriginal: _b(json['show_original']) ? true : true,
      isPinnedComment: _b(json['is_pinned_comment']),
      communityNote: json['community_note']?.toString(),
      factCheckLabel: json['fact_check_label']?.toString(),
      analytics: json['analytics'] as Map<String, dynamic>?,
    );
  }

  // =====================================================================
  // TO JSON
  // =====================================================================
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'content': content,
      'image_urls': imageUrls,
      'video_url': videoUrl,
      'audio_url': audioUrl,
      'is_carousel': isCarousel,
      'location': location,
      'hashtags': hashtags,
      'mentions': mentions,
      'tagged_users': taggedUsers,
      'audience': audience,
      'is_edited': isEdited,
      'is_nsfw': isNSFW,
      'is_sponsored': isSponsored,
      'is_pinned': isPinned,
      'is_archived': isArchived,
      'is_deleted': isDeleted,
      'is_blocked': isBlocked,
      'is_muted': isMuted,
      'view_count': viewCount,
      'reach_count': reachCount,
      'link_preview': linkPreview,
      'alt_text': altText,
      'music_attribution': musicAttribution,
      'copyright_notice': copyrightNotice,
      'created_at': createdAt.toIso8601String(),
      'poll': poll?.toJson(),
      'product_tags': productTags,
      'has_donation': hasDonation,
      'donation_url': donationUrl,
      'has_shop': hasShop,
      'shop_url': shopUrl,
      'community_note': communityNote,
      'fact_check_label': factCheckLabel,
      'event_badge': eventBadge,
      'challenge_badge': challengeBadge,
      'emojis': emojis,
    };
  }
}

// ---- PollData & PollOption (unchanged) ----
class PollData {
  final String question;
  final List<PollOption> options;
  final int totalVotes;
  final bool isMultipleChoice;
  final DateTime endsAt;

  PollData({
    required this.question,
    required this.options,
    this.totalVotes = 0,
    this.isMultipleChoice = false,
    required this.endsAt,
  });

  factory PollData.fromJson(Map<String, dynamic> json) {
    return PollData(
      question: json['question']?.toString() ?? '',
      options:
          (json['options'] as List?)
              ?.map((e) => PollOption.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalVotes: (json['total_votes'] as num?)?.toInt() ?? 0,
      isMultipleChoice: json['is_multiple_choice'] ?? false,
      endsAt: json['ends_at'] != null
          ? DateTime.parse(json['ends_at'].toString())
          : DateTime.now().add(const Duration(days: 7)),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'options': options.map((e) => e.toJson()).toList(),
      'total_votes': totalVotes,
      'is_multiple_choice': isMultipleChoice,
      'ends_at': endsAt.toIso8601String(),
    };
  }
}

class PollOption {
  final String text;
  final int votes;
  final double percentage;

  PollOption({required this.text, this.votes = 0, this.percentage = 0.0});

  factory PollOption.fromJson(Map<String, dynamic> json) {
    return PollOption(
      text: json['text']?.toString() ?? '',
      votes: (json['votes'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'text': text, 'votes': votes, 'percentage': percentage};
  }
}
