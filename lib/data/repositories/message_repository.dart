import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/message_model.dart';

class MessageRepository {
  final SupabaseClient _supabase;

  MessageRepository(this._supabase);

  Future<List<Message>> getMessages(String conversationId, String currentUserId) async {
    try {
      print('📨 Getting messages for conversation: $conversationId');
      
      final response = await _supabase
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      print('📨 Found ${response.length} messages');

      if (response.isEmpty) {
        return [];
      }

      return response.map((msg) {
        return Message.fromJson({
          ...msg,
          'is_sent_by_me': msg['sender_id'] == currentUserId,
        });
      }).toList();
    } catch (e) {
      print('❌ Error fetching messages: $e');
      rethrow;
    }
  }

  Future<Message> sendMessage({
    required String conversationId,
    required String senderId,
    required String content,
  }) async {
    try {
      print('📤 Sending message to conversation: $conversationId');
      
      // Get conversation to determine receiver
      final conversationResponse = await _supabase
          .from('conversations')
          .select('buyer_id, seller_id')
          .eq('id', conversationId)
          .single();

      if (conversationResponse.isEmpty) {
        throw Exception('Conversation not found');
      }

      final buyerId = conversationResponse['buyer_id'] as String;
      final sellerId = conversationResponse['seller_id'] as String;
      
      // Determine receiver
      final receiverId = senderId == buyerId ? sellerId : buyerId;

      print('📤 Message details:');
      print('   Sender: $senderId');
      print('   Receiver: $receiverId');
      print('   Content: $content');

      // Send the message
      final response = await _supabase
          .from('messages')
          .insert({
            'conversation_id': conversationId,
            'sender_id': senderId,
            'receiver_id': receiverId,
            'content': content,
          })
          .select();

      if (response.isEmpty) {
        throw Exception('Failed to send message: No response from server');
      }

      final messageData = response.first;
      print('✅ Message sent successfully: ${messageData['id']}');

      // Update conversation updated_at - use proper timestamp
      await _supabase
          .from('conversations')
          .update({'updated_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', conversationId);

      print('✅ Conversation updated_at refreshed');

      return Message.fromJson({
        ...messageData,
        'is_sent_by_me': true,
      });
    } catch (e) {
      print('❌ Error sending message: $e');
      rethrow;
    }
  }

  Stream<List<Message>> messageStream(String conversationId, String currentUserId) {
    print('🔗 Starting message stream for: $conversationId');
    
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true)
        .map((messages) {
          print('🔄 Stream update: ${messages.length} messages');
          return messages.map((msg) {
            return Message.fromJson({
              ...msg,
              'is_sent_by_me': msg['sender_id'] == currentUserId,
            });
          }).toList();
        });
  }
}