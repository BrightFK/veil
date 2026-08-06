import 'package:flutter_riverpod/legacy.dart';
import 'package:veil/export.dart';

class SearchState {
  final bool isLoading;
  final List<PostModel> posts;
  final List<Map<String, dynamic>> users;
  final List<String> hashtags;
  final String? errorMessage;

  SearchState({
    this.isLoading = false,
    this.posts = const [],
    this.users = const [],
    this.hashtags = const [],
    this.errorMessage,
  });

  SearchState copyWith({
    bool? isLoading,
    List<PostModel>? posts,
    List<Map<String, dynamic>>? users,
    List<String>? hashtags,
    String? errorMessage,
  }) {
    return SearchState(
      isLoading: isLoading ?? this.isLoading,
      posts: posts ?? this.posts,
      users: users ?? this.users,
      hashtags: hashtags ?? this.hashtags,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class SearchNotifier extends StateNotifier<SearchState> {
  final PostService _postService;

  SearchNotifier(this._postService) : super(SearchState());

  Future<void> search(String query) async {
    if (query.isEmpty) {
      state = state.copyWith(posts: [], users: [], hashtags: []);
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final posts = await _postService.searchPosts(query);
      final users = await _postService.searchUsers(query);
      final hashtags = await _postService.searchHashtags(query);

      state = state.copyWith(
        isLoading: false,
        posts: posts,
        users: users,
        hashtags: hashtags,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void clear() {
    state = SearchState();
  }
}

final searchProvider = StateNotifierProvider<SearchNotifier, SearchState>((
  ref,
) {
  final postService = ref.watch(postServiceProvider);
  return SearchNotifier(postService);
});
