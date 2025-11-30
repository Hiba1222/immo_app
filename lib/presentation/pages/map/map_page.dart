import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import '../../../data/models/property_model.dart';
import '../../../presentation/providers/property_provider.dart';
import '../../../services/supabase_service.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  GoogleMapController? mapController;
  final Completer<GoogleMapController> _controller = Completer();

  LatLng _currentLocation = const LatLng(48.8566, 2.3522); // Paris default
  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {};
  bool _isLoading = true;
  bool _locationEnabled = false;
  Position? _userPosition;

  // Filter states
  bool _showHouses = true;
  bool _showApartments = true;
  bool _showVillas = true;
  bool _showForSale = true;
  bool _showForRent = true;
  double _radiusFilter = 50000; // meters
  bool _useRadiusFilter = false; // Radius filter disabled by default

  // Search
  final TextEditingController _searchController = TextEditingController();
  bool _showSearchBar = false;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  // Properties cache
  List<dynamic> _allProperties = [];

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _loadProperties();
  }

  Future<void> _initializeLocation() async {
    try {
      // Check location permission
      final status = await Permission.location.request();

      if (status.isGranted) {
        // Get current position
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        setState(() {
          _userPosition = position;
          _currentLocation = LatLng(position.latitude, position.longitude);
          _locationEnabled = true;
        });

        // Move camera to user location
        if (mapController != null) {
          mapController!.animateCamera(
            CameraUpdate.newLatLng(_currentLocation),
          );
        }
      } else {
        _showLocationPermissionDialog();
      }
    } catch (e) {
      print('❌ Erreur de localisation: $e');
      if (e.toString().contains('mapController')) {
        print('⚠️ Map controller not ready yet, but location is working');
      } else {
        _showLocationErrorSnackbar();
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadProperties() async {
    try {
      final supabaseService = SupabaseService();
      final properties = await supabaseService.client
          .from('properties')
          .select()
          .eq('is_active', true);

      print('📊 Properties loaded: ${properties.length}');
      _allProperties = properties; // Cache the properties
      _applyFiltersToCachedData(); // Apply current filters to cached properties
    } catch (e) {
      print('❌ Erreur chargement propriétés: $e');
      // If online loading fails, try to show cached properties if available
      if (_allProperties.isNotEmpty) {
        _applyFiltersToCachedData();
        _showErrorSnackbar(
            'Connexion interrompue - Affichage des données en cache');
      } else {
        _showErrorSnackbar('Erreur de chargement des propriétés');
      }
    }
  }

  void _addPropertyMarkers(List<dynamic> properties) {
    _markers.clear();
    final Set<String> processedIds = {}; // Track processed property IDs
    int propertiesWithCoords = 0;
    int propertiesWithoutCoords = 0;
    int duplicateCount = 0;

    for (final propertyData in properties) {
      try {
        final property = Property.fromJson(propertyData);

        // Skip duplicates
        if (processedIds.contains(property.id)) {
          duplicateCount++;
          continue;
        }
        processedIds.add(property.id);

        // Skip properties without coordinates
        if (property.latitude == null || property.longitude == null) {
          propertiesWithoutCoords++;
          print(
              '⚠️ Property "${property.title}" skipped - no coordinates: ${property.fullAddress}');
          continue;
        }

        propertiesWithCoords++;

        // Apply filters
        if (!_shouldShowProperty(property)) {
          continue;
        }

        final marker = Marker(
          markerId: MarkerId(property.id),
          position: LatLng(property.latitude!, property.longitude!),
          infoWindow: InfoWindow(
            title: property.title.length > 30
                ? '${property.title.substring(0, 30)}...'
                : property.title,
            snippet:
                '${property.formattedPrice} • ${property.transactionTypeDisplay}',
          ),
          icon: _getMarkerIcon(property),
          onTap: () {
            _showPropertyDetails(property);
          },
        );
        _markers.add(marker);
        print(
            '📍 Marker: "${property.title}" at ${property.latitude}, ${property.longitude}');
      } catch (e) {
        print('❌ Erreur création marqueur: $e');
      }
    }

    print('🎯 Map Statistics:');
    print('   📍 Markers on map: ${_markers.length}');
    print('   📊 Properties with coordinates: $propertiesWithCoords');
    print('   📊 Properties without coordinates: $propertiesWithoutCoords');
    print('   🔄 Duplicates skipped: $duplicateCount');

    if (propertiesWithoutCoords > 0) {
      print(
          '💡 Tip: ${propertiesWithoutCoords} properties missing coordinates');
    }

    if (mounted) {
      setState(() {});
    }
  }

  bool _shouldShowProperty(Property property) {
    // Property type filter
    final showByType = (property.propertyType == 'house' && _showHouses) ||
        (property.propertyType == 'apartment' && _showApartments) ||
        (property.propertyType == 'villa' && _showVillas);

    if (!showByType) {
      return false;
    }

    // Transaction type filter
    final showByTransaction =
        (property.transactionType == 'sale' && _showForSale) ||
            (property.transactionType == 'rental' && _showForRent);

    if (!showByTransaction) {
      return false;
    }

    // Radius filter (only if enabled and user location is available)
    if (_useRadiusFilter && _userPosition != null) {
      final distance = Geolocator.distanceBetween(
        _userPosition!.latitude,
        _userPosition!.longitude,
        property.latitude!,
        property.longitude!,
      );
      final withinRadius = distance <= _radiusFilter;

      if (!withinRadius) {
        return false;
      }
    }

    return true;
  }

  BitmapDescriptor _getMarkerIcon(Property property) {
    // Hue by property type
    double hue;
    switch (property.propertyType) {
      case 'house':
        hue = BitmapDescriptor.hueGreen;
        break;
      case 'apartment':
        hue = BitmapDescriptor.hueBlue;
        break;
      case 'villa':
        hue = BitmapDescriptor.hueOrange;
        break;
      default:
        hue = BitmapDescriptor.hueRed;
    }

    return BitmapDescriptor.defaultMarkerWithHue(hue);
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller; // Now it can handle null
    _controller.complete(controller);

    // Add user location circle if available and radius filter is enabled
    if (_userPosition != null && _useRadiusFilter) {
      _circles.clear();
      _circles.add(
        Circle(
          circleId: const CircleId('user_location'),
          center: LatLng(_userPosition!.latitude, _userPosition!.longitude),
          radius: _radiusFilter,
          strokeWidth: 2,
          strokeColor: Colors.blue.withOpacity(0.5),
          fillColor: Colors.blue.withOpacity(0.1),
        ),
      );
      setState(() {});
    }
  }

  // Search functionality with better error handling
  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults.clear();
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchResults.clear();
    });

    try {
      // Add a timeout to the request
      final response = await http.get(
        Uri.parse(
            'https://nominatim.openstreetmap.org/search?format=json&q=$query&limit=5'),
        headers: {
          'User-Agent': 'immo_app/1.0 (cesur.sawak2003@gmail.com)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _searchResults = data
              .map((item) => {
                    'display_name': item['display_name'],
                    'lat': double.parse(item['lat']),
                    'lon': double.parse(item['lon']),
                  })
              .toList();
        });

        if (_searchResults.isEmpty) {
          _showErrorSnackbar('Aucun résultat trouvé pour "$query"');
        }
      } else {
        print('❌ Search API error: ${response.statusCode} - ${response.body}');
        _showErrorSnackbar('Erreur de recherche (${response.statusCode})');
      }
    } on TimeoutException {
      print('❌ Search timeout');
      _showErrorSnackbar('Recherche timeout - vérifiez votre connexion');
    } catch (e) {
      print('❌ Erreur recherche: $e');
      _showErrorSnackbar('Erreur de connexion lors de la recherche');
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _goToLocation(double lat, double lon, String locationName) {
    final newLocation = LatLng(lat, lon);

    mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(newLocation, 12.0),
    );

    setState(() {
      _currentLocation = newLocation;
      _searchResults.clear();
      _showSearchBar = false;
      _searchController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Localisation: $locationName'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _toggleSearchBar() {
    setState(() {
      _showSearchBar = !_showSearchBar;
      if (!_showSearchBar) {
        _searchController.clear();
        _searchResults.clear();
        _isSearching = false;
      }
    });
  }

  void _showPropertyDetails(Property property) {
    showDialog(
      context: context,
      builder: (context) {
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
                                child:
                                    _buildPropertyImage(property.images.first),
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
                                property.bathrooms?.toString() ??
                                    'Non spécifié',
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
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
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
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
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
      },
    );
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

    Share.share(shareText,
        subject: 'Découvrez cette propriété: ${property.title}');
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
            return const Center(
                child: Icon(Icons.broken_image, size: 40, color: Colors.grey));
          },
        );
      } catch (e) {
        return const Center(
            child: Icon(Icons.error, size: 40, color: Colors.red));
      }
    } else {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const Center(
              child: Icon(Icons.broken_image, size: 40, color: Colors.grey));
        },
      );
    }
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
                                  child: _buildPropertyImage(
                                      property.images.first),
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
                      hintText:
                          'Bonjour, je suis intéressé par votre annonce...',
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
                                  content: const Text(
                                      'Message envoyé à l\'annonceur!'),
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

  Future<void> _goToMyLocation() async {
    try {
      if (_userPosition != null && mapController != null) {
        await mapController!.animateCamera(
          CameraUpdate.newLatLng(
            LatLng(_userPosition!.latitude, _userPosition!.longitude),
          ),
        );
      } else {
        await _initializeLocation();
      }
    } catch (e) {
      print('❌ Error going to location: $e');
      // Only show error if it's a real location issue, not mapController
      if (!e.toString().contains('mapController')) {
        _showErrorSnackbar('Impossible d\'accéder à votre position');
      }
    }
  }

  void _zoomIn() {
    mapController?.animateCamera(CameraUpdate.zoomIn());
  }

  void _zoomOut() {
    mapController?.animateCamera(CameraUpdate.zoomOut());
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              height: MediaQuery.of(context).size.height * 0.8,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filtres de la carte',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Property type filters
                    const Text(
                      'Type de bien',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildFilterOption('Maisons', _showHouses, (value) {
                      setModalState(() => _showHouses = value!);
                    }),
                    _buildFilterOption('Appartements', _showApartments,
                        (value) {
                      setModalState(() => _showApartments = value!);
                    }),
                    _buildFilterOption('Villas', _showVillas, (value) {
                      setModalState(() => _showVillas = value!);
                    }),

                    const SizedBox(height: 20),

                    // Transaction type filters
                    const Text(
                      'Type de transaction',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildFilterOption('À vendre', _showForSale, (value) {
                      setModalState(() => _showForSale = value!);
                    }),
                    _buildFilterOption('À louer', _showForRent, (value) {
                      setModalState(() => _showForRent = value!);
                    }),

                    const SizedBox(height: 20),

                    // Radius filter
                    if (_userPosition != null) ...[
                      _buildFilterOption('Filtrer par rayon', _useRadiusFilter,
                          (value) {
                        setModalState(() => _useRadiusFilter = value!);
                      }),
                      if (_useRadiusFilter) ...[
                        const SizedBox(height: 12),
                        Text(
                            'Dans un rayon de ${(_radiusFilter / 1000).toStringAsFixed(0)} km'),
                        Slider(
                          value: _radiusFilter,
                          min: 1000,
                          max: 500000, // 500km max
                          divisions: 50,
                          onChanged: (value) {
                            setModalState(() => _radiusFilter = value);
                          },
                        ),
                        Text(
                          'Actuellement: ${_markers.length} propriétés visibles',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],

                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              // Reset filters - show all properties worldwide
                              setModalState(() {
                                _showHouses = true;
                                _showApartments = true;
                                _showVillas = true;
                                _showForSale = true;
                                _showForRent = true;
                                _radiusFilter = 50000;
                                _useRadiusFilter = false;
                              });
                            },
                            child: const Text('Tout afficher'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _applyFilters();
                            },
                            child: const Text('Appliquer'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterOption(
      String label, bool value, ValueChanged<bool?> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: onChanged,
          ),
          Text(label),
        ],
      ),
    );
  }

  void _applyFilters() {
    print('🎛️ Applying filters...');
    print('🏠 Houses: $_showHouses');
    print('🏢 Apartments: $_showApartments');
    print('🏡 Villas: $_showVillas');
    print('💰 For Sale: $_showForSale');
    print('📅 For Rent: $_showForRent');
    print('📏 Radius Filter Enabled: $_useRadiusFilter');
    print(
        '📏 Radius: ${_radiusFilter}m (${(_radiusFilter / 1000).toStringAsFixed(0)}km)');

    _applyFiltersToCachedData();

    // Update user location circle if radius filter is enabled
    if (_userPosition != null && _useRadiusFilter) {
      _circles.clear();
      _circles.add(
        Circle(
          circleId: const CircleId('user_location'),
          center: LatLng(_userPosition!.latitude, _userPosition!.longitude),
          radius: _radiusFilter,
          strokeWidth: 2,
          strokeColor: Colors.blue.withOpacity(0.5),
          fillColor: Colors.blue.withOpacity(0.1),
        ),
      );
    } else {
      _circles.clear();
    }

    setState(() {});
  }

  void _applyFiltersToCachedData() {
    if (_allProperties.isNotEmpty) {
      _addPropertyMarkers(_allProperties);
    } else {
      _loadProperties(); // Only load from network if no cached data
    }
  }

  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Autorisation de localisation'),
        content: const Text(
            'Cette application a besoin de votre position pour afficher les propriétés près de chez vous.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Plus tard'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Paramètres'),
          ),
        ],
      ),
    );
  }

  void _showLocationErrorSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Impossible d\'accéder à votre position'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Carte Immobilière',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProperties,
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: _currentLocation,
                    zoom: _useRadiusFilter
                        ? 10
                        : 5, // Wider zoom when showing worldwide
                  ),
                  markers: _markers,
                  circles: _circles,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: true,
                  rotateGesturesEnabled: true,
                  scrollGesturesEnabled: true,
                  zoomGesturesEnabled: true,
                  tiltGesturesEnabled: true,
                ),

                // Zoom controls
                Positioned(
                  bottom: 100,
                  right: 16,
                  child: Column(
                    children: [
                      FloatingActionButton.small(
                        heroTag: 'zoom_in',
                        onPressed: _zoomIn,
                        child: const Icon(Icons.add),
                      ),
                      const SizedBox(height: 8),
                      FloatingActionButton.small(
                        heroTag: 'zoom_out',
                        onPressed: _zoomOut,
                        child: const Icon(Icons.remove),
                      ),
                    ],
                  ),
                ),

                // Search bar with results
                // Search bar with results - UPDATED DESIGN
                if (_showSearchBar)
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Column(
                      children: [
                        // Search input - UPDATED to match home_content_page
                        Container(
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 8.0),
                            child: Row(
                              children: [
                                const Icon(Icons.search,
                                    color: Colors.grey, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    decoration: const InputDecoration(
                                      hintText:
                                          'Rechercher par ville, adresse, quartier...',
                                      border: InputBorder.none,
                                      contentPadding:
                                          EdgeInsets.symmetric(vertical: 12),
                                      hintStyle: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 14,
                                      ),
                                    ),
                                    onChanged: _searchLocation,
                                    onSubmitted: (value) {
                                      if (_searchResults.isNotEmpty) {
                                        final firstResult =
                                            _searchResults.first;
                                        _goToLocation(
                                          firstResult['lat'],
                                          firstResult['lon'],
                                          firstResult['display_name'],
                                        );
                                      } else if (value.isNotEmpty) {
                                        _searchLocation(value);
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (_isSearching)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 8),
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    ),
                                  ),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.close,
                                        color: Colors.blue, size: 20),
                                    onPressed: _toggleSearchBar,
                                    padding: const EdgeInsets.all(8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Search results
                        if (_searchResults.isNotEmpty)
                          Card(
                            elevation: 4,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 200),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: _searchResults.length,
                                itemBuilder: (context, index) {
                                  final result = _searchResults[index];
                                  return ListTile(
                                    leading:
                                        const Icon(Icons.location_on, size: 20),
                                    title: Text(
                                      result['display_name'],
                                      style: const TextStyle(fontSize: 14),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onTap: () {
                                      _goToLocation(
                                        result['lat'],
                                        result['lon'],
                                        result['display_name'],
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

// Search button (when search bar is hidden) - UPDATED DESIGN
                if (!_showSearchBar)
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Container(
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.0, vertical: 8.0),
                        child: Row(
                          children: [
                            const Icon(Icons.search,
                                color: Colors.grey, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: _toggleSearchBar,
                                child: Text(
                                  'Rechercher par ville, adresse, quartier...',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.tune,
                                    color: Colors.blue, size: 20),
                                onPressed: _showFilters,
                                tooltip: 'Filtres',
                                padding: const EdgeInsets.all(8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                // Location status indicator
                if (!_locationEnabled)
                  Positioned(
                    top: _showSearchBar
                        ? (_searchResults.isNotEmpty ? 250 : 80)
                        : 80,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_off,
                              size: 16, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            'Localisation désactivée',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Debug info
                Positioned(
                  bottom: 16,
                  left: 16,
                  child: Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Marqueurs: ${_markers.length}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          if (_useRadiusFilter)
                            Text(
                              'Rayon: ${(_radiusFilter / 1000).toStringAsFixed(0)}km',
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.grey),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _goToMyLocation,
        backgroundColor: Colors.blue,
        child: Icon(
          _locationEnabled ? Icons.gps_fixed : Icons.gps_not_fixed,
          color: Colors.white,
        ),
      ),
    );
  }
}
