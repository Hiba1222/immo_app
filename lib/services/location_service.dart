import 'dart:convert';
import 'package:http/http.dart' as http;

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  // Multiple geocoding providers as fallback
  Future<Map<String, double>?> geocodeAddress({
    required String address,
    required String city,
    String? postalCode,
    String? country = 'France',
  }) async {
    print('📍 Geocoding: $address, $city, $postalCode, $country');

    // Try multiple geocoding services
    Map<String, double>? coordinates;

    // Try OpenStreetMap first
    coordinates = await _geocodeWithOSM(address, city, postalCode, country);
    if (coordinates != null) return coordinates;

    // Try Google Geocoding API (free tier)
    coordinates = await _geocodeWithGoogle(address, city, postalCode, country);
    if (coordinates != null) return coordinates;

    // Try Mapbox (free tier)
    coordinates = await _geocodeWithMapbox(address, city, postalCode, country);

    return coordinates;
  }

  Future<Map<String, double>?> _geocodeWithOSM(
      String address, String city, String? postalCode, String? country) async {
    try {
      String query = _buildQuery(address, city, postalCode, country);
      final encodedQuery = Uri.encodeComponent(query);

      final url =
          'https://nominatim.openstreetmap.org/search?format=json&q=$encodedQuery&limit=1&addressdetails=1';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'immo_app/1.0 (cesur.sawak2003@gmail.com)',
          'Accept-Language': 'fr-FR,fr;q=0.9,en;q=0.8',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          final result = data.first;
          final lat = double.parse(result['lat']);
          final lon = double.parse(result['lon']);
          print('✅ OSM Geocoding successful: $lat, $lon');
          return {'latitude': lat, 'longitude': lon};
        }
      } else {
        print('❌ OSM Geocoding failed: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ OSM Geocoding error: $e');
    }
    return null;
  }

  Future<Map<String, double>?> _geocodeWithGoogle(
      String address, String city, String? postalCode, String? country) async {
    try {
      // Note: You'll need to get a free API key from Google Cloud Console
      const apiKey =
          'AIzaSyBOZ4YdX399msLSnEkacCBUyHmHAHiO450'; // Replace with actual key
      if (apiKey == 'AIzaSyBOZ4YdX399msLSnEkacCBUyHmHAHiO450') return null;

      String query = _buildQuery(address, city, postalCode, country);
      final encodedQuery = Uri.encodeComponent(query);

      final url =
          'https://maps.googleapis.com/maps/api/geocode/json?address=$encodedQuery&key=$apiKey';

      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['results'].isNotEmpty) {
          final location = data['results'][0]['geometry']['location'];
          final lat = location['lat'].toDouble();
          final lon = location['lng'].toDouble();
          print('✅ Google Geocoding successful: $lat, $lon');
          return {'latitude': lat, 'longitude': lon};
        }
      }
    } catch (e) {
      print('❌ Google Geocoding error: $e');
    }
    return null;
  }

  Future<Map<String, double>?> _geocodeWithMapbox(
      String address, String city, String? postalCode, String? country) async {
    try {
      // Note: You'll need to get a free access token from Mapbox
      const accessToken =
          'pk.eyJ1IjoiY2VzdXJzayIsImEiOiJjbWlrdDk4a28wZmh0M2dyMWlqeTVkYXhlIn0.yGDI2Y89BNNbcQgv_P6-7A'; // Replace with actual token
      if (accessToken ==
          'pk.eyJ1IjoiY2VzdXJzayIsImEiOiJjbWlrdDk4a28wZmh0M2dyMWlqeTVkYXhlIn0.yGDI2Y89BNNbcQgv_P6-7A')
        return null;

      String query = _buildQuery(address, city, postalCode, country);
      final encodedQuery = Uri.encodeComponent(query);

      final url =
          'https://api.mapbox.com/geocoding/v5/mapbox.places/$encodedQuery.json?access_token=$accessToken&limit=1';

      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['features'].isNotEmpty) {
          final coordinates = data['features'][0]['geometry']['coordinates'];
          final lon = coordinates[0].toDouble();
          final lat = coordinates[1].toDouble();
          print('✅ Mapbox Geocoding successful: $lat, $lon');
          return {'latitude': lat, 'longitude': lon};
        }
      }
    } catch (e) {
      print('❌ Mapbox Geocoding error: $e');
    }
    return null;
  }

  String _buildQuery(
      String address, String city, String? postalCode, String? country) {
    List<String> parts = [];

    if (address.isNotEmpty) parts.add(address);
    if (city.isNotEmpty) parts.add(city);
    if (postalCode != null && postalCode.isNotEmpty) parts.add(postalCode);
    if (country != null && country.isNotEmpty) parts.add(country);

    return parts.join(', ');
  }

  // Manual coordinates for major French cities as fallback
  Map<String, Map<String, double>> getCityCoordinates() {
    return {
      'Paris': {'latitude': 48.8566, 'longitude': 2.3522},
      'Lyon': {'latitude': 45.7640, 'longitude': 4.8357},
      'Marseille': {'latitude': 43.2965, 'longitude': 5.3698},
      'Toulouse': {'latitude': 43.6047, 'longitude': 1.4442},
      'Nice': {'latitude': 43.7102, 'longitude': 7.2620},
      'Nantes': {'latitude': 47.2184, 'longitude': -1.5536},
      'Strasbourg': {'latitude': 48.5734, 'longitude': 7.7521},
      'Montpellier': {'latitude': 43.6108, 'longitude': 3.8767},
      'Bordeaux': {'latitude': 44.8378, 'longitude': -0.5792},
      'Lille': {'latitude': 50.6292, 'longitude': 3.0573},
    };
  }

  // Fallback: Get approximate coordinates for known cities
  Future<Map<String, double>?> getCityCoordinatesFallback(String city) async {
    final cityCoords = getCityCoordinates();
    final normalizedCity = city.toLowerCase().trim();

    for (final cityName in cityCoords.keys) {
      if (cityName.toLowerCase().contains(normalizedCity) ||
          normalizedCity.contains(cityName.toLowerCase())) {
        print('📍 Using fallback coordinates for $cityName');
        return cityCoords[cityName];
      }
    }
    return null;
  }
}
