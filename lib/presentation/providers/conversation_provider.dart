import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/conversation_model.dart';
import '../../data/repositories/conversation_repository.dart';
import '../../services/supabase_service.dart';

final conversationRepositoryProvider = Provider<ConversationRepository>((ref) {
  final supabase = SupabaseService().client;
  return ConversationRepository(supabase);
});

final conversationsProvider = FutureProvider<List<Conversation>>((ref) async {
  final repository = ref.read(conversationRepositoryProvider);
  final currentUser = SupabaseService().currentUser;

  print('🔄 [Provider] Fetching conversations for user: ${currentUser?.id}');

  if (currentUser == null) {
    print('❌ [Provider] No current user found');
    return [];
  }

  try {
    // Add auto-refresh trigger when auth state changes
    ref.watch(authStateProvider); // This will refresh when auth changes
    
    final conversations = await repository.getUserConversations(currentUser.id);
    print('✅ [Provider] Loaded ${conversations.length} conversations');
    
    // Debug: Print each conversation
    for (var i = 0; i < conversations.length; i++) {
      final conv = conversations[i];
      print('   📝 Conversation $i: ${conv.id} - ${conv.otherUserName} - ${conv.propertyTitle}');
    }
    
    return conversations;
  } catch (error, stack) {
    print('❌ [Provider] Error loading conversations: $error');
    print('Stack: $stack');
    rethrow;
  }
});

// Add this provider for auth state changes
final authStateProvider = StreamProvider<AuthState>((ref) {
  final supabaseService = SupabaseService();
  return supabaseService.authStateChanges;
});

final conversationProvider = StateNotifierProvider<ConversationNotifier, AsyncValue<List<Conversation>>>((ref) {
  final repository = ref.read(conversationRepositoryProvider);
  return ConversationNotifier(repository);
});

class ConversationNotifier extends StateNotifier<AsyncValue<List<Conversation>>> {
  final ConversationRepository _repository;
  
  ConversationNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadConversations();
  }
  
  Future<void> loadConversations() async {
    state = const AsyncValue.loading();
    try {
      final currentUser = SupabaseService().currentUser;
      if (currentUser == null) {
        state = const AsyncValue.data([]);
        return;
      }
      
      final conversations = await _repository.getUserConversations(currentUser.id);
      state = AsyncValue.data(conversations);
    } catch (error) {
      state = AsyncValue.error(error, StackTrace.current);
    }
  }
  
  Future<void> refreshConversations() async {
    await loadConversations();
  }
}