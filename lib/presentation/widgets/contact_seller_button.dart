import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/property_model.dart';
import '../../data/repositories/conversation_repository.dart';
import '../../services/supabase_service.dart';
import '../pages/messages/chat_page.dart';

class ContactSellerButton extends ConsumerWidget {
  final Property property;
  
  const ContactSellerButton({super.key, required this.property});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.chat),
      label: const Text('Contacter le vendeur'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      onPressed: () => _startConversation(context, ref),
    );
  }

  Future<void> _startConversation(BuildContext context, WidgetRef ref) async {
    final currentUser = SupabaseService().currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous devez être connecté pour envoyer un message')),
      );
      return;
    }

    if (currentUser.id == property.userId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous ne pouvez pas vous envoyer un message')),
      );
      return;
    }

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // First, ensure the current user has a profile
      await _ensureUserProfileExists(currentUser.id);
      
      final repository = ConversationRepository(SupabaseService().client);
      
      final conversation = await repository.getOrCreateConversation(
        propertyId: property.id,
        buyerId: currentUser.id,
        sellerId: property.userId,
      );

      // Close loading indicator
      if (context.mounted) {
        Navigator.pop(context);
      }

      if (conversation != null && context.mounted) {
        // Navigate to chat page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatPage(conversation: conversation),
          ),
        );
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur: Impossible de créer la conversation')),
        );
      }
    } catch (error) {
      print('Error starting conversation: $error');
      
      // Close loading indicator if still open
      if (context.mounted) {
        Navigator.pop(context);
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${error.toString()}'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _ensureUserProfileExists(String userId) async {
  try {
    final supabase = SupabaseService().client;
    
    // Check if profile exists
    final profileResponse = await supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    // If profile doesn't exist, create it
    if (profileResponse == null) {
      final user = SupabaseService().currentUser;
      if (user == null) {
        throw Exception('No authenticated user found');
      }

      final insertResponse = await supabase.from('profiles').insert({
        'id': userId,
        'email': user.email ?? '$userId@example.com', // FIX: Handle null email
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).select();
      
      if (insertResponse.isEmpty) {
        throw Exception('Failed to create profile: No response from server');
      }
      
      print('✅ Profile created for user: $userId');
    }
  } catch (e) {
    print('❌ Error ensuring profile exists: $e');
    rethrow;
  }
}
}