import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'presentation/pages/auth/login_page.dart';
import 'presentation/pages/home/home_page.dart';
import 'presentation/providers/user_provider.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    
    return authState.when(
      loading: () => const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('Vérification de la session...'),
            ],
          ),
        ),
      ),
      error: (error, stack) {
        print('❌ [App] Auth state error: $error');
        return const LoginPage();
      },
      data: (authState) {
        final user = authState.session?.user;
        print('🔄 [App] Auth state changed - User: ${user?.email}');
        
        if (user != null) {
          print('✅ [App] User authenticated: ${user.email}');
          return const HomePage();
        } else {
          print('🚪 [App] No user, showing login');
          return const LoginPage();
        }
      },
    );
  }
}