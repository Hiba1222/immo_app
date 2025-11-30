import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';

class ConversationRepository {
  final SupabaseClient _supabase;

  ConversationRepository(this._supabase);

  // In getUserConversations method, replace the complex logic with this simpler approach:

Future<List<Conversation>> getUserConversations(String userId) async {
  try {
    print('🔄 [Repository] Fetching conversations for user: $userId');
    
    final conversationsResponse = await _supabase
        .from('conversations')
        .select()
        .or('buyer_id.eq.$userId,seller_id.eq.$userId')
        .order('updated_at', ascending: false);

    print('📊 [Repository] Found ${conversationsResponse.length} conversations');

    // Get all user IDs first for batch profile fetching
    final allUserIds = <String>{};
    for (final conv in conversationsResponse) {
      final buyerId = conv['buyer_id'] as String? ?? '';
      final sellerId = conv['seller_id'] as String? ?? '';
      if (buyerId.isNotEmpty) allUserIds.add(buyerId);
      if (sellerId.isNotEmpty) allUserIds.add(sellerId);
    }

    // Fetch all profiles in one batch
    final profilesResponse = allUserIds.isNotEmpty
        ? await _supabase
            .from('profiles')
            .select('id, email, first_name, last_name, avatar_url')
            .inFilter('id', allUserIds.toList())
        : [];

    // Create profiles map
    final profilesMap = <String, Map<String, dynamic>>{};
    for (var profile in profilesResponse) {
      final id = profile['id'] as String?;
      if (id != null) {
        profilesMap[id] = profile;
        print('📋 Loaded profile: $id - ${profile['email']} - ${profile['first_name']} ${profile['last_name']}');
      }
    }

    final conversations = <Conversation>[];
    
    for (final conv in conversationsResponse) {
      try {
        final conversationId = conv['id'] as String? ?? '';
        final propertyId = conv['property_id'] as String? ?? '';
        final buyerId = conv['buyer_id'] as String? ?? '';
        final sellerId = conv['seller_id'] as String? ?? '';
        
        if (conversationId.isEmpty) continue;

        // Determine which name to show
        String otherUserId;
        if (userId == buyerId) {
          otherUserId = sellerId; // Show the seller
        } else {
          otherUserId = buyerId; // Show the buyer
        }

        print('👥 Conversation $conversationId:');
        print('   Current User: $userId');
        print('   Buyer: $buyerId (${profilesMap[buyerId]?['email']})');
        print('   Seller: $sellerId (${profilesMap[sellerId]?['email']})');
        print('   Showing Other User: $otherUserId');

        // Get other user's profile from the map
        String otherUserName = 'Utilisateur';
        String? otherUserAvatar;
        
        final otherUserProfile = profilesMap[otherUserId];
        if (otherUserProfile != null) {
          final firstName = otherUserProfile['first_name'] as String? ?? '';
          final lastName = otherUserProfile['last_name'] as String? ?? '';
          final email = otherUserProfile['email'] as String? ?? '';
          
          otherUserName = '$firstName $lastName'.trim();
          if (otherUserName.isEmpty) {
            otherUserName = email.split('@').first;
          }
          if (otherUserName.isEmpty) {
            otherUserName = 'Utilisateur';
          }
          otherUserAvatar = otherUserProfile['avatar_url'];
          
          print('✅ Using profile: $otherUserName ($otherUserId)');
        } else {
          print('❌ Profile not found in map for: $otherUserId');
          print('   Available profiles: ${profilesMap.keys.toList()}');
        }

        // Get property title
        String propertyTitle = 'Annonce';
        if (propertyId.isNotEmpty) {
          final propertyResponse = await _supabase
              .from('properties')
              .select('title')
              .eq('id', propertyId)
              .maybeSingle();
          
          propertyTitle = propertyResponse?['title'] ?? 'Annonce';
        }

        // Get last message
        Message? lastMessage;
        final lastMessageResponse = await _supabase
            .from('messages')
            .select('id, content, created_at, sender_id, receiver_id')
            .eq('conversation_id', conversationId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (lastMessageResponse != null) {
          lastMessage = Message.fromJson({
            ...lastMessageResponse,
            'is_sent_by_me': lastMessageResponse['sender_id'] == userId,
          });
        }

        conversations.add(Conversation.fromJson({
          'id': conversationId,
          'property_id': propertyId,
          'buyer_id': buyerId,
          'seller_id': sellerId,
          'created_at': conv['created_at'] ?? DateTime.now().toIso8601String(),
          'updated_at': conv['updated_at'] ?? DateTime.now().toIso8601String(),
          'property_title': propertyTitle,
          'other_user_name': otherUserName,
          'other_user_avatar': otherUserAvatar,
          'last_message': lastMessage?.toJson(),
        }));
        
      } catch (e) {
        print('❌ Error processing conversation: $e');
      }
    }

    print('✅ [Repository] Built ${conversations.length} conversations');
    return conversations;
  } catch (e) {
    print('❌ [Repository] Error fetching conversations: $e');
    rethrow;
  }
}

  Future<Conversation?> getOrCreateConversation({
  required String propertyId,
  required String buyerId,
  required String sellerId,
}) async {
  try {
    print('🔄 Creating conversation for property: $propertyId, buyer: $buyerId, seller: $sellerId');
    
    // First, ensure both users have profiles
    await _ensureProfileExists(buyerId);
    await _ensureProfileExists(sellerId);

    // Get the current user ID
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      throw Exception('No authenticated user');
    }
    final currentUserId = currentUser.id;
    print('👤 Current authenticated user: $currentUserId');

    // Check if conversation already exists
    final existingResponse = await _supabase
        .from('conversations')
        .select()
        .eq('property_id', propertyId)
        .eq('buyer_id', buyerId)
        .eq('seller_id', sellerId)
        .maybeSingle();

    if (existingResponse != null) {
      print('✅ Found existing conversation');
      // FIX: Pass the current user ID, not just buyerId
      return await _enrichConversationWithData(existingResponse, currentUserId);
    }

    print('🆕 Creating new conversation...');
    // Create new conversation
    final newResponse = await _supabase
        .from('conversations')
        .insert({
          'property_id': propertyId,
          'buyer_id': buyerId,
          'seller_id': sellerId,
        })
        .select();

    // FIX: Check if response is not empty
    if (newResponse.isEmpty) {
      throw Exception('Failed to create conversation: No response from server');
    }

    print('✅ Conversation created successfully');
    // FIX: Pass the current user ID, not just buyerId
    return await _enrichConversationWithData(newResponse.first, currentUserId);
  } catch (e) {
    print('❌ Error creating conversation: $e');
    
    // If it's a foreign key error, try to create the missing profile
    if (e.toString().contains('violates foreign key constraint')) {
      print('🔧 Foreign key error detected, attempting to create missing profiles...');
      await _handleMissingProfiles(buyerId, sellerId);
      
      // Retry the conversation creation
      return await getOrCreateConversation(
        propertyId: propertyId,
        buyerId: buyerId,
        sellerId: sellerId,
      );
    }
    
    rethrow;
  }
}

