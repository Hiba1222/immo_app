import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/property_repository.dart';
import '../../data/models/property_model.dart';
import '../../presentation/providers/supabase_service_provider.dart';
import '../../services/supabase_service.dart';

// FIXED: Use propertyRepoProvider instead of creating a new one
final propertyRepositoryProvider = Provider<PropertyRepository>((ref) {
  final supabaseService = ref.read(supabaseServiceProvider);
  return PropertyRepository(supabaseService);
});

// Provider principal pour toutes les propriétés
final propertiesProvider = FutureProvider<List<Property>>((ref) async {
  final repository = ref.read(propertyRepositoryProvider);
  return await repository.getProperties(limit: 50);
});

// Provider pour les propriétés filtrées - FIXED
final filteredPropertiesProvider = FutureProvider<List<Property>>((ref) {
  final searchState = ref.watch(propertySearchProvider);
  final allProperties = ref.watch(propertiesProvider);

  return allProperties.when(
    data: (properties) {
      // Si pas de recherche active, retourner toutes les propriétés
      if (searchState.query.isEmpty && searchState.filters.isEmpty) {
        return properties;
      }

      // Si recherche active, utiliser les résultats de recherche
      return searchState.results;
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

final userPropertiesProvider = FutureProvider.family<List<Property>, String>((
  ref,
  userId,
) async {
  final repository = ref.read(propertyRepositoryProvider);
  return await repository.getPropertiesByUser(userId);
});

final favoritePropertiesProvider =
    FutureProvider.family<List<Property>, String>((ref, userId) async {
      final repository = ref.read(propertyRepositoryProvider);
      return await repository.getFavoriteProperties(userId);
    });

final propertiesStatsProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) async {
  final repository = ref.read(propertyRepositoryProvider);
  return await repository.getPropertiesStats();
});

// État de recherche avec filtres
class SearchState {
  final List<Property> results;
  final String query;
  final Map<String, dynamic> filters;

  const SearchState({
    this.results = const [],
    this.query = '',
    this.filters = const {},
  });

  SearchState copyWith({
    List<Property>? results,
    String? query,
    Map<String, dynamic>? filters,
  }) {
    return SearchState(
      results: results ?? this.results,
      query: query ?? this.query,
      filters: filters ?? this.filters,
    );
  }
}

// Provider pour la recherche avec état complet - CORRECTED TYPE
final propertySearchProvider =
    StateNotifierProvider<PropertySearchNotifier, SearchState>((ref) {
      return PropertySearchNotifier(ref.read(propertyRepositoryProvider));
    });

class PropertySearchNotifier extends StateNotifier<SearchState> {
  final PropertyRepository _repository;

  PropertySearchNotifier(this._repository) : super(const SearchState());

  Future<void> searchProperties({
    String? query,
    String? city,
    double? minPrice,
    double? maxPrice,
    String? propertyType,
    String? transactionType,
    int? minRooms,
    int? minBedrooms,
  }) async {
    try {
      print('🔍 [PropertySearch] Début recherche...');
      final results = await _repository.searchProperties(
        query: query,
        city: city,
        minPrice: minPrice,
        maxPrice: maxPrice,
        propertyType: propertyType,
        transactionType: transactionType,
        minRooms: minRooms,
        minBedrooms: minBedrooms,
      );

      final filters = <String, dynamic>{};
      if (query != null && query.isNotEmpty) filters['query'] = query;
      if (city != null && city.isNotEmpty) filters['city'] = city;
      if (minPrice != null) filters['minPrice'] = minPrice;
      if (maxPrice != null) filters['maxPrice'] = maxPrice;
      if (propertyType != null) filters['propertyType'] = propertyType;
      if (transactionType != null) filters['transactionType'] = transactionType;
      if (minRooms != null) filters['minRooms'] = minRooms;
      if (minBedrooms != null) filters['minBedrooms'] = minBedrooms;

      state = SearchState(
        results: results,
        query: query ?? '',
        filters: filters,
      );

      print(
        '✅ [PropertySearch] Recherche terminée: ${results.length} résultats',
      );
    } catch (e) {
      print('❌ [PropertySearch] Erreur recherche: $e');
      state = const SearchState(results: []);
    }
  }

  void clearSearch() {
    print('🗑️ [PropertySearch] Nettoyage recherche');
    state = const SearchState();
  }

  void setQuery(String query) {
    state = state.copyWith(query: query);
  }
}

// Provider pour les favoris
final favoritesManagerProvider =
    StateNotifierProvider<FavoritesManager, Map<String, bool>>((ref) {
      return FavoritesManager(ref);
    });

class FavoritesManager extends StateNotifier<Map<String, bool>> {
  final Ref ref;

  FavoritesManager(this.ref) : super({});

  Future<void> toggleFavorite(String propertyId) async {
    try {
      final repository = ref.read(propertyRepositoryProvider);
      final supabaseService = SupabaseService();
      final user = supabaseService.currentUser;

      if (user == null) {
        print('❌ No user logged in');
        return;
      }

      final isCurrentlyFavorite = state[propertyId] ?? false;

      print('🔄 Toggling favorite for property: $propertyId');
      print('   Current state: $isCurrentlyFavorite');
      print('   User: ${user.id}');

      // Optimistically update UI
      state = {...state, propertyId: !isCurrentlyFavorite};

      bool success;
      if (isCurrentlyFavorite) {
        // Remove from favorites
        success = await repository.removeFromFavorites(user.id, propertyId);
      } else {
        // Add to favorites
        success = await repository.addToFavorites(user.id, propertyId);
      }

      if (!success) {
        // Revert if failed
        state = {...state, propertyId: isCurrentlyFavorite};
        print('❌ Failed to update favorites for property: $propertyId');
      } else {
        print('✅ Successfully updated favorites for property: $propertyId');
        print('   New state: ${!isCurrentlyFavorite}');
      }

      // Refresh favorites list
      ref.invalidate(favoritePropertiesProvider(user.id));
    } catch (e) {
      print('❌ Error in toggleFavorite: $e');
      // Revert on error
      final isCurrentlyFavorite = state[propertyId] ?? false;
      state = {...state, propertyId: isCurrentlyFavorite};
    }
  }

  // Load initial favorites state - FIXED: Use getFavoriteProperties instead of getUserFavorites
  Future<void> loadFavorites(String userId) async {
    try {
      final repository = ref.read(propertyRepositoryProvider);
      final favorites = await repository.getFavoriteProperties(userId);

      final favoritesMap = <String, bool>{};
      for (final property in favorites) {
        favoritesMap[property.id] = true;
      }

      state = favoritesMap;
      print('✅ Loaded ${favorites.length} favorites for user: $userId');
    } catch (e) {
      print('❌ Error loading favorites: $e');
    }
  }

  // Add this method to initialize favorites when user logs in
  void initializeFavorites(String userId) {
    loadFavorites(userId);
  }
}
