class AppConstants {
  // Supabase Configuration - À REMPLACER AVEC VOS VRAIES CLÉS
  static const String supabaseUrl = 'https://bhtimfwyqjamwofyegjn.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJodGltZnd5cWphbXdvZnllZ2puIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQyODIzMDksImV4cCI6MjA3OTg1ODMwOX0.9WjZjoH9v24O4OyRmtdApxxcXqtSE5-cKqy1F8tSBUM';
  
  // Google Maps Configuration - À REMPLACER AVEC VRAIE CLÉ
  static const String googleMapsApiKey = 'AIzaSyBOZ4YdX399msLSnEkacCBUyHmHAHiO450';
  
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