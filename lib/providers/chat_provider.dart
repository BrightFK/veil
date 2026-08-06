import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:veil/export.dart'; // adjust import if needed

final chatServiceProvider = Provider<ChatService>((ref) => ChatService());

// ─────────────────────────────────────────────
// Conversations
// ─────────────────────────────────────────────
class ConversationsState {
  final List<Map<String, dynamic>> conversations;
  final bool isLoading;
  final String? error;

  const ConversationsState({
    this.conversations = const [],
    this.isLoading = false,
    this.error,
  });

  ConversationsState copyWith({
    List<Map<String, dynamic>>? conversations,
    bool? isLoading,
    String? error,
  }) {
    return ConversationsState(
      conversations: conversations ?? this.conversations,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class ConversationsNotifier extends StateNotifier<ConversationsState> {
  final ChatService _service;
  RealtimeChannel? _subscription;

  ConversationsNotifier(this._service) : super(const ConversationsState()) {
    loadConversations();
    _subscribeToUpdates();
  }

  Future<void> loadConversations() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final conversations = await _service.getConversations();
      state = state.copyWith(conversations: conversations, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void _subscribeToUpdates() {
    _subscription = _service.subscribeToConversationUpdates(() {
      loadConversations();
    });
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }
}

final conversationsProvider =
    StateNotifierProvider<ConversationsNotifier, ConversationsState>((ref) {
      final service = ref.watch(chatServiceProvider);
      return ConversationsNotifier(service);
    });

// ─────────────────────────────────────────────
// Messages (family)
// ─────────────────────────────────────────────
class MessagesState {
  final List<Map<String, dynamic>> messages;
  final bool isLoading;
  final String? error;

  const MessagesState({
    this.messages = const [],
    this.isLoading = false,
    this.error,
  });

  MessagesState copyWith({
    List<Map<String, dynamic>>? messages,
    bool? isLoading,
    String? error,
  }) {
    return MessagesState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class MessagesNotifier extends StateNotifier<MessagesState> {
  final ChatService _service;
  final String conversationId;
  final Ref _ref;
  RealtimeChannel? _subscription;

  MessagesNotifier(this._service, this.conversationId, this._ref)
    : super(const MessagesState()) {
    loadMessages();
    _subscribe();
  }

  Future<void> loadMessages() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final messages = await _service.getMessages(conversationId);
      state = state.copyWith(messages: messages, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void _subscribe() {
    _subscription?.unsubscribe();

    _subscription = _service.subscribeToMessages(conversationId, (newMsg) {
      // Remove any temporary (optimistic) message with the same content + sender
      final cleaned = state.messages.where((m) {
        final isTemp = m['id'].toString().startsWith('temp_');
        final sameContent = m['content'] == newMsg['content'];
        final sameSender = m['sender_id'] == newMsg['sender_id'];
        return !(isTemp && sameContent && sameSender);
      }).toList();

      // Avoid exact duplicates by real ID
      final alreadyExists = cleaned.any((m) => m['id'] == newMsg['id']);
      if (!alreadyExists) {
        state = state.copyWith(messages: [...cleaned, newMsg]);
      } else {
        state = state.copyWith(messages: cleaned);
      }
    });
  }

  Future<void> sendMessage(String content) async {
    final text = content.trim();
    if (text.isEmpty) return;

    final currentUserId = _ref.read(authProvider).user?.id;
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

    // Optimistic message
    final optimistic = {
      'id': tempId,
      'conversation_id': conversationId,
      'sender_id': currentUserId,
      'content': text,
      'created_at': DateTime.now().toIso8601String(),
      'profiles': {'display_name': 'You', 'username': 'you'},
    };

    state = state.copyWith(messages: [...state.messages, optimistic]);

    try {
      await _service.sendMessage(conversationId, text);
    } catch (e) {
      // Remove optimistic on error
      state = state.copyWith(
        messages: state.messages.where((m) => m['id'] != tempId).toList(),
        error: e.toString(),
      );
    }
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }
}

final messagesProvider =
    StateNotifierProvider.family<MessagesNotifier, MessagesState, String>((
      ref,
      conversationId,
    ) {
      final service = ref.watch(chatServiceProvider);
      return MessagesNotifier(service, conversationId, ref);
    });
