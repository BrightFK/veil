import 'package:supabase_flutter/supabase_flutter.dart';

class ChatService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ─────────────────────────────────────────────
  // Conversations
  // ─────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getConversations() async {
    final userId = _supabase.auth.currentUser!.id;

    final response = await _supabase
        .from('conversation_participants')
        .select('''
          conversation_id,
          conversations (
            id,
            last_message,
            last_message_time,
            updated_at
          )
        ''')
        .eq('user_id', userId);

    final List<Map<String, dynamic>> result = [];

    for (final entry in response) {
      final convId = entry['conversation_id'] as String;
      final convData = entry['conversations'] as Map<String, dynamic>;

      // Other participant
      final other = await _supabase
          .from('conversation_participants')
          .select('''
            user_id,
            profiles!user_id (
              id,
              username,
              display_name,
              avatar_url
            )
          ''')
          .eq('conversation_id', convId)
          .neq('user_id', userId)
          .maybeSingle();

      if (other == null) continue;

      final profile = other['profiles'] as Map<String, dynamic>;

      // Unread count (correct syntax)
      final unreadResponse = await _supabase
          .from('messages')
          .count(CountOption.exact)
          .eq('conversation_id', convId)
          .neq('sender_id', userId)
          .filter('read_at', 'is', null);

      result.add({
        'conversation_id': convId,
        'last_message': convData['last_message'] ?? '',
        'last_message_time': convData['last_message_time'],
        'other_user_id': profile['id'],
        'other_username': profile['username'],
        'other_display_name': profile['display_name'] ?? profile['username'],
        'other_avatar_url': profile['avatar_url'],
        'unread_count': unreadResponse,
      });
    }

    // Optional: sort by last_message_time descending
    result.sort((a, b) {
      final t1 = a['last_message_time'] as String?;
      final t2 = b['last_message_time'] as String?;
      if (t1 == null) return 1;
      if (t2 == null) return -1;
      return DateTime.parse(t2).compareTo(DateTime.parse(t1));
    });

    return result;
  }

  // ─────────────────────────────────────────────
  // Messages
  // ─────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getMessages(String conversationId) async {
    final userId = _supabase.auth.currentUser!.id;

    // Mark as read
    await _supabase
        .from('messages')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('conversation_id', conversationId)
        .neq('sender_id', userId)
        .filter('read_at', 'is', null);

    final response = await _supabase
        .from('messages')
        .select('*, profiles!sender_id (username, display_name, avatar_url)')
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> sendMessage(String conversationId, String content) async {
    final userId = _supabase.auth.currentUser!.id;

    await _supabase.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': userId,
      'content': content,
    });

    await _supabase
        .from('conversations')
        .update({
          'last_message': content,
          'last_message_time': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', conversationId);
  }

  // ─────────────────────────────────────────────
  // Create / find conversation
  // ─────────────────────────────────────────────
  Future<String> createConversation(String otherUserId) async {
    final userId = _supabase.auth.currentUser!.id;

    // 1. Check if conversation already exists
    final existing = await _supabase
        .from('conversation_participants')
        .select('conversation_id')
        .eq('user_id', userId);

    for (final entry in existing) {
      final convId = entry['conversation_id'] as String;

      final other = await _supabase
          .from('conversation_participants')
          .select('user_id')
          .eq('conversation_id', convId)
          .eq('user_id', otherUserId)
          .maybeSingle();

      if (other != null) {
        await _supabase
            .from('conversations')
            .update({'updated_at': DateTime.now().toIso8601String()})
            .eq('id', convId);
        return convId;
      }
    }

    // 2. Create conversation + get the ID in one go
    //    We temporarily allow the insert to return the ID by using a
    //    more permissive approach or by using a database function.

    // Safer approach: use a Postgres function that creates everything atomically
    final response = await _supabase.rpc(
      'create_conversation',
      params: {'other_user_id': otherUserId},
    );

    return response as String;
  }

  // ─────────────────────────────────────────────
  // Realtime subscriptions (modern API)
  // ─────────────────────────────────────────────

  RealtimeChannel subscribeToMessages(
    String conversationId,
    void Function(Map<String, dynamic>) onNewMessage,
  ) {
    final channel = _supabase.channel('messages-$conversationId');

    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'conversation_id',
        value: conversationId,
      ),
      callback: (payload) {
        print('🔥 REALTIME MESSAGE RECEIVED: ${payload.newRecord}');

        final newMessage = Map<String, dynamic>.from(payload.newRecord);

        // Fetch sender profile
        _supabase
            .from('profiles')
            .select('username, display_name, avatar_url')
            .eq('id', newMessage['sender_id'])
            .maybeSingle()
            .then((profile) {
              if (profile != null) {
                newMessage['profiles'] = profile;
              }
              onNewMessage(newMessage);
            })
            .catchError((e) {
              print('Profile fetch error: $e');
              onNewMessage(newMessage);
            });
      },
    );

    channel.subscribe((status, [error]) {
      print('Realtime channel status → $status');
      if (error != null) print('Realtime error → $error');
    });

    return channel;
  }

  RealtimeChannel subscribeToConversationUpdates(void Function() onUpdate) {
    return _supabase
        .channel('conversation_updates')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'conversations',
          callback: (_) => onUpdate(),
        )
        .subscribe();
  }
}
