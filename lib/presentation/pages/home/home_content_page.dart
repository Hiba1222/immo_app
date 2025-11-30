import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/property_model.dart';
import '../../../presentation/providers/property_provider.dart';
import '../../../services/supabase_service.dart';
import '../../../data/repositories/property_repository.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../../widgets/contact_seller_button.dart';

class HomeContentPage extends HookConsumerWidget {
  const HomeContentPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supabaseService = SupabaseService();
    final user = supabaseService.currentUser;
    final propertiesAsync = ref.watch(filteredPropertiesProvider);
    
    final searchController = useTextEditingController();
    final selectedCategory = useState<String?>(null);
    final searchQuery = useState<String>('');

    // Écouter les nouvelles annonces en temps réel
    useEffect(() {
      final subscription = Supabase.instance.client
        .from('properties')
        .stream(primaryKey: ['id'])
        .listen((_) {
          print('🔄 Nouvelle annonce détectée, rafraîchissement...');
          ref.refresh(propertiesProvider);
          ref.refresh(filteredPropertiesProvider);
          ref.refresh(propertiesStatsProvider);
        });

      return subscription.cancel;
    }, []);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // App Logo
            Image.asset(
              'assets/images/logo.png',
              width: 32,
              height: 32,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                // Fallback if logo is not found
                return Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.home_work,
                    size: 20,
                    color: Colors.blue,
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            const Text(
              'Immo App',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => _showNotifications(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.refresh(propertiesProvider);
          ref.refresh(filteredPropertiesProvider);
          ref.refresh(propertiesStatsProvider);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // En-tête avec recherche et filtres
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Barre de recherche
                    _buildSearchBar(context, searchController, searchQuery, ref),
                    const SizedBox(height: 16),

                    // Filtres rapides
                    _buildQuickFilters(selectedCategory, ref),
                  ],
                ),
              ),
            ),

            // Liste des propriétés
            _buildPropertiesList(propertiesAsync, ref),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPropertyBottomSheet(context, ref),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  // === WIDGETS PRINCIPAUX ===

  Widget _buildSearchBar(BuildContext context, TextEditingController controller, 
      ValueNotifier<String> searchQuery, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.grey, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Rechercher par ville, adresse, quartier...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                  hintStyle: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
                onChanged: (value) {
                  searchQuery.value = value;
                  _performSearch(value, ref);
                },
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.tune, color: Colors.blue, size: 20),
                onPressed: () => _showFiltersBottomSheet(context, ref),
                padding: const EdgeInsets.all(8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickFilters(ValueNotifier<String?> selectedCategory, WidgetRef ref) {
    final List<Map<String, dynamic>> filters = [
      {'label': 'Tous', 'type': null, 'icon': Icons.all_inclusive},
      {'label': 'À vendre', 'type': 'sale', 'icon': Icons.sell},
      {'label': 'À louer', 'type': 'rental', 'icon': Icons.house},
      {'label': 'Maisons', 'type': 'house', 'icon': Icons.house},
      {'label': 'Apparts', 'type': 'apartment', 'icon': Icons.apartment},
    ];

    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = selectedCategory.value == filter['type'];
          
          return Container(
            margin: EdgeInsets.only(right: index == filters.length - 1 ? 0 : 8),
            child: FilterChip(
              label: Text(filter['label'] as String),
              avatar: Icon(filter['icon'] as IconData, size: 18),
              selected: isSelected,
              onSelected: (selected) {
                selectedCategory.value = selected ? filter['type'] as String? : null;
                _filterByCategory(filter['type'] as String?, ref);
              },
              backgroundColor: Colors.grey[100],
              selectedColor: Colors.blue.withOpacity(0.2),
              checkmarkColor: Colors.blue,
              labelStyle: TextStyle(
                color: isSelected ? Colors.blue : Colors.grey[700],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPropertiesList(AsyncValue<List<Property>> propertiesAsync, WidgetRef ref) {
    return propertiesAsync.when(
      loading: () => SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => const _PropertyCardSkeleton(),
          childCount: 3,
        ),
      ),
      error: (error, stack) => SliverToBoxAdapter(
        child: _ErrorProperties(
          error: error,
          onRetry: () {
            ref.refresh(filteredPropertiesProvider);
          },
        ),
      ),
      data: (properties) {
        if (properties.isEmpty) {
          return SliverToBoxAdapter(
            child: _buildEmptyProperties(),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final property = properties[index];
              return _PropertyListItem(
                property: property,
                onTap: () => _showPropertyDetails(context, property, ref),
              );
            },
            childCount: properties.length,
          ),
        );
      },
    );
  }

  Widget _buildEmptyProperties() {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.home_work, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Aucune annonce disponible',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Soyez le premier à publier une annonce!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                // Naviguer vers la page d'ajout
              },
              icon: const Icon(Icons.add),
              label: const Text('Créer une annonce'),
            ),
          ],
        ),
      ),
    );
  }

  // === FONCTIONNALITÉS ===

  void _performSearch(String query, WidgetRef ref) {
    final searchNotifier = ref.read(propertySearchProvider.notifier);
    if (query.isEmpty) {
      searchNotifier.clearSearch();
    } else {
      searchNotifier.searchProperties(query: query);
    }
  }

  void _filterByCategory(String? category, WidgetRef ref) {
    final searchNotifier = ref.read(propertySearchProvider.notifier);
    
    if (category == null) {
      searchNotifier.clearSearch();
    } else {
      String? propertyType;
      String? transactionType;
      
      if (category == 'sale' || category == 'rental') {
        transactionType = category;
      } else {
        propertyType = category;
      }
      
      searchNotifier.searchProperties(
        propertyType: propertyType,
        transactionType: transactionType,
      );
    }
  }

  void _showFiltersBottomSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return _FiltersBottomSheet(
          onApplyFilters: (filters) {
            final searchNotifier = ref.read(propertySearchProvider.notifier);
            searchNotifier.searchProperties(
              minPrice: filters['minPrice'],
              maxPrice: filters['maxPrice'],
              propertyType: filters['propertyType'],
              transactionType: filters['transactionType'],
              minRooms: filters['minRooms'],
              minBedrooms: filters['minBedrooms'],
            );
            Navigator.pop(context);
            _showSuccessSnackbar(context, 'Filtres appliqués');
          },
        );
      },
    );
  }

  void _showAddPropertyBottomSheet(BuildContext context, WidgetRef ref) {
    final repository = ref.read(propertyRepositoryProvider);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return _AddPropertyBottomSheet(
          onPropertyAdded: () {
            Navigator.pop(context);
            ref.refresh(propertiesProvider);
            ref.refresh(filteredPropertiesProvider);
            ref.refresh(propertiesStatsProvider);
            _showSuccessSnackbar(context, 'Annonce créée avec succès!');
          },
          repository: repository,
          ref: ref,
        );
      },
    );
  }

  void _showNotifications(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Aucune nouvelle notification'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showPropertyDetails(BuildContext context, Property property, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        return PropertyDetailsDialog(
          property: property,
          onContact: () {},
        );
      },
    );
  }

  // === MESSAGES ET SNACKBARS ===

  void _showSuccessSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// === NOUVEAU WIDGET POUR LA LISTE ===