  // Helper method to enrich conversation with related data
  // Helper method to enrich conversation with related data
Future<Conversation> _enrichConversationWithData(Map<String, dynamic> conversationData, String currentUserId) async {
  try {
    final conversationId = conversationData['id'] as String? ?? '';
    final propertyId = conversationData['property_id'] as String? ?? '';
    final buyerId = conversationData['buyer_id'] as String? ?? '';
    final sellerId = conversationData['seller_id'] as String? ?? '';

    // Get last message to determine context
    final lastMessageResponse = await _supabase
        .from('messages')
        .select('sender_id, receiver_id')
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    String otherUserId;
    if (lastMessageResponse != null) {
      final lastSenderId = lastMessageResponse['sender_id'] as String? ?? '';
      final lastReceiverId = lastMessageResponse['receiver_id'] as String? ?? '';
      
      if (lastSenderId == currentUserId) {
        otherUserId = lastReceiverId; // Current user was sender, show receiver
      } else {
        otherUserId = lastSenderId; // Current user was receiver, show sender
      }
    } else {
      // No messages, fall back to conversation roles
      otherUserId = currentUserId == buyerId ? sellerId : buyerId;
    }

    // ... rest of the method remains the same for fetching profile and property data
    String propertyTitle = 'Annonce';
    String otherUserName = 'Utilisateur';
    String? otherUserAvatar;

    // Fetch property data
    if (propertyId.isNotEmpty) {
      try {
        final propertyResponse = await _supabase
            .from('properties')
            .select('title')
            .eq('id', propertyId)
            .maybeSingle();
        propertyTitle = propertyResponse?['title'] ?? 'Annonce';
      } catch (e) {
        print('Error fetching property: $e');
      }
    }

    // Fetch user profile
    if (otherUserId.isNotEmpty) {
      try {
        final profileResponse = await _supabase
            .from('profiles')
            .select('email, first_name, last_name, avatar_url')
            .eq('id', otherUserId)
            .maybeSingle();

        if (profileResponse != null) {
          final firstName = profileResponse['first_name'] as String? ?? '';
          final lastName = profileResponse['last_name'] as String? ?? '';
          final email = profileResponse['email'] as String? ?? '';
          
          otherUserName = '$firstName $lastName'.trim();
          if (otherUserName.isEmpty) {
            otherUserName = email.split('@').first;
          }
          otherUserAvatar = profileResponse['avatar_url'];
        }
      } catch (e) {
        print('Error fetching profile: $e');
      }
    }

    return Conversation.fromJson({
      ...conversationData,
      'property_title': propertyTitle,
      'other_user_name': otherUserName,
      'other_user_avatar': otherUserAvatar,
    });
  } catch (e) {
    print('Error enriching conversation: $e');
    return Conversation.fromJson({
      ...conversationData,
      'property_title': 'Annonce',
      'other_user_name': 'Utilisateur',
    });
  }
}

  // Helper method to ensure a profile exists
  Future<void> _ensureProfileExists(String userId) async {
    try {
      final profileResponse = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (profileResponse == null) {
        // FIX: Use the current user's email or a fallback instead of admin API
        final currentUser = _supabase.auth.currentUser;
        final userEmail = currentUser?.email ?? '$userId@example.com';
        
        final insertResponse = await _supabase.from('profiles').insert({
          'id': userId,
          'email': userEmail,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).select();
        
        // FIX: Check if insert was successful
        if (insertResponse.isEmpty) {
          throw Exception('Failed to create profile for user: $userId');
        }
        
        print('✅ Profile created for user: $userId');
      }
    } catch (e) {
      print('❌ Error ensuring profile for user $userId: $e');
      // Don't rethrow - we'll try to continue anyway
    }
  }

  // Handle missing profiles for both buyer and seller
  Future<void> _handleMissingProfiles(String buyerId, String sellerId) async {
    try {
      await _ensureProfileExists(buyerId);
      await _ensureProfileExists(sellerId);
    } catch (e) {
      print('❌ Error handling missing profiles: $e');
    }
  }

  // Get conversation by ID with full details
  Future<Conversation> getConversationById(String conversationId, String currentUserId) async {
    try {
      final response = await _supabase
          .from('conversations')
          .select()
          .eq('id', conversationId)
          .single();

      return await _enrichConversationWithData(response, currentUserId);
    } catch (e) {
      print('Error fetching conversation by ID: $e');
      rethrow;
    }
  }
}