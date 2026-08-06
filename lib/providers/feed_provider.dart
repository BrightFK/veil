import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:veil/export.dart';

final postServiceProvider = Provider<PostService>((ref) => PostService());

class FeedState {
  final List<PostModel> posts;
  final bool isLoading;
  final bool isLoadingMore;
  final String? errorMessage;
  final bool hasReachedMax;
  final String feedType; // 'world', 'circle', 'private'

  FeedState({
    this.posts = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.errorMessage,
    this.hasReachedMax = false,
    this.feedType = 'world',
  });

  FeedState copyWith({
    List<PostModel>? posts,
    bool? isLoading,
    bool? isLoadingMore,
    String? errorMessage,
    bool? hasReachedMax,
    String? feedType,
  }) {
    return FeedState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: errorMessage ?? this.errorMessage,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      feedType: feedType ?? this.feedType,
    );
  }
}

class FeedNotifier extends StateNotifier<FeedState> {
  final PostService _postService;
  final Ref _ref;

  FeedNotifier(this._postService, this._ref) : super(FeedState()) {
    fetchPosts();
  }

  Future<void> fetchPosts({bool refresh = false, String? feedType}) async {
    final type = feedType ?? state.feedType;
    if (refresh) {
      state = state.copyWith(posts: [], hasReachedMax: false, feedType: type);
    }
    if (state.isLoading || state.hasReachedMax) return;

    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final newPosts = await _postService.fetchPosts(limit: 10, feedType: type);
      state = state.copyWith(
        posts: newPosts,
        isLoading: false,
        hasReachedMax: newPosts.length < 10,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || state.hasReachedMax || state.posts.isEmpty)
      return;

    state = state.copyWith(isLoadingMore: true);
    try {
      final newPosts = await _postService.fetchPosts(limit: 10);
      final allPosts = [...state.posts, ...newPosts];
      state = state.copyWith(
        posts: allPosts,
        isLoadingMore: false,
        hasReachedMax: newPosts.length < 10,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, errorMessage: e.toString());
    }
  }

  Future<void> createPost(String content) async {
    try {
      final newPost = await _postService.createPost(content);
      state = state.copyWith(posts: [newPost, ...state.posts]);
      _ref.read(refreshProfileProvider.notifier).state++;
    } catch (e) {
      // handle error
    }
  }

  // ====== Like ======
  Future<void> toggleLike(String postId) async {
    try {
      await _postService.toggleLike(postId);
      final updatedPost = await _postService.getPost(postId);
      updatePost(updatedPost);
      _ref.read(refreshProfileProvider.notifier).state++;
    } catch (e) {
      // handle error
    }
  }

  // ====== Bookmark ======
  Future<void> toggleBookmark(String postId) async {
    try {
      await _postService.toggleBookmark(postId);
      final updatedPost = await _postService.getPost(postId);
      updatePost(updatedPost);
      _ref.read(refreshProfileProvider.notifier).state++;
    } catch (e) {
      // handle error
    }
  }

  // ====== Delete ======
  Future<void> deletePost(String postId) async {
    try {
      await _postService.deletePost(postId);
      _ref.read(refreshProfileProvider.notifier).state++;
      state = state.copyWith(
        posts: state.posts.where((p) => p.id != postId).toList(),
      );
    } catch (e) {
      // handle error
    }
  }

  // ====== Update a single post ======
  void updatePost(PostModel updatedPost) {
    final index = state.posts.indexWhere((p) => p.id == updatedPost.id);
    if (index != -1) {
      final newPosts = List<PostModel>.from(state.posts);
      newPosts[index] = updatedPost;
      state = state.copyWith(posts: newPosts);
    }
  }

  // ====== Hide ======
  Future<void> hidePost(String postId) async {
    try {
      await _postService.hidePost(postId);
      state = state.copyWith(
        posts: state.posts.where((p) => p.id != postId).toList(),
      );
    } catch (e) {
      // handle
    }
  }

  // ====== Pin ======
  Future<void> togglePin(String postId) async {
    try {
      await _postService.togglePin(postId);
      final updated = await _postService.getPost(postId);
      updatePost(updated);
    } catch (e) {
      // handle
    }
  }

  // ====== Archive ======
  Future<void> toggleArchive(String postId) async {
    try {
      await _postService.toggleArchive(postId);
      final updated = await _postService.getPost(postId);
      updatePost(updated);
    } catch (e) {
      // handle
    }
  }

  // ====== Edit ======
  Future<void> editPost(String postId, String content) async {
    try {
      await _postService.updatePostContent(postId, content);
      final updated = await _postService.getPost(postId);
      updatePost(updated);
    } catch (e) {
      // handle
    }
  }

  // ====== Report ======
  Future<void> reportPost(String postId, {String? reason}) async {
    await _postService.reportPost(postId, reason: reason);
  }

  // ====== Mute ======
  Future<void> muteUser(String userId) async {
    await _postService.muteUser(userId);
  }

  // ====== Block ======
  Future<void> blockUser(String userId) async {
    await _postService.blockUser(userId);
  }

  @override
  void dispose() {
    super.dispose();
  }
}

final feedProvider = StateNotifierProvider<FeedNotifier, FeedState>((ref) {
  final postService = ref.watch(postServiceProvider);
  return FeedNotifier(postService, ref);
});
