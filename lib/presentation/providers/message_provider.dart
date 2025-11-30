import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/message_model.dart';
import '../../data/repositories/message_repository.dart';
import '../../services/supabase_service.dart';

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  final supabase = SupabaseService().client;
  return MessageRepository(supabase);
});

final messagesProvider = StreamProvider.family<List<Message>, String>((ref, conversationId) {
  final repository = ref.read(messageRepositoryProvider);
  final currentUser = SupabaseService().currentUser;
  
  print('🔗 [Provider] Setting up stream for conversation: $conversationId');
  
  if (currentUser == null) {
    print('❌ [Provider] No current user for stream');
    return const Stream.empty();
  }
  
  return repository.messageStream(conversationId, currentUser.id);
});

final messageNotifierProvider = StateNotifierProvider.family<MessageNotifier, AsyncValue<List<Message>>, String>((ref, conversationId) {
  final repository = ref.read(messageRepositoryProvider);
  return MessageNotifier(repository, conversationId);
});

class MessageNotifier extends StateNotifier<AsyncValue<List<Message>>> {
  final MessageRepository _repository;
  final String conversationId;
  
  MessageNotifier(this._repository, this.conversationId) : super(const AsyncValue.loading()) {
    _loadMessages();
  }
  
  Future<void> _loadMessages() async {
    print('🔄 [Notifier] Loading messages for: $conversationId');
    state = const AsyncValue.loading();
    try {
      final currentUser = SupabaseService().currentUser;
      if (currentUser == null) {
        print('❌ [Notifier] No current user');
        state = const AsyncValue.data([]);
        return;
      }
      
      final messages = await _repository.getMessages(conversationId, currentUser.id);
      print('✅ [Notifier] Loaded ${messages.length} messages');
      state = AsyncValue.data(messages);
    } catch (error) {
      print('❌ [Notifier] Error loading messages: $error');
      state = AsyncValue.error(error, StackTrace.current);
    }
  }
  
  Future<void> sendMessage(String content) async {
    print('📤 [Notifier] Sending message: $content');
    try {
      final currentUser = SupabaseService().currentUser;
      if (currentUser == null) {
        throw Exception('No user logged in');
      }
      
      await _repository.sendMessage(
        conversationId: conversationId,
        senderId: currentUser.id,
        content: content,
      );
      
      print('✅ [Notifier] Message sent successfully');
      // Refresh messages after sending
      await _loadMessages();
      
    } catch (error) {
      print('❌ [Notifier] Error sending message: $error');
      rethrow;
    }
  }
  
  void updateMessages(List<Message> messages) {
    state = AsyncValue.data(messages);
  }
}