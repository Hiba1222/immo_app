# Immo App 🏠

Une application immobilière moderne développée avec Flutter pour parcourir, rechercher et gérer des annonces de biens immobiliers.

## 📱 À propos

Immo App est une application mobile construite avec Flutter qui offre une plateforme complète pour la gestion de biens immobiliers. Que vous cherchiez à acheter, louer ou mettre en vente des propriétés, cette application propose une interface intuitive pour parcourir les annonces disponibles avec des informations détaillées et des images.

## ✨ Fonctionnalités

- **Liste de biens** : Parcourez une liste complète de propriétés disponibles
- **Recherche avancée** : Filtrez les biens par localisation, prix, type et autres critères
- **Gestion des annonces** : Créez, modifiez et supprimez vos propres annonces (CRUD)
- **Détails des biens** : Consultez des informations détaillées incluant photos, équipements et caractéristiques
- **Authentification sécurisée** : Système de connexion et d'inscription pour les utilisateurs
- **Cartes interactives** : Visualisez l'emplacement des biens sur Google Maps avec géolocalisation
- **Chat en temps réel** : Communiquez directement avec les propriétaires ou agents
- **Design responsive** : Optimisé pour différentes tailles d'écran et appareils

## 🏗️ Architecture

L'application suit une architecture en couches basée sur le modèle C4, avec une séparation claire des responsabilités :
![Image](https://github.com/Hiba1222/immo_app/conception C4.png)
### Niveau C4 - Code (Couche Services)
**Composants métier**
- **AdService** : Logique métier pour la validation, gestion d'état et orchestration des annonces
- **AdRepository** : Couche d'abstraction pour les opérations CRUD avec gestion des requêtes
- **AdModel** : Modèle de données (titre, description, prix, coordonnées GPS)
- **Supabase Client** : Client Flutter pour l'interaction avec le backend

### Niveau C3 - Composants (Couche Métier)
**Modules fonctionnels**
- **Composant Annonces** : Gestion complète du CRUD des annonces avec gestion d'état (Bloc/Riverpod)
- **Composant Recherche & Filtrage** : Traitement des requêtes complexes et filtres multiples
- **Composant Gestion des Annonces** : Interface CRUD pour les annonces de l'utilisateur connecté
- **Service d'Authentification** : Gestion de la connexion et inscription des utilisateurs
- **Composant Cartographie** : Intégration de Google Maps pour l'affichage et la géolocalisation
- **Composant Chat** : Messagerie en temps réel entre utilisateurs

### Niveau C2 - Conteneurs (Couche Infrastructure)
**Systèmes et bases de données**
- **Application Mobile (Flutter)** : Interface utilisateur avec logique de présentation
- **Supabase Database (PostgreSQL)** : Stockage des annonces, profils utilisateurs, transactions avec Row Level Security (RLS)
- **Supabase Storage (S3-compatible)** : Gestion et stockage des photos et vidéos des biens
- **Supabase Auth** : Système d'authentification et gestion des sessions
- **Google Maps API** : Services web pour l'affichage des cartes et la géolocalisation

### Niveau C1 - Contexte (Systèmes Externes)
**Acteurs et systèmes externes**
- **Utilisateur Particulier** : Utilise l'application mobile pour rechercher, publier et gérer des annonces
- **Google Maps Platform** : Système externe pour l'affichage des cartes et services de géolocalisation
- **Supabase** : Backend as a Service pour l'authentification, base de données, stockage et temps réel

## 🚀 Démarrage

### Prérequis

Avant de commencer, assurez-vous d'avoir installé :
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (version 3.0 ou supérieure)
- [Dart SDK](https://dart.dev/get-dart) (inclus avec Flutter)
- Android Studio / VS Code avec les extensions Flutter
- Un émulateur ou un appareil physique pour les tests
- Un compte [Supabase](https://supabase.com/) pour le backend
- Une clé API [Google Maps](https://developers.google.com/maps)

### Configuration

1. **Cloner le dépôt**
   ```bash
   git clone https://github.com/Hiba1222/immo_app.git
   cd immo_app
   ```

2. **Installer les dépendances**
   ```bash
   flutter pub get
   ```

3. **Configuration Supabase**
   - Créez un projet sur [Supabase](https://supabase.com/)
   - Récupérez votre URL et clé API
   - Créez un fichier `.env` à la racine du projet :
   ```env
   SUPABASE_URL=votre_url_supabase
   SUPABASE_ANON_KEY=votre_cle_anonyme
   ```

4. **Configuration Google Maps**
   - Obtenez une clé API Google Maps
   - Ajoutez-la dans les fichiers de configuration :
     - **Android** : `android/app/src/main/AndroidManifest.xml`
     - **iOS** : `ios/Runner/AppDelegate.swift`

5. **Lancer l'application**
   ```bash
   flutter run
   ```

## 📂 Structure du projet

```
immo_app/
├── android/                # Fichiers spécifiques Android
├── ios/                    # Fichiers spécifiques iOS
├── lib/                    # Code principal de l'application
│   ├── models/            # Modèles de données (AdModel, UserModel, etc.)
│   ├── screens/           # Écrans de l'interface utilisateur
│   │   ├── home_screen.dart
│   │   ├── ad_detail_screen.dart
│   │   ├── search_screen.dart
│   │   └── profile_screen.dart
│   ├── widgets/           # Widgets réutilisables
│   ├── services/          # Logique métier (AdService, AuthService)
│   ├── repositories/      # Couche d'abstraction données (AdRepository)
│   ├── providers/         # Gestion d'état (Bloc/Riverpod)
│   └── main.dart          # Point d'entrée de l'application
├── test/                   # Tests unitaires et de widgets
├── assets/                 # Images, polices et autres ressources
├── .env                    # Variables d'environnement (à créer)
└── pubspec.yaml           # Dépendances du projet
```

## 🛠️ Technologies utilisées

- **[Flutter](https://flutter.dev/)** - Framework d'interface utilisateur multiplateforme
- **[Dart](https://dart.dev/)** - Langage de programmation
- **[Supabase](https://supabase.com/)** - Backend as a Service
  - PostgreSQL pour la base de données
  - Storage pour les fichiers média
  - Auth pour l'authentification
  - Realtime pour le chat en temps réel
- **[Google Maps API](https://developers.google.com/maps)** - Cartographie et géolocalisation
- **Bloc/Riverpod** - Gestion d'état de l'application
- **supabase_flutter** - Client officiel Supabase pour Flutter
- **google_maps_flutter** - Plugin Flutter pour Google Maps

## 📱 Captures d'écran

<!-- Ajoutez vos captures d'écran ici -->
```
[Écran d'accueil] [Liste des annonces] [Détails d'une annonce] [Carte interactive]
```

## 🧪 Tests

Exécuter la suite de tests :
```bash
flutter test
```

Pour les tests d'intégration :
```bash
flutter test integration_test
```

## 📦 Compilation pour la production

### Android (APK)
```bash
flutter build apk --release
```

### Android (App Bundle)
```bash
flutter build appbundle --release
```

### iOS
```bash
flutter build ios --release
```

## 🔐 Sécurité

- Authentification gérée par Supabase Auth
- Row Level Security (RLS) activé sur toutes les tables
- Validation des données côté client et serveur
- Stockage sécurisé des tokens d'authentification
- HTTPS pour toutes les communications

## 🤝 Contribution

Les contributions sont les bienvenues ! Pour contribuer :

1. Forkez le projet
2. Créez votre branche de fonctionnalité (`git checkout -b feature/NouvelleFonctionnalite`)
3. Committez vos changements (`git commit -m 'Ajout d'une nouvelle fonctionnalité'`)
4. Poussez vers la branche (`git push origin feature/NouvelleFonctionnalite`)
5. Ouvrez une Pull Request

### Convention de code
- Suivez les conventions de style Dart
- Utilisez `flutter analyze` avant de commiter
- Ajoutez des tests pour les nouvelles fonctionnalités
- Documentez les fonctions publiques

## 📄 Licence

Ce projet est sous licence MIT - voir le fichier [LICENSE](LICENSE) pour plus de détails.

## 👤 Auteur

**Hiba**
- GitHub: [@Hiba1222](https://github.com/Hiba1222)

## 📞 Support

Si vous rencontrez des problèmes ou avez des questions :
- Ouvrez une [issue](https://github.com/Hiba1222/immo_app/issues)
- Consultez la [documentation Flutter](https://docs.flutter.dev/)
- Consultez la [documentation Supabase](https://supabase.com/docs)

## 🙏 Remerciements

- L'équipe Flutter pour ce framework incroyable
- Supabase pour la solution backend
- Google Maps Platform pour les services de cartographie
- Tous les contributeurs qui aident à améliorer ce projet

## 🗺️ Roadmap

- [ ] Notifications push pour les nouvelles annonces
- [ ] Système de favoris synchronisé
- [ ] Comparateur de biens
- [ ] Mode sombre
- [ ] Support multilingue
- [ ] Intégration de paiement
- [ ] Statistiques pour les agents immobiliers

---

Fait avec ❤️ en utilisant Flutter et Supabase
