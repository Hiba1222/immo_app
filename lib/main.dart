import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'presentation/providers/supabase_service_provider.dart';
import 'services/message_listener_service.dart';
import 'services/notification_service.dart'; // ADD THIS IMPORT

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://bhtimfwyqjamwofyegjn.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJodGltZnd5cWphbXdvZnllZ2puIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQyODIzMDksImV4cCI6MjA3OTg1ODMwOX0.9WjZjoH9v24O4OyRmtdApxxcXqtSE5-cKqy1F8tSBUM',
  );

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  /*final _messageListener = MessageListenerService();*/
  /*final _notificationService = NotificationService();*/

  @override
  void initState() {
    super.initState();
    _setupAuthListener();
    /*_setupNotificationTapHandler();*/
  }

  void _setupAuthListener() {
    final supabase = Supabase.instance.client;

    // Listen for auth state changes
    supabase.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      print('🔐 Auth state changed: $event');

      if (event == AuthChangeEvent.signedIn && session != null) {
        // Start listening for messages when user signs in
        /*_messageListener.startListening(session.user.id);*/
        print('👤 User signed in: ${session.user.id}');
      } else if (event == AuthChangeEvent.signedOut) {
        // Stop listening when user signs out
        /*_messageListener.stopListening();*/
        print('👤 User signed out');
      } else if (event == AuthChangeEvent.tokenRefreshed && session != null) {
        // Restart listener if token refreshed
        /* _messageListener.startListening(session.user.id);*/
        print('🔄 Token refreshed, restarting listener');
      }
    });
  }

  @override
  void dispose() {
    /* _messageListener.stopListening();*/
    /*_notificationService.dispose();*/
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initializationAsync = ref.watch(supabaseInitializationProvider);

    return MaterialApp(
      title: 'Immo App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ),
      home: initializationAsync.when(
        loading: () => const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text('Initialisation de l\'application...'),
              ],
            ),
          ),
        ),
        error: (error, stack) => Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 50, color: Colors.red),
                const SizedBox(height: 20),
                const Text(
                  'Erreur d\'initialisation',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => ref.refresh(supabaseInitializationProvider),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
        data: (_) => const App(),
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
