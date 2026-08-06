import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:veil/export.dart';

class PostService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ========== AUTH & PROFILE ==========
  Future<Map<String, dynamic>> getProfile(String userId) async {
    final response = await _supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();
    return response;
  }

  Future<void> updateProfile(
    String userId, {
    String? username,
    String? displayName,
    String? bio,
    String? website,
    String? avatarUrl,
  }) async {
    final data = <String, dynamic>{};
    if (username != null) data['username'] = username;
    if (displayName != null) data['display_name'] = displayName;
    if (bio != null) data['bio'] = bio;
    if (website != null) data['website'] = website;
    if (avatarUrl != null) data['avatar_url'] = avatarUrl;
    await _supabase.from('profiles').update(data).eq('id', userId);
  }

  Future<String> uploadAvatar(String userId, String filePath) async {
    final file = File(filePath);
    final fileName = '$userId-${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path = 'avatars/$fileName';
    await _supabase.storage.from('avatars').upload(path, file);
    final publicUrl = _supabase.storage.from('avatars').getPublicUrl(path);
    await _supabase
        .from('profiles')
        .update({'avatar_url': publicUrl})
        .eq('id', userId);
    return publicUrl;
  }

  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    return await _supabase
        .from('profiles')
        .select('''
          *,
          posts (id),
          followers:follows!following_id (follower_id),
          following:follows!follower_id (following_id)
        ''')
        .eq('id', userId)
        .single();
  }

  // ========== POSTS ==========
  Future<List<PostModel>> fetchPosts({
    int limit = 10,
    String feedType = 'world',
  }) async {
    final currentUserId = _supabase.auth.currentUser!.id;

    // Get muted and blocked user IDs
    final muted = await getMutedUserIds();
    final blocked = await getBlockedUserIds();
    final excludedIds = [...muted, ...blocked];

    var query = _supabase
        .from('posts')
        .select('''
        *,
        profiles!user_id (
          id, username, display_name, avatar_url, is_verified
        ),
        likes (user_id),
        comments (id),
        bookmarks (user_id),
        poll_votes (option_index, user_id)
      ''')
        .eq('is_deleted', false);

    // Exclude muted/blocked users
    if (excludedIds.isNotEmpty) {
      query = query.filter('user_id', 'not.in', '(${excludedIds.join(',')})');
    }

    if (feedType == 'world') {
      query = query.eq('audience', 'Public');
    } else if (feedType == 'circle' || feedType == 'friends') {
      final circleIds = await getCircleUserIds();
      final allIds = [...circleIds, currentUserId];
      query = query
          .eq('audience', 'Friends')
          .filter('user_id', 'in', '(${allIds.join(',')})');
    } else if (feedType == 'private') {
      query = query.eq('user_id', currentUserId).eq('audience', 'Private');
    } else {
      return [];
    }

    final response = await query
        .order('created_at', ascending: false)
        .limit(limit);

    final List<dynamic> data = response;
    return data.map((json) {
      int? userVote;
      final votes = json['poll_votes'] as List? ?? [];
      for (final v in votes) {
        if (v['user_id'] == currentUserId) {
          userVote = v['option_index'] as int?;
          break;
        }
      }
      bool liked = false;
      final likes = json['likes'] as List? ?? [];
      for (final like in likes) {
        if (like['user_id'] == currentUserId) {
          liked = true;
          break;
        }
      }
      bool bookmarked = false;
      final bookmarks = json['bookmarks'] as List? ?? [];
      for (final bookmark in bookmarks) {
        if (bookmark['user_id'] == currentUserId) {
          bookmarked = true;
          break;
        }
      }
      return PostModel.fromJson(
        json,
        userPollVote: userVote,
        isLikedByUser: liked,
        isBookmarkedByUser: bookmarked,
      );
    }).toList();
  }

  Future<PostModel> createPost(
    String content, {
    List<String> imageUrls = const [],
    List<String> hashtags = const [],
    String? location,
    String audience = 'Public',
    bool isNSFW = false,
    String? altText,
    List<String> taggedUsers = const [],
    Map<String, dynamic>? poll,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    final data = {
      'user_id': userId,
      'content': content,
      'image_urls': imageUrls,
      'hashtags': hashtags,
      'location': location,
      'audience': audience,
      'is_nsfw': isNSFW,
      'alt_text': altText,
      'tagged_users': taggedUsers,
      'created_at': DateTime.now().toIso8601String(),
    };
    if (poll != null) data['poll'] = poll;
    final response = await _supabase
        .from('posts')
        .insert(data)
        .select('*, profiles!user_id (*)')
        .single();
    return PostModel.fromJson(response);
  }

  Future<void> createPostFromMap(Map<String, dynamic> data) async {
    await _supabase.from('posts').insert(data);
  }

  Future<void> deletePost(String postId) async {
    await _supabase.from('posts').update({'is_deleted': true}).eq('id', postId);
  }

  Future<List<PostModel>> getUserPosts(
    String userId, {
    bool includePrivate = false,
  }) async {
    var query = _supabase
        .from('posts')
        .select('*, profiles!user_id (*)')
        .eq('user_id', userId)
        .eq('is_deleted', false);
    if (!includePrivate) {
      query = query.eq('audience', 'Public');
    }
    final response = await query.order('created_at', ascending: false);
    return response.map((json) => PostModel.fromJson(json)).toList();
  }

  // ========== LIKES ==========
  Future<void> toggleLike(String postId) async {
    final userId = _supabase.auth.currentUser!.id;
    final existing = await _supabase
        .from('likes')
        .select()
        .eq('post_id', postId)
        .eq('user_id', userId)
        .maybeSingle();
    if (existing != null) {
      await _supabase
          .from('likes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', userId);
    } else {
      await _supabase.from('likes').insert({
        'post_id': postId,
        'user_id': userId,
      });
    }
  }

  Future<List<PostModel>> getLikedPosts() async {
    final userId = _supabase.auth.currentUser!.id;
    final response = await _supabase
        .from('likes')
        .select('posts (*, profiles!user_id (*))')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return response.map((json) {
      final postJson = json['posts'] as Map<String, dynamic>;
      return PostModel.fromJson(postJson);
    }).toList();
  }

  // ========== BOOKMARKS ==========
  Future<void> toggleBookmark(String postId) async {
    final userId = _supabase.auth.currentUser!.id;
    final existing = await _supabase
        .from('bookmarks')
        .select()
        .eq('post_id', postId)
        .eq('user_id', userId)
        .maybeSingle();
    if (existing != null) {
      await _supabase
          .from('bookmarks')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', userId);
    } else {
      await _supabase.from('bookmarks').insert({
        'post_id': postId,
        'user_id': userId,
      });
    }
  }

  Future<List<PostModel>> getBookmarkedPosts() async {
    final userId = _supabase.auth.currentUser!.id;
    final response = await _supabase
        .from('bookmarks')
        .select('posts (*, profiles!user_id (*))')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return response.map((json) {
      final postJson = json['posts'] as Map<String, dynamic>;
      return PostModel.fromJson(postJson);
    }).toList();
  }

  // ========== COMMENTS ==========
  Future<List<Map<String, dynamic>>> getCommentsForPost(String postId) async {
    final response = await _supabase
        .from('comments')
        .select('*, profiles!user_id (username, display_name, avatar_url)')
        .eq('post_id', postId)
        .order('created_at', ascending: true);
    return response;
  }

  Future<void> addComment(String postId, String content) async {
    final userId = _supabase.auth.currentUser!.id;
    await _supabase.from('comments').insert({
      'post_id': postId,
      'user_id': userId,
      'content': content,
    });
    await _supabase.rpc('increment_comment_count', params: {'post_id': postId});
  }

  // ========== VIEW COUNT ==========
  Future<void> incrementViewCount(String postId) async {
    await _supabase.rpc('increment_view_count', params: {'post_id': postId});
  }

  // ========== POLLS ==========
  Future<void> votePoll(
    String postId,
    int optionIndex, {
    bool unvote = false,
  }) async {
    final userId = _supabase.auth.currentUser!.id;

    // 1. Get current poll data
    final postResponse = await _supabase
        .from('posts')
        .select('poll')
        .eq('id', postId)
        .single();
    final Map<String, dynamic> pollData = postResponse['poll'] ?? {};
    final List<dynamic> options = pollData['options'] ?? [];
    if (optionIndex < 0 || optionIndex >= options.length) {
      throw Exception('Invalid option index');
    }

    // 2. Get user's existing vote
    final existingVote = await _supabase
        .from('poll_votes')
        .select('option_index')
        .eq('post_id', postId)
        .eq('user_id', userId)
        .maybeSingle();

    // 3. If unvote is requested
    if (unvote) {
      if (existingVote == null) return; // no vote to remove
      int previousOption = existingVote['option_index'] as int;
      // Decrement count for that option
      final newOptions = List<Map<String, dynamic>>.from(options);
      newOptions[previousOption]['votes'] =
          (newOptions[previousOption]['votes'] as int) - 1;
      final updatedPoll = {
        'question': pollData['question'],
        'options': newOptions,
        'totalVotes': (pollData['totalVotes'] as int? ?? 0) - 1,
        'endsAt': pollData['endsAt'],
      };
      await _supabase
          .from('posts')
          .update({'poll': updatedPoll})
          .eq('id', postId);
      // Delete the vote record
      await _supabase
          .from('poll_votes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', userId);
      return;
    }

    // 4. Vote or change vote
    int previousOption = -1;
    if (existingVote != null) {
      previousOption = existingVote['option_index'] as int;
      if (previousOption == optionIndex) {
        // If same option, treat as unvote (just call this method with unvote=true)
        return votePoll(postId, optionIndex, unvote: true);
      }
    }

    // Update counts: decrement previous, increment new
    final newOptions = List<Map<String, dynamic>>.from(options);
    if (previousOption >= 0 && previousOption < newOptions.length) {
      newOptions[previousOption]['votes'] =
          (newOptions[previousOption]['votes'] as int) - 1;
    }
    newOptions[optionIndex]['votes'] =
        (newOptions[optionIndex]['votes'] as int) + 1;

    final updatedPoll = {
      'question': pollData['question'],
      'options': newOptions,
      'totalVotes':
          (pollData['totalVotes'] as int? ?? 0) + (previousOption < 0 ? 1 : 0),
      'endsAt': pollData['endsAt'],
    };

    await _supabase
        .from('posts')
        .update({'poll': updatedPoll})
        .eq('id', postId);

    // Insert or update poll_votes
    if (existingVote != null) {
      await _supabase
          .from('poll_votes')
          .update({'option_index': optionIndex})
          .eq('post_id', postId)
          .eq('user_id', userId);
    } else {
      await _supabase.from('poll_votes').insert({
        'post_id': postId,
        'user_id': userId,
        'option_index': optionIndex,
      });
    }
  }

  Future<int?> getUserPollVote(String postId) async {
    final userId = _supabase.auth.currentUser!.id;
    final result = await _supabase
        .from('poll_votes')
        .select('option_index')
        .eq('post_id', postId)
        .eq('user_id', userId)
        .maybeSingle();
    return result?['option_index'] as int?;
  }

  // ========== SEARCH ==========
  Future<List<PostModel>> searchPosts(String query, {int limit = 20}) async {
    if (query.isEmpty) return [];
    final response = await _supabase
        .from('posts')
        .select('*, profiles!user_id (*)')
        .or('content.ilike.%$query%, hashtags.cs.{$query}')
        .eq('is_deleted', false)
        .order('created_at', ascending: false)
        .limit(limit);
    return response.map((json) => PostModel.fromJson(json)).toList();
  }

  Future<List<Map<String, dynamic>>> searchUsers(
    String query, {
    int limit = 10,
  }) async {
    if (query.isEmpty) return [];
    final response = await _supabase
        .from('profiles')
        .select('id, username, display_name, avatar_url')
        .or('username.ilike.%$query%, display_name.ilike.%$query%')
        .limit(limit);
    return response;
  }

  Future<List<String>> searchHashtags(String query, {int limit = 20}) async {
    if (query.isEmpty) return [];
    try {
      final response = await _supabase.rpc(
        'search_hashtags',
        params: {'search_term': query, 'limit_val': limit},
      );
      if (response is List) {
        return response
            .map((e) => e['hashtag']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  // Get a single post by ID (with profile data)
  Future<PostModel> getPost(String postId) async {
    final response = await _supabase
        .from('posts')
        .select('*, profiles!user_id (*)')
        .eq('id', postId)
        .single();
    return PostModel.fromJson(response);
  }

  // ==== Pin/Archive ====
  Future<void> togglePin(String postId) async {
    final current = await _supabase
        .from('posts')
        .select('is_pinned')
        .eq('id', postId)
        .single();
    final isPinned = current['is_pinned'] ?? false;
    await _supabase
        .from('posts')
        .update({'is_pinned': !isPinned})
        .eq('id', postId);
  }

  Future<void> toggleArchive(String postId) async {
    final current = await _supabase
        .from('posts')
        .select('is_archived')
        .eq('id', postId)
        .single();
    final isArchived = current['is_archived'] ?? false;
    await _supabase
        .from('posts')
        .update({'is_archived': !isArchived})
        .eq('id', postId);
  }

  // ==== Edit ====
  Future<void> updatePostContent(String postId, String content) async {
    await _supabase
        .from('posts')
        .update({'content': content, 'is_edited': true})
        .eq('id', postId);
  }

  // ==== Report ====
  Future<void> reportPost(String postId, {String? reason}) async {
    final userId = _supabase.auth.currentUser!.id;
    await _supabase.from('reports').insert({
      'post_id': postId,
      'user_id': userId,
      'reason': reason,
    });
  }

  Future<void> ensureProfileExists(String userId) async {
    final existing = await _supabase
        .from('profiles')
        .select('id')
        .eq('id', userId)
        .maybeSingle();
    if (existing == null) {
      // Get user email from auth
      final user = await _supabase.auth.admin.getUserById(userId);
      final email = user.user?.email ?? '';
      final username = email.split('@').first;
      await _supabase.from('profiles').insert({
        'id': userId,
        'username': username,
        'display_name': username,
        'email': email,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  // ----- Circle Connections -----
  Future<List<String>> getCircleUserIds() async {
    final userId = _supabase.auth.currentUser!.id;
    final response = await _supabase
        .from('circle_connections')
        .select('user_id, circle_user_id')
        .or('user_id.eq.$userId,circle_user_id.eq.$userId')
        .eq('status', 'accepted');
    final List<String> ids = [];
    for (final row in response) {
      final uid = row['user_id'] as String;
      final cid = row['circle_user_id'] as String;
      ids.add(uid == userId ? cid : uid);
    }
    return ids;
  }

  Future<void> sendCircleRequest(String targetUserId) async {
    final userId = _supabase.auth.currentUser!.id;
    final existing = await _supabase
        .from('circle_connections')
        .select()
        .eq('user_id', userId)
        .eq('circle_user_id', targetUserId)
        .maybeSingle();
    if (existing != null) return;
    await _supabase.from('circle_connections').insert({
      'user_id': userId,
      'circle_user_id': targetUserId,
      'status': 'pending',
    });
  }

  Future<void> acceptCircleRequest(String requestId) async {
    await _supabase
        .from('circle_connections')
        .update({
          'status': 'accepted',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', requestId);
  }

  Future<void> rejectCircleRequest(String requestId) async {
    await _supabase.from('circle_connections').delete().eq('id', requestId);
  }

  Future<Map<String, dynamic>?> getCircleRequestStatus(
    String targetUserId,
  ) async {
    final userId = _supabase.auth.currentUser!.id;
    // Check if we sent a request (we are user_id)
    final sent = await _supabase
        .from('circle_connections')
        .select('id, status')
        .eq('user_id', userId)
        .eq('circle_user_id', targetUserId)
        .maybeSingle();
    if (sent != null) {
      return {'status': sent['status'], 'id': sent['id'], 'isSent': true};
    }
    // Check if we received a request (we are circle_user_id)
    final received = await _supabase
        .from('circle_connections')
        .select('id, status')
        .eq('circle_user_id', userId)
        .eq('user_id', targetUserId)
        .maybeSingle();
    if (received != null) {
      return {
        'status': received['status'],
        'id': received['id'],
        'isSent': false,
      };
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> getPendingCircleRequests() async {
    final userId = _supabase.auth.currentUser!.id;
    final response = await _supabase
        .from('circle_connections')
        .select('''
        id,
        user_id,
        profiles!user_id (
          id,
          username,
          display_name,
          avatar_url
        )
      ''')
        .eq('circle_user_id', userId)
        .eq('status', 'pending');
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getCircleMembers() async {
    final userId = _supabase.auth.currentUser!.id;

    final response = await _supabase
        .from('circle_connections')
        .select('user_id, circle_user_id')
        .or('user_id.eq.$userId,circle_user_id.eq.$userId')
        .eq('status', 'accepted');

    final List<String> memberIds = [];
    for (final row in response) {
      final uid = row['user_id'] as String;
      final cid = row['circle_user_id'] as String;
      final otherId = uid == userId ? cid : uid;
      memberIds.add(otherId);
    }

    if (memberIds.isEmpty) return [];

    // Use filter instead of in_
    final profiles = await _supabase
        .from('profiles')
        .select('id, username, display_name, avatar_url')
        .filter('id', 'in', '(${memberIds.join(',')})');

    return List<Map<String, dynamic>>.from(profiles);
  }

  // ---------- Mute / Block ----------
  Future<void> muteUser(String userIdToMute) async {
    final userId = _supabase.auth.currentUser!.id;
    await _supabase.from('muted_users').insert({
      'user_id': userId,
      'muted_user_id': userIdToMute,
    });
  }

  Future<void> blockUser(String userIdToBlock) async {
    final userId = _supabase.auth.currentUser!.id;
    await _supabase.from('blocked_users').insert({
      'user_id': userId,
      'blocked_user_id': userIdToBlock,
    });
  }

  Future<List<String>> getMutedUserIds() async {
    final userId = _supabase.auth.currentUser!.id;
    final response = await _supabase
        .from('muted_users')
        .select('muted_user_id')
        .eq('user_id', userId);
    return response.map((e) => e['muted_user_id'] as String).toList();
  }

  Future<List<String>> getBlockedUserIds() async {
    final userId = _supabase.auth.currentUser!.id;
    final response = await _supabase
        .from('blocked_users')
        .select('blocked_user_id')
        .eq('user_id', userId);
    return response.map((e) => e['blocked_user_id'] as String).toList();
  }

  // ==== Hidden Posts ====
  Future<void> hidePost(String postId) async {
    final userId = _supabase.auth.currentUser!.id;
    await _supabase.from('hidden_posts').insert({
      'user_id': userId,
      'post_id': postId,
    });
  }

  Future<void> unhidePost(String postId) async {
    final userId = _supabase.auth.currentUser!.id;
    await _supabase
        .from('hidden_posts')
        .delete()
        .eq('user_id', userId)
        .eq('post_id', postId);
  }

  Future<List<Map<String, dynamic>>> getHiddenPosts() async {
    final userId = _supabase.auth.currentUser!.id;
    final response = await _supabase
        .from('hidden_posts')
        .select('posts (*, profiles!user_id (*))')
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  // ==== Muted Users ====
  Future<List<Map<String, dynamic>>> getMutedUsers() async {
    final userId = _supabase.auth.currentUser!.id;
    final response = await _supabase
        .from('muted_users')
        .select('''
        muted_user_id,
        profiles!muted_user_id (
          id, username, display_name, avatar_url
        )
      ''')
        .eq('user_id', userId);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> unmuteUser(String mutedUserId) async {
    final userId = _supabase.auth.currentUser!.id;
    await _supabase
        .from('muted_users')
        .delete()
        .eq('user_id', userId)
        .eq('muted_user_id', mutedUserId);
  }

  // ==== Blocked Users ====
  Future<List<Map<String, dynamic>>> getBlockedUsers() async {
    final userId = _supabase.auth.currentUser!.id;
    final response = await _supabase
        .from('blocked_users')
        .select('''
        blocked_user_id,
        profiles!blocked_user_id (
          id, username, display_name, avatar_url
        )
      ''')
        .eq('user_id', userId);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> unblockUser(String blockedUserId) async {
    final userId = _supabase.auth.currentUser!.id;
    await _supabase
        .from('blocked_users')
        .delete()
        .eq('user_id', userId)
        .eq('blocked_user_id', blockedUserId);
  }
}