class _PropertyListItem extends HookConsumerWidget {
  final Property property;
  final VoidCallback onTap;

  const _PropertyListItem({
    required this.property,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesManager = ref.watch(favoritesManagerProvider.notifier);
    final isFavorite = ref.watch(favoritesManagerProvider.select((state) => state[property.id] ?? false));

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image de la propriété
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[300],
                ),
                child: property.images.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _buildPropertyImage(property.images.first),
                      )
                    : const Center(
                        child: Icon(Icons.home, size: 40, color: Colors.grey),
                      ),
              ),
              const SizedBox(width: 16),
              
              // Détails de la propriété
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Titre et bouton favori
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            property.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite ? Colors.red : Colors.grey,
                            size: 20,
                          ),
                          onPressed: () {
                            favoritesManager.toggleFavorite(property.id);
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    
                    // Localisation
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            property.city,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    
                    // Prix et type de transaction
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          property.formattedPrice,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: property.transactionType == 'sale'
                                ? Colors.green[100]
                                : Colors.blue[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            property.transactionTypeDisplay,
                            style: TextStyle(
                              color: property.transactionType == 'sale'
                                  ? Colors.green[800]
                                  : Colors.blue[800],
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    // Caractéristiques (optionnel)
                    if (property.surfaceArea != null || property.rooms != null || property.bedrooms != null)
                      const SizedBox(height: 8),
                    if (property.surfaceArea != null || property.rooms != null || property.bedrooms != null)
                      Row(
                        children: [
                          if (property.surfaceArea != null) ...[
                            _buildFeatureChip('${property.surfaceArea} m²'),
                            const SizedBox(width: 4),
                          ],
                          if (property.rooms != null) ...[
                            _buildFeatureChip('${property.rooms} pièces'),
                            const SizedBox(width: 4),
                          ],
                          if (property.bedrooms != null) ...[
                            _buildFeatureChip('${property.bedrooms} chambres'),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildPropertyImage(String imageUrl) {
    if (imageUrl.startsWith('data:image')) {
      try {
        final base64String = imageUrl.split(',').last;
        final bytes = base64.decode(base64String);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Center(child: Icon(Icons.broken_image, size: 30, color: Colors.grey));
          },
        );
      } catch (e) {
        return const Center(child: Icon(Icons.error, size: 30, color: Colors.red));
      }
    } else {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const Center(child: Icon(Icons.broken_image, size: 30, color: Colors.grey));
        },
      );
    }
  }
}

// === WIDGETS EXISTANTS (MAINTENUS) ===

class _PropertyCardSkeleton extends StatelessWidget {
  const _PropertyCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 100,
              height: 100,
              color: Colors.grey[300],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 200,
                    height: 16,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 150,
                    height: 14,
                    color: Colors.grey[200],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 100,
                    height: 16,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 80,
                    height: 20,
                    color: Colors.grey[200],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorProperties extends StatelessWidget {
  final dynamic error;
  final VoidCallback onRetry;

  const _ErrorProperties({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 50, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Erreur de chargement',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

// === LES AUTRES CLASSES (PropertyDetailsDialog, _FiltersBottomSheet, _AddPropertyBottomSheet) ===
// Ces classes restent identiques à votre code précédent, je ne les ai pas modifiées
// pour garder la réponse concise. Elles doivent être conservées telles quelles.

// ... (Le reste de votre code existant pour PropertyDetailsDialog, _FiltersBottomSheet, _AddPropertyBottomSheet)

class _EmptyProperties extends StatelessWidget {
  const _EmptyProperties();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.home_work, size: 50, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Aucune annonce disponible',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Soyez le premier à publier une annonce!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                // Naviguer vers la page d'ajout
              },
              icon: const Icon(Icons.add),
              label: const Text('Créer une annonce'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PropertiesGrid extends StatelessWidget {
  final List<Property> properties;
  final bool showAll;
  final int totalCount;

  const _PropertiesGrid({
    required this.properties,
    required this.showAll,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final crossAxisCount = showAll ? 2 : 1;
    final childAspectRatio = showAll ? 0.75 : 1.4;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: properties.length,
      itemBuilder: (context, index) {
        final property = properties[index];
        return _PropertyCard(property: property);
      },
    );
  }
}

class _PropertyCard extends HookConsumerWidget {
  final Property property;

  const _PropertyCard({required this.property});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesManager = ref.watch(favoritesManagerProvider.notifier);
    final isFavorite = ref.watch(favoritesManagerProvider.select((state) => state[property.id] ?? false));

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => _showPropertyDetails(context, property, ref),
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: 180,
            maxHeight: 220,
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Image de la propriété - UPDATED
                  Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: property.images.isNotEmpty
                        ? ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                            child: _buildPropertyImage(property.images.first, height: 120),
                          )
                        : const Center(
                            child: Icon(Icons.home, size: 40, color: Colors.grey),
                          ),
                  ),
                  
                  // Rest of your card content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                property.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                property.city,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Text(
                                  property.formattedPrice,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: property.transactionType == 'sale'
                                      ? Colors.green[100]
                                      : Colors.blue[100],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  property.transactionTypeDisplay,
                                  style: TextStyle(
                                    color: property.transactionType == 'sale'
                                        ? Colors.green[800]
                                        : Colors.blue[800],
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              // Favoris button - Positioned correctly
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.red : Colors.grey,
                      size: 20,
                    ),
                    onPressed: () {
                      favoritesManager.toggleFavorite(property.id);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Image builder method
  Widget _buildPropertyImage(String imageUrl, {double? width, double? height}) {
  if (imageUrl.startsWith('data:image')) {
    // Handle base64 image
    try {
      final base64String = imageUrl.split(',').last;
      final bytes = base64Decode(base64String);
      
      return Image.memory(
        bytes,
        width: width,
        height: height,
        fit: BoxFit.cover,
        cacheWidth: width != null ? (width * 2).toInt() : 400, // Optimize for performance
        cacheHeight: height != null ? (height * 2).toInt() : 300,
        errorBuilder: (context, error, stackTrace) {
          print('❌ Erreur affichage image base64: $error');
          return const Center(
            child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
          );
        },
      );
    } catch (e) {
      print('❌ Erreur décodage base64: $e');
      return const Center(
        child: Icon(Icons.error, size: 40, color: Colors.red),
      );
    }
  } else {
    // Handle URL image with better error handling
    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                : null,
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        print('❌ Erreur chargement URL: $error');
        return const Center(
          child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
        );
      },
    );
  }
}

  void _showPropertyDetails(BuildContext context, Property property, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (context) {
      return PropertyDetailsDialog(
        property: property,
        onContact: () {}, // Keep this empty or remove it entirely if not needed
      );
    },
  );
}
}

class PropertyDetailsDialog extends HookConsumerWidget {
  final Property property;
  final VoidCallback onContact;

  const PropertyDetailsDialog({
    super.key,
    required this.property,
    required this.onContact,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoritesManager = ref.watch(favoritesManagerProvider.notifier);
    final isFavorite = ref.watch(favoritesManagerProvider.select((state) => state[property.id] ?? false));

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 500),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with image and close button
              Stack(
                children: [
                  // Property Image
                  Container(
                    height: 250,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                      color: Colors.grey[200],
                    ),
                    child: property.images.isNotEmpty
                        ? ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                            child: _buildPropertyImage(property.images.first),
                          )
                        : const Center(
                            child: Icon(
                              Icons.home_work,
                              size: 60,
                              color: Colors.grey,
                            ),
                          ),
                  ),
                  
                  // Gradient overlay
                  Container(
                    height: 250,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.3),
                        ],
                      ),
                    ),
                  ),
                  
                  // Price badge
                  Positioned(
                    top: 20,
                    left: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        property.formattedPrice,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ),
                  
                  // Close button
                  Positioned(
                    top: 20,
                    right: 20,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(context),
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  
                  // Favorite button
                  // In the PropertyDetailsDialog build method, update the favorite button:
Positioned(
  top: 70,
  right: 20,
  child: Container(
    decoration: BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.1),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: IconButton(
      icon: Icon(
        isFavorite ? Icons.favorite : Icons.favorite_border,
        color: isFavorite ? Colors.red : Colors.grey[700],
        size: 20,
      ),
      onPressed: () async {
        try {
          await favoritesManager.toggleFavorite(property.id);
        } catch (e) {
          print('❌ Error toggling favorite: $e');
          // Show error message to user if needed
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Erreur lors de la mise à jour des favoris'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    ),
  ),
),
                  
                  // Transaction type badge
                  Positioned(
                    bottom: 20,
                    left: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: property.transactionType == 'sale'
                            ? Colors.green
                            : Colors.blue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        property.transactionTypeDisplay.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              // Content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title and location
                    Text(
                      property.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 18,
                          color: Colors.blue[600],
                        ),
                        const SizedBox(width: 6),
                        Text(
                          property.fullAddress,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // Property features grid
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 12,
                        childAspectRatio: 3,
                        children: [
                          _buildFeatureItem(
                            Icons.aspect_ratio,
                            'Surface',
                            property.surfaceArea != null
                                ? '${property.surfaceArea} m²'
                                : 'Non spécifié',
                          ),
                          _buildFeatureItem(
                            Icons.door_front_door,
                            'Pièces',
                            property.rooms?.toString() ?? 'Non spécifié',
                          ),
                          _buildFeatureItem(
                            Icons.bed,
                            'Chambres',
                            property.bedrooms?.toString() ?? 'Non spécifié',
                          ),
                          _buildFeatureItem(
                            Icons.bathtub,
                            'SDB',
                            property.bathrooms?.toString() ?? 'Non spécifié',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Description
                    const Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      property.description,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _contactOwner(context, property);
                            },
                            icon: const Icon(Icons.message, size: 18),
                            label: const Text(
                              'Contacter',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(color: Colors.blue[600]!),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _shareProperty(context, property);
                            },
                            icon: const Icon(Icons.share, size: 18),
                            label: const Text(
                              'Partager',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[600],
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPropertyImage(String imageUrl) {
    if (imageUrl.startsWith('data:image')) {
      try {
        final base64String = imageUrl.split(',').last;
        final bytes = base64.decode(base64String);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey));
          },
        );
      } catch (e) {
        return const Center(child: Icon(Icons.error, size: 40, color: Colors.red));
      }
    } else {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey));
        },
      );
    }
  }

  Widget _buildFeatureItem(IconData icon, String label, String value) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(
            icon,
            size: 18,
            color: Colors.blue[600],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _shareProperty(BuildContext context, Property property) {
    // Generate shareable link
    final shareText = '''
🏠 ${property.title}

💰 ${property.formattedPrice}
📍 ${property.fullAddress}
📝 ${property.description.length > 100 ? '${property.description.substring(0, 100)}...' : property.description}

🔗 Découvrez cette propriété sur Immo App!

#Immobilier #${property.transactionType == 'sale' ? 'Vente' : 'Location'} #${property.city}
    ''';

    Share.share(shareText, subject: 'Découvrez cette propriété: ${property.title}');
  }

  void _contactOwner(BuildContext context, Property property) {
    showDialog(
      context: context,
      builder: (context) {
        final messageController = TextEditingController();
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 400),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.message,
                          color: Colors.blue[600],
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Contacter l\'annonceur',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(context),
                        color: Colors.grey[600],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Property info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey[200],
                          ),
                          child: property.images.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: _buildPropertyImage(property.images.first),
                                )
                              : const Icon(Icons.home, color: Colors.grey),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                property.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                property.formattedPrice,
                                style: TextStyle(
                                  color: Colors.blue[600],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Message field
                  const Text(
                    'Votre message',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: messageController,
                    decoration: InputDecoration(
                      hintText: 'Bonjour, je suis intéressé par votre annonce...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[400]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.blue[600]!),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 24),
                  
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Annuler',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (messageController.text.trim().isNotEmpty) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Message envoyé à l\'annonceur!'),
                                  backgroundColor: Colors.green,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[600],
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Envoyer',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}



// === BOTTOM SHEETS ===

class _AdvancedSearchBottomSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onSearch;

  const _AdvancedSearchBottomSheet({required this.onSearch});

  @override
  State<_AdvancedSearchBottomSheet> createState() => _AdvancedSearchBottomSheetState();
}

class _AdvancedSearchBottomSheetState extends State<_AdvancedSearchBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _queryController = TextEditingController();
  final _cityController = TextEditingController();
  String? _selectedPropertyType;
  String? _selectedTransactionType;
  double _minPrice = 0;
  double _maxPrice = 1000000;
  int _minRooms = 1;
  int _minBedrooms = 1;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      height: MediaQuery.of(context).size.height * 0.9,
      child: Column(
        children: [
          const Text(
            'Recherche avancée',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  _buildSearchField('Recherche', _queryController),
                  _buildSearchField('Ville', _cityController),
                  _buildDropdown('Type de bien', _propertyTypes, _selectedPropertyType, (value) {
                    setState(() => _selectedPropertyType = value);
                  }),
                  _buildDropdown('Type de transaction', _transactionTypes, _selectedTransactionType, (value) {
                    setState(() => _selectedTransactionType = value);
                  }),
                  _buildPriceRange(),
                  _buildRoomSelection(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _performSearch,
                  child: const Text('Rechercher'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> options, String? value, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: options.map((option) {
          return DropdownMenuItem(
            value: option,
            child: Text(option),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildPriceRange() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Fourchette de prix (€)'),
          RangeSlider(
            values: RangeValues(_minPrice, _maxPrice),
            min: 0,
            max: 1000000,
            divisions: 20,
            labels: RangeLabels(
              '${_minPrice.toInt()}€',
              '${_maxPrice.toInt()}€',
            ),
            onChanged: (values) {
              setState(() {
                _minPrice = values.start;
                _maxPrice = values.end;
              });
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Min: ${_minPrice.toInt()}€'),
              Text('Max: ${_maxPrice.toInt()}€'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoomSelection() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pièces min.'),
                DropdownButtonFormField<int>(
                  value: _minRooms,
                  items: List.generate(5, (index) => index + 1)
                      .map((rooms) => DropdownMenuItem(value: rooms, child: Text('$rooms')))
                      .toList(),
                  onChanged: (value) => setState(() => _minRooms = value!),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Chambres min.'),
                DropdownButtonFormField<int>(
                  value: _minBedrooms,
                  items: List.generate(4, (index) => index + 1)
                      .map((bedrooms) => DropdownMenuItem(value: bedrooms, child: Text('$bedrooms')))
                      .toList(),
                  onChanged: (value) => setState(() => _minBedrooms = value!),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _performSearch() {
    widget.onSearch({
      'query': _queryController.text.isEmpty ? null : _queryController.text,
      'city': _cityController.text.isEmpty ? null : _cityController.text,
      'propertyType': _selectedPropertyType,
      'transactionType': _selectedTransactionType,
      'minPrice': _minPrice,
      'maxPrice': _maxPrice,
      'minRooms': _minRooms,
      'minBedrooms': _minBedrooms,
    });
  }

  final List<String> _propertyTypes = ['house', 'apartment', 'villa', 'land'];
  final List<String> _transactionTypes = ['sale', 'rental'];
}

class _FiltersBottomSheet extends StatefulWidget {
  final Function(Map<String, dynamic>) onApplyFilters;

  const _FiltersBottomSheet({required this.onApplyFilters});

  @override
  State<_FiltersBottomSheet> createState() => _FiltersBottomSheetState();
}

class _FiltersBottomSheetState extends State<_FiltersBottomSheet> {
  String? _selectedPropertyType;
  String? _selectedTransactionType;
  double _minPrice = 0;
  double _maxPrice = 500000;
  int _minRooms = 1;
  int _minBedrooms = 1;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Filtres',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          
          _buildDropdown('Type de bien', ['house', 'apartment', 'villa', 'land'], _selectedPropertyType, (value) {
            setState(() => _selectedPropertyType = value);
          }),
          const SizedBox(height: 16),
          
          _buildDropdown('Type de transaction', ['sale', 'rental'], _selectedTransactionType, (value) {
            setState(() => _selectedTransactionType = value);
          }),
          const SizedBox(height: 16),
          
          _buildPriceRange(),
          const SizedBox(height: 16),
          
          _buildRoomSelection(),
          const SizedBox(height: 20),
          
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    widget.onApplyFilters({
                      'propertyType': _selectedPropertyType,
                      'transactionType': _selectedTransactionType,
                      'minPrice': _minPrice,
                      'maxPrice': _maxPrice,
                      'minRooms': _minRooms,
                      'minBedrooms': _minBedrooms,
                    });
                  },
                  child: const Text('Appliquer'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> options, String? value, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [DropdownMenuItem(value: null, child: Text('Tous les $label'))]
        ..addAll(options.map((option) => DropdownMenuItem(value: option, child: Text(option)))),
      onChanged: onChanged,
    );
  }

  Widget _buildPriceRange() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Fourchette de prix (€)'),
        RangeSlider(
          values: RangeValues(_minPrice, _maxPrice),
          min: 0,
          max: 1000000,
          divisions: 20,
          labels: RangeLabels(
            '${_minPrice.toInt()}€',
            '${_maxPrice.toInt()}€',
          ),
          onChanged: (values) {
            setState(() {
              _minPrice = values.start;
              _maxPrice = values.end;
            });
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Min: ${_minPrice.toInt()}€'),
            Text('Max: ${_maxPrice.toInt()}€'),
          ],
        ),
      ],
    );
  }

  Widget _buildRoomSelection() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Pièces min.'),
              DropdownButtonFormField<int>(
                value: _minRooms,
                items: List.generate(5, (index) => index + 1)
                    .map((rooms) => DropdownMenuItem(value: rooms, child: Text('$rooms')))
                    .toList(),
                onChanged: (value) => setState(() => _minRooms = value!),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Chambres min.'),
              DropdownButtonFormField<int>(
                value: _minBedrooms,
                items: List.generate(4, (index) => index + 1)
                    .map((bedrooms) => DropdownMenuItem(value: bedrooms, child: Text('$bedrooms')))
                    .toList(),
                onChanged: (value) => setState(() => _minBedrooms = value!),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AddPropertyBottomSheet extends StatefulWidget {
  final VoidCallback onPropertyAdded;
  final PropertyRepository repository;
  final WidgetRef ref;

  const _AddPropertyBottomSheet({
    required this.onPropertyAdded,
    required this.repository,
    required this.ref,
  });

  @override
  State<_AddPropertyBottomSheet> createState() => _AddPropertyBottomSheetState();
}

class _AddPropertyBottomSheetState extends State<_AddPropertyBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  final _surfaceController = TextEditingController();
  final _roomsController = TextEditingController();
  final _bedroomsController = TextEditingController();
  final _bathroomsController = TextEditingController();
  final _postalCodeController = TextEditingController();

  String? _selectedPropertyType;
  String? _selectedTransactionType;
  List<String> _selectedImages = []; // FOR MULTIPLE IMAGES
  bool _isUploading = false;

  @override
Widget build(BuildContext context) {
  return Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.all(20),
    child: Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 500),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with close button
            Stack(
              children: [
                Container(
                  height: 60,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      'Créer une annonce',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 20, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              ],
            ),
            
            // Form content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildImageUploadSection(),
                    const SizedBox(height: 20),
                    
                    // Two column layout for form fields
                    Column(
                      children: [
                        _buildTextField('Titre*', _titleController),
                        _buildTextField('Description*', _descriptionController, maxLines: 3),
                        _buildTextField('Prix* (€)', _priceController, keyboardType: TextInputType.number),
                        
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField('Ville*', _cityController),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField('Code postal', _postalCodeController, optional: true),
                            ),
                          ],
                        ),
                        
                        _buildTextField('Adresse complète*', _addressController),
                        
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField('Surface (m²)', _surfaceController, keyboardType: TextInputType.number, optional: true),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField('Pièces', _roomsController, keyboardType: TextInputType.number, optional: true),
                            ),
                          ],
                        ),
                        
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField('Chambres', _bedroomsController, keyboardType: TextInputType.number, optional: true),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField('SDB', _bathroomsController, keyboardType: TextInputType.number, optional: true),
                            ),
                          ],
                        ),
                        
                        Row(
                          children: [
                            Expanded(
                              child: _buildDropdown('Type de bien*', ['house', 'apartment', 'villa', 'land'], _selectedPropertyType, (value) {
                                setState(() => _selectedPropertyType = value);
                              }),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildDropdown('Transaction*', ['sale', 'rental'], _selectedTransactionType, (value) {
                                setState(() => _selectedTransactionType = value);
                              }),
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Annuler',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isUploading ? null : _createProperty,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isUploading 
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text(
                                    'Créer l\'annonce',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildImageUploadSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Images de l\'annonce',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      const Text(
        'Ajoutez jusqu\'à 5 images',
        style: TextStyle(fontSize: 12, color: Colors.grey),
      ),
      const SizedBox(height: 12),
      
      // Display selected images - UPDATED for base64
      if (_selectedImages.isNotEmpty) ...[
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _selectedImages.length,
            itemBuilder: (context, index) {
              final imageUrl = _selectedImages[index];
              return Stack(
                children: [
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[200],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildPropertyImage(imageUrl, width: 100, height: 100),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 12,
                    child: GestureDetector(
                      onTap: () => _removeImage(index),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '${_selectedImages.length} image(s) sélectionnée(s)',
          style: const TextStyle(fontSize: 12, color: Colors.green),
        ),
        const SizedBox(height: 12),
      ],
      
      // Upload button
      OutlinedButton.icon(
        onPressed: _isUploading ? null : _pickImages,
        icon: const Icon(Icons.photo_library),
        label: Text(_isUploading ? 'Chargement...' : 'Ajouter des images'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.blue,
          side: BorderSide(color: Colors.blue),
        ),
      ),
      
      if (_isUploading) ...[
        const SizedBox(height: 8),
        const LinearProgressIndicator(),
        const SizedBox(height: 8),
        const Text(
          'Conversion des images...',
          style: TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    ],
  );
}

  Widget _buildSubmitButton() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _isUploading ? null : _createProperty,
            child: const Text('Créer'),
          ),
        ),
      ],
    );
  }

  Future<void> _pickImages() async {
  try {
    final ImagePicker picker = ImagePicker();
    final List<XFile>? selectedFiles = await picker.pickMultiImage(
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 70,
    );

    if (selectedFiles != null && selectedFiles.isNotEmpty) {
      setState(() {
        _isUploading = true;
      });

      final List<String> base64Images = [];
      
      for (final file in selectedFiles) {
        if (base64Images.length >= 5) break;
        
        try {
          // Convert to base64 directly - this is reliable
          final bytes = await file.readAsBytes();
          final base64Image = base64Encode(bytes);
          final dataUrl = 'data:image/jpeg;base64,$base64Image';
          base64Images.add(dataUrl);
          print('✅ Image convertie en base64: ${file.name}');
        } catch (e) {
          print('❌ Erreur conversion base64: $e');
        }
      }

      setState(() {
        _selectedImages = base64Images;
        _isUploading = false;
      });
      
      print('🎯 ${base64Images.length} images prêtes en base64');
    }
  } catch (e) {
    setState(() {
      _isUploading = false;
    });
    print('❌ Erreur pickImages: $e');
  }
}


  void _removeImage(int index) {
  setState(() {
    _selectedImages.removeAt(index);
  });
  print('🗑️ Image $index supprimée, reste ${_selectedImages.length} images');
}
  Widget _buildPropertyImage(String imageUrl, {double? width, double? height}) {
    if (imageUrl.startsWith('data:image')) {
      // Handle base64 image
      try {
        final base64String = imageUrl.split(',').last;
        final bytes = base64Decode(base64String);
        
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: BoxFit.cover,
          cacheWidth: width != null ? (width * 2).toInt() : 400,
          cacheHeight: height != null ? (height * 2).toInt() : 300,
          errorBuilder: (context, error, stackTrace) {
            print('❌ Erreur affichage image base64: $error');
            return const Center(
              child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
            );
          },
        );
      } catch (e) {
        print('❌ Erreur décodage base64: $e');
        return const Center(
          child: Icon(Icons.error, size: 40, color: Colors.red),
        );
      }
    } else {
      // Handle URL image with better error handling
      return Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          print('❌ Erreur chargement URL: $error');
          return const Center(
            child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
          );
        },
      );
    }
  }
  Widget _buildTextField(String label, TextEditingController controller, {int maxLines = 1, TextInputType keyboardType = TextInputType.text, bool optional = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.blue),
          ),
        ),
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: (value) {
          if (!optional && (value == null || value.isEmpty)) {
            return 'Ce champ est obligatoire';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> options, String? value, ValueChanged<String?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.blue),
          ),
        ),
        items: options.map((option) {
          return DropdownMenuItem(
            value: option,
            child: Text(option),
          );
        }).toList(),
        onChanged: onChanged,
        validator: (value) {
          if (value == null) {
            return 'Ce champ est obligatoire';
          }
          return null;
        },
      ),
    );
  }

  // In the _createProperty method, replace the current implementation with:
void _createProperty() async {
  if (_formKey.currentState!.validate()) {
    try {
      setState(() {
        _isUploading = true;
      });

      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vous devez être connecté pour créer une annonce')),
        );
        return;
      }

      // Create property object without coordinates initially
      final property = Property(
        id: '', // Will be generated by Supabase
        title: _titleController.text,
        description: _descriptionController.text,
        price: double.parse(_priceController.text),
        propertyType: _selectedPropertyType!,
        transactionType: _selectedTransactionType!,
        address: _addressController.text,
        city: _cityController.text,
        postalCode: _postalCodeController.text.isNotEmpty ? _postalCodeController.text : null,
        surfaceArea: _surfaceController.text.isNotEmpty ? int.parse(_surfaceController.text) : null,
        rooms: _roomsController.text.isNotEmpty ? int.parse(_roomsController.text) : null,
        bedrooms: _bedroomsController.text.isNotEmpty ? int.parse(_bedroomsController.text) : null,
        bathrooms: _bathroomsController.text.isNotEmpty ? int.parse(_bathroomsController.text) : 1,
        latitude: null, // Will be set by geocoding
        longitude: null, // Will be set by geocoding
        images: _selectedImages,
        userId: user.id,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      print('📝 Création annonce avec ${_selectedImages.length} images');
      print('📍 Adresse à géocoder: ${property.fullAddress}');

      // Use the new method with geocoding
      final propertyId = await widget.repository.createPropertyWithGeocoding(property);
      
      setState(() {
        _isUploading = false;
      });

      if (propertyId != null) {
        print('✅ Annonce créée avec ID: $propertyId');
        widget.onPropertyAdded();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors de la création de l\'annonce')),
        );
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      print('❌ Erreur création annonce: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur création annonce: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

  void _showErrorSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _postalCodeController.dispose();
    _surfaceController.dispose();
    _roomsController.dispose();
    _bedroomsController.dispose();
    _bathroomsController.dispose();
    super.dispose();
  }
}