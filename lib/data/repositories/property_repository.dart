import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/location_service.dart';
import '../../services/supabase_service.dart';
import '../models/property_model.dart';
import '../../presentation/providers/supabase_service_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Create a provider for PropertyRepository
final propertyRepoProvider = Provider<PropertyRepository>((ref) {
  final supabaseService = ref.read(supabaseServiceProvider);
  return PropertyRepository(supabaseService);
});

class PropertyRepository {
  final SupabaseService _supabaseService;

  PropertyRepository(this._supabaseService);

  // Get the Supabase client
  SupabaseClient get _supabase => _supabaseService.client;

  Future<List<Property>> getProperties({int limit = 10, int offset = 0}) async {
    try {
      print('🔄 [PropertyRepository] Début getProperties()');

      print('📡 [PropertyRepository] Exécution de la requête Supabase...');
      print('   📊 Limit: $limit, Offset: $offset');

      final response = await _supabase
          .from('properties')
          .select()
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      print('✅ [PropertyRepository] Réponse Supabase reçue');
      print('   📈 Nombre de propriétés: ${response.length}');

      // Debug: Print first property if available
      if (response.isNotEmpty) {
        print('🔍 [PropertyRepository] Première propriété:');
        print('   - ID: ${response[0]['id']}');
        print('   - Titre: ${response[0]['title']}');
        print('   - Ville: ${response[0]['city']}');
        print('   - Prix: ${response[0]['price']}');
        print('   - Type: ${response[0]['property_type']}');
        print('   - Transaction: ${response[0]['transaction_type']}');
        print('   - Images: ${response[0]['images']}');
      } else {
        print(
          '⚠️ [PropertyRepository] Aucune propriété trouvée dans la base de données',
        );
        print(
          '   💡 Vérifiez que vous avez des propriétés avec is_active = true',
        );
      }

      final List<Property> properties = [];
      for (final item in response) {
        try {
          final property = Property.fromJson(item);
          properties.add(property);
          print(
            '   🏠 Propriété chargée: ${property.title} - ${property.city} - ${property.formattedPrice}',
          );
        } catch (e) {
          print(
            '❌ [PropertyRepository] Erreur conversion Property.fromJson: $e',
          );
          print('   📋 Données problématiques: $item');
        }
      }

      print(
        '✅ [PropertyRepository] getProperties() terminé avec ${properties.length} propriétés',
      );
      return properties;
    } catch (e) {
      print('❌ [PropertyRepository] ERREUR CRITIQUE dans getProperties(): $e');
      print(
        '   🚨 Stack trace: ${e is Error ? e.stackTrace : 'Non disponible'}',
      );
      return [];
    }
  }

  Future<Property?> getPropertyById(String id) async {
    try {
      final response = await _supabase
          .from('properties')
          .select()
          .eq('id', id)
          .single();

      return Property.fromJson(response);
    } catch (e) {
      print('❌ Erreur lors de la récupération de la propriété: $e');
      return null;
    }
  }

  Future<List<Property>> getPropertiesByUser(String userId) async {
    try {
      final response = await _supabase
          .from('properties')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final List<Property> properties = [];
      for (final item in response) {
        properties.add(Property.fromJson(item));
      }
      return properties;
    } catch (e) {
      print('❌ Erreur lors de la récupération des propriétés utilisateur: $e');
      return [];
    }
  }

  Future<String?> createProperty(Property property) async {
    try {
      print('🔄 [PropertyRepository] Début createProperty()');
      print('   📝 Titre: ${property.title}');
      print('   🏙️ Ville: ${property.city}');
      print('   💰 Prix: ${property.price}');
      print('   🖼️ Images: ${property.images.length}');

      // Create data without ID for insert
      final propertyData = property.toJson();
      propertyData.remove('id'); // Remove the empty ID

      print('   📤 Envoi des données à Supabase...');

      final response = await _supabase
          .from('properties')
          .insert(propertyData)
          .select();

      if (response.isNotEmpty) {
        final propertyId = response[0]['id'];
        print('✅ [PropertyRepository] Propriété créée avec ID: $propertyId');
        return propertyId;
      } else {
        print('❌ [PropertyRepository] Aucune réponse après création');
        return null;
      }
    } catch (e) {
      print(
        '❌ [PropertyRepository] Erreur lors de la création de la propriété: $e',
      );
      return null;
    }
  }

