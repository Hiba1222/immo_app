import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/supabase_service.dart';

final supabaseServiceProvider = Provider<SupabaseService>((ref) {
  final service = SupabaseService();
  print('🔧 [Provider] Creating SupabaseService instance');
  return service;
});

// Remove this provider since Supabase is already initialized in main.dart
// final supabaseInitializationProvider = FutureProvider<void>((ref) async {
//   final service = ref.read(supabaseServiceProvider);
//   print('🔧 [Provider] Initializing SupabaseService...');
//   await service.initialize();
//   print('✅ [Provider] SupabaseService initialized');
// });

// Instead, create a simple initialization check provider
final supabaseInitializationProvider = FutureProvider<void>((ref) async {
  // Since Supabase is already initialized in main.dart,
  // we just need to verify it's working
  final service = ref.read(supabaseServiceProvider);
  print('🔧 [Provider] Checking Supabase initialization...');
  
  // Test the connection by getting the current user
  final user = service.currentUser;
  print('✅ [Provider] Supabase check complete - User: ${user?.email}');
});