/*import 'package:supabase_flutter/supabase_flutter.dart';
import 'notification_service.dart';
import 'supabase_service.dart';

class MessageListenerService {
  static final MessageListenerService _instance =
      MessageListenerService._internal();
  factory MessageListenerService() => _instance;
  MessageListenerService._internal();

  final SupabaseService _supabaseService = SupabaseService();
  final NotificationService _notificationService = NotificationService();
  RealtimeChannel? _messageChannel;
  bool _isListening = false;

  Future<void> startListening(String userId) async {
    if (_isListening) {
      print('🔔 Message listener already running');
      return;
    }

    print('🔔 Starting message listener for user: $userId');

    try {
      // Initialize notifications
      await _notificationService.initialize();

      // Subscribe to new messages using the corrected method
      _messageChannel = _supabaseService.subscribeToNewMessagesWithFilter(
        userId,
        onMessageReceived: (payload) async {
          await _handleNewMessage(payload, userId);
        },
      );

      _messageChannel?.subscribe();
      _isListening = true;

      print('✅ Message listener started successfully');
    } catch (e) {
      print('❌ Error starting message listener: $e');
      _isListening = false;
    }
  }

  Future<void> _handleNewMessage(
    Map<String, dynamic> payload,
    String userId,
  ) async {
    try {
      final Map<String, dynamic>? newRecord = payload['newRecord'];
      if (newRecord == null) return;

      final receiverId = newRecord['receiver_id'] as String?;
      final senderId = newRecord['sender_id'] as String?;
      final content = newRecord['content'] as String?;
      final conversationId = newRecord['conversation_id'] as String?;

      // Verify this message is for the current user
      if (receiverId != userId || content == null || conversationId == null) {
        return;
      }

      print('📨 New message received: $content');

      // Get sender info
      final sender = await _supabaseService.getUserProfile(senderId!);
      final conversation = await _supabaseService.getConversation(
        conversationId,
      );

      String senderName = 'Utilisateur';
      String propertyTitle = 'Annonce';

      if (sender != null) {
        final firstName = sender['first_name'] as String?;
        final lastName = sender['last_name'] as String?;
        if (firstName != null && lastName != null) {
          senderName = '$firstName $lastName';
        } else if (firstName != null) {
          senderName = firstName;
        }
      }

      if (conversation != null) {
        final dynamic propertyData = conversation['property'];
        if (propertyData is Map<String, dynamic>) {
          propertyTitle = propertyData['title'] as String? ?? 'Annonce';
        } else if (propertyData is List && propertyData.isNotEmpty) {
          final firstProperty = propertyData.first as Map<String, dynamic>?;
          propertyTitle = firstProperty?['title'] as String? ?? 'Annonce';
        }
      }

      // Show notification
      await _notificationService.showMessageNotification(
        title: 'Nouveau message de $senderName',
        body: content.length > 50 ? '${content.substring(0, 50)}...' : content,
        conversationId: conversationId,
      );
    } catch (e) {
      print('❌ Error handling new message: $e');
    }
  }

  Future<void> stopListening() async {
    if (_messageChannel != null) {
      await _messageChannel?.unsubscribe();
      _messageChannel = null;
    }
    _isListening = false;
    print('🔕 Message listener stopped');
  }

  bool get isListening => _isListening;
}
*/