  Future<bool> updateProperty(Property property) async {
    try {
      await _supabase
          .from('properties')
          .update(property.toJson())
          .eq('id', property.id);

      return true;
    } catch (e) {
      print('❌ Erreur lors de la mise à jour de la propriété: $e');
      return false;
    }
  }

  Future<bool> deleteProperty(String id) async {
    try {
      await _supabase.from('properties').delete().eq('id', id);

      return true;
    } catch (e) {
      print('❌ Erreur lors de la suppression de la propriété: $e');
      return false;
    }
  }

  // Recherche avec filtres
  Future<List<Property>> searchProperties({
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
      var request = _supabase.from('properties').select().eq('is_active', true);

      if (query != null && query.isNotEmpty) {
        request = request.ilike('title', '%$query%');
      }

      if (city != null && city.isNotEmpty) {
        request = request.ilike('city', '%$city%');
      }

      if (minPrice != null) {
        request = request.gte('price', minPrice);
      }

      if (maxPrice != null) {
        request = request.lte('price', maxPrice);
      }

      if (propertyType != null && propertyType.isNotEmpty) {
        request = request.eq('property_type', propertyType);
      }

      if (transactionType != null && transactionType.isNotEmpty) {
        request = request.eq('transaction_type', transactionType);
      }

      if (minRooms != null) {
        request = request.gte('rooms', minRooms);
      }

      if (minBedrooms != null) {
        request = request.gte('bedrooms', minBedrooms);
      }

      final response = await request.order('created_at', ascending: false);

      final List<Property> properties = [];
      for (final item in response) {
        properties.add(Property.fromJson(item));
      }
      return properties;
    } catch (e) {
      print('❌ Erreur lors de la recherche de propriétés: $e');
      return [];
    }
  }

  // Add this method to PropertyRepository
  Future<String?> createPropertyWithGeocoding(Property property) async {
    try {
      print('🔄 [PropertyRepository] Début createPropertyWithGeocoding()');

      Map<String, double>? coordinates;

      // If coordinates are not provided, try to geocode the address
      if ((property.latitude == null || property.longitude == null) &&
          property.city.isNotEmpty) {
        print('📍 Geocoding address for property...');
        final locationService = LocationService();

        // Try precise geocoding first
        coordinates = await locationService.geocodeAddress(
          address: property.address,
          city: property.city,
          postalCode: property.postalCode,
          country: 'France',
        );

        // If precise geocoding fails, try city-level coordinates
        if (coordinates == null && property.city.isNotEmpty) {
          print(
            '🔄 Precise geocoding failed, trying city-level coordinates...',
          );
          coordinates = await locationService.getCityCoordinatesFallback(
            property.city,
          );
        }

        if (coordinates != null) {
          print('✅ Geocoding successful, creating property with coordinates');
          final propertyWithCoords = Property(
            id: property.id,
            title: property.title,
            description: property.description,
            price: property.price,
            propertyType: property.propertyType,
            transactionType: property.transactionType,
            surfaceArea: property.surfaceArea,
            rooms: property.rooms,
            bedrooms: property.bedrooms,
            bathrooms: property.bathrooms,
            address: property.address,
            city: property.city,
            postalCode: property.postalCode,
            latitude: coordinates['latitude'],
            longitude: coordinates['longitude'],
            images: property.images,
            userId: property.userId,
            isActive: property.isActive,
            createdAt: property.createdAt,
            updatedAt: property.updatedAt,
          );

          return await createProperty(propertyWithCoords);
        } else {
          print(
            '⚠️ All geocoding attempts failed, property will not appear on map',
          );
          print('📍 Address: ${property.fullAddress}');
        }
      } else if (property.latitude != null && property.longitude != null) {
        print('📍 Property already has coordinates, using existing ones');
      }

      // Create property (with or without coordinates)
      return await createProperty(property);
    } catch (e) {
      print(
        '❌ [PropertyRepository] Erreur dans createPropertyWithGeocoding: $e',
      );
      return null;
    }
  }

