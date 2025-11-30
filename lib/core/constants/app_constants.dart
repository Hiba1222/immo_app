class AppConstants {
  // Supabase Configuration - À REMPLACER AVEC VOS VRAIES CLÉS
  static const String supabaseUrl = 'https://url.supabase.co';
  static const String supabaseAnonKey = 'TOKEN-CODE';
  
  // Google Maps Configuration - À REMPLACER AVEC VRAIE CLÉ
  static const String googleMapsApiKey = 'TOKEN-CODE';
  
  // Routes de l'application
  static const String splashRoute = '/';
  static const String loginRoute = '/login';
  static const String registerRoute = '/register';
  static const String homeRoute = '/home';
  static const String searchRoute = '/search';
  static const String mapRoute = '/map';
  static const String favoritesRoute = '/favorites';
  static const String profileRoute = '/profile';
  
  // Messages d'erreur
  static const String connectionError = 'Erreur de connexion';
  static const String invalidCredentials = 'Email ou mot de passe incorrect';
}
