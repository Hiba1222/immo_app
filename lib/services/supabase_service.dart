import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  SupabaseClient get client => _client;

  User? get currentUser => _client.auth.currentUser;

  Future<AuthResponse> signUp(String email, String password) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signIn(String email, String password) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> resetPassword(String email) async {
    try {
      print('🔄 Envoi de l\'email de réinitialisation à: $email');

      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'http://localhost:3000/auth/callback',
      );

      print('✅ Email de réinitialisation envoyé avec succès à: $email');
    } catch (e) {
      print('❌ Erreur lors de l\'envoi de l\'email de réinitialisation: $e');
      rethrow;
    }
  }

  // ADD THIS METHOD for auth state changes
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /*// NEW: Real-time subscription for new messages - CORRECTED VERSION
  RealtimeChannel subscribeToNewMessages(
    String userId, {
    required Function(Map<String, dynamic>) onMessageReceived,
  }) {
    final channel = _client.channel('user_messages_$userId');
    
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      callback: (payload) {
        final message = payload.newRecord;
        // Only notify if message is for this user
        if (message != null && message['receiver_id'] == userId) {
          // Convert the payload to a Map and call the callback
          final payloadMap = {
            'newRecord': message,
            'oldRecord': payload.oldRecord,
            'eventType': payload.eventType,
          };
          onMessageReceived(payloadMap);
        }
      },
    );
    
    return channel;
  }

  // Alternative version using filter (recommended)
  RealtimeChannel subscribeToNewMessagesWithFilter(
    String userId, {
    required Function(Map<String, dynamic>) onMessageReceived,
  }) {
    final channel = _client.channel('user_messages_$userId');
    
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'receiver_id',
        value: userId,
      ),
      callback: (payload) {
        final message = payload.newRecord;
        if (message != null) {
          final payloadMap = {
            'newRecord': message,
            'oldRecord': payload.oldRecord,
            'eventType': payload.eventType,
          };
          onMessageReceived(payloadMap);
        }
      },
    );
    
    return channel;
  }

  // Simple version that returns the channel for manual handling
  RealtimeChannel createMessageChannel(String userId) {
    return _client.channel('user_messages_$userId')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'receiver_id',
          value: userId,
        ),
        callback: (payload) {
          // Empty callback - let the caller handle the messages
          // This is useful if you want to use the channel's stream directly
        },
      );
  }

  // Even simpler version for basic use cases
  RealtimeChannel createBasicMessageChannel(String userId) {
    return _client.channel('user_messages_$userId')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        callback: (payload) {
          // Basic callback that does nothing
          // The actual handling will be done by the listener
        },
      );
  }

  // NEW: Get user profile
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      return response;
    } catch (e) {
      print('❌ Error getting user profile: $e');
      return null;
    }
  }

  // NEW: Get conversation with property info
  Future<Map<String, dynamic>?> getConversation(String conversationId) async {
    try {
      final response = await _client
          .from('conversations')
          .select('''
            *,
            property:properties(title)
          ''')
          .eq('id', conversationId)
          .single();
      return response;
    } catch (e) {
      print('❌ Error getting conversation: $e');
      return null;
    }
  }

  // NEW: Alternative method using direct stream
  Stream<Map<String, dynamic>> getMessagesStream(String userId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('receiver_id', userId)
        .order('created_at', ascending: false)
        .map((List<Map<String, dynamic>> messages) {
          if (messages.isNotEmpty) {
            return messages.first;
          }
          return {};
        });
  }*/
}