  // Récupérer les propriétés favorites d'un utilisateur
  Future<List<Property>> getFavoriteProperties(String userId) async {
    try {
      final response = await _supabase
          .from('favorites')
          .select('property:properties(*)')
          .eq('user_id', userId);

      final List<Property> properties = [];
      for (final item in response) {
        if (item['property'] != null) {
          properties.add(Property.fromJson(item['property']));
        }
      }
      return properties;
    } catch (e) {
      print('❌ Erreur lors de la récupération des favoris: $e');
      return [];
    }
  }

  // Ajouter une propriété aux favoris
  Future<bool> addToFavorites(String userId, String propertyId) async {
    try {
      print('⭐ Adding to favorites: User $userId, Property $propertyId');

      // First check if already in favorites
      final existingFavorite = await _supabase
          .from('favorites')
          .select()
          .eq('user_id', userId)
          .eq('property_id', propertyId)
          .maybeSingle();

      if (existingFavorite != null) {
        print('⚠️ Property already in favorites, skipping...');
        return true; // Already in favorites, consider it success
      }

      // If not exists, add to favorites
      final response = await _supabase.from('favorites').insert({
        'user_id': userId,
        'property_id': propertyId,
      }).select();

      print('✅ Added to favorites successfully');
      return response.isNotEmpty;
    } catch (e) {
      print('❌ Error adding to favorites: $e');

      // Check if it's a duplicate error
      if (e.toString().contains('23505')) {
        print('⚠️ Duplicate favorite detected, considering as success');
        return true; // Already exists, so consider it success
      }

      rethrow;
    }
  }

  // Retirer une propriété des favoris
  Future<bool> removeFromFavorites(String userId, String propertyId) async {
    try {
      print('🗑️ Removing from favorites: User $userId, Property $propertyId');

      final response = await _supabase
          .from('favorites')
          .delete()
          .eq('user_id', userId)
          .eq('property_id', propertyId)
          .select();

      print('✅ Removed from favorites successfully');
      return response.isNotEmpty;
    } catch (e) {
      print('❌ Error removing from favorites: $e');
      rethrow;
    }
  }

  // Vérifier si une propriété est dans les favoris
  Future<bool> isPropertyFavorite(String userId, String propertyId) async {
    try {
      final response = await _supabase
          .from('favorites')
          .select()
          .eq('user_id', userId)
          .eq('property_id', propertyId);

      return response.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  User? getCurrentUser() {
    return _supabaseService.currentUser;
  }

  Future<bool> isPropertyInFavorites(String userId, String propertyId) async {
    try {
      final response = await _supabase
          .from('favorites')
          .select()
          .eq('user_id', userId)
          .eq('property_id', propertyId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      print('❌ Error checking favorite status: $e');
      return false;
    }
  }

  // Récupérer les statistiques des propriétés
  Future<Map<String, dynamic>> getPropertiesStats() async {
    try {
      final totalResponse = await _supabase
          .from('properties')
          .select('id')
          .eq('is_active', true);

      final saleResponse = await _supabase
          .from('properties')
          .select('id')
          .eq('is_active', true)
          .eq('transaction_type', 'sale');

      final rentalResponse = await _supabase
          .from('properties')
          .select('id')
          .eq('is_active', true)
          .eq('transaction_type', 'rental');

      return {
        'total': totalResponse.length,
        'for_sale': saleResponse.length,
        'for_rent': rentalResponse.length,
      };
    } catch (e) {
      print('❌ Erreur lors de la récupération des statistiques: $e');
      return {'total': 0, 'for_sale': 0, 'for_rent': 0};
    }
  }
}
