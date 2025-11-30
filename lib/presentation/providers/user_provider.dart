import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/models/user_model.dart';
import '../../services/supabase_service.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

// Provider for current auth state
final authStateProvider = StreamProvider<AuthState>((ref) {
  final supabaseService = SupabaseService();
  return supabaseService.authStateChanges;
});

// Provider for current user
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.valueOrNull?.session?.user;
});

// Provider for user profile
final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final user = ref.watch(currentUserProvider);
  final repository = ref.read(userRepositoryProvider);
  
  if (user == null) return null;
  
  try {
    print('👤 [Provider] Fetching profile for user: ${user.id}');
    final userProfile = await repository.getUserProfile(user.id);
    print('✅ [Provider] Profile loaded: ${userProfile?.displayName}');
    return userProfile;
  } catch (e) {
    print('❌ [Provider] Error loading profile: $e');
    return null;
  }
});