import 'dart:convert';
import 'package:http/http.dart' as http;

class GeocodingService {
  static final GeocodingService _instance = GeocodingService._internal();
  factory GeocodingService() => _instance;
  GeocodingService._internal();

  // Geocode address to coordinates using OpenStreetMap Nominatim
  Future<Map<String, double>?> geocodeAddress({
    required String address,
    required String city,
    String? postalCode,
  }) async {
    try {
      // Build search query
      String query = address;
      if (postalCode != null && postalCode.isNotEmpty) {
        query += ', $postalCode';
      }
      query += ', $city, France';

      print('🔄 Geocoding address: $query');

      final encodedQuery = Uri.encodeComponent(query);
      final url =
          'https://nominatim.openstreetmap.org/search?format=json&q=$encodedQuery&limit=1';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'immo_app/1.0 (cesur.sawak2003@gmail.com)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        if (data.isNotEmpty) {
          final result = data.first;
          final lat = double.parse(result['lat']);
          final lon = double.parse(result['lon']);

          print('✅ Geocoding successful: $lat, $lon');
          return {'latitude': lat, 'longitude': lon};
        } else {
          print('❌ No results found for address: $query');
          return null;
        }
      } else {
        print('❌ Geocoding API error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Geocoding error: $e');
      return null;
    }
  }

  // Reverse geocode coordinates to address
  Future<Map<String, String>?> reverseGeocode(double lat, double lon) async {
    try {
      final url =
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'immo_app/1.0 (cesur.sawak2003@example.com)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'];

        return {
          'address': address['road'] ?? address['house_number'] ?? '',
          'city':
              address['city'] ?? address['town'] ?? address['village'] ?? '',
          'postalCode': address['postcode'] ?? '',
        };
      }
      return null;
    } catch (e) {
      print('❌ Reverse geocoding error: $e');
      return null;
    }
  }
}
