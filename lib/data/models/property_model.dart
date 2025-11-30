class Property {
  final String id;
  final String title;
  final String description;
  final double price;
  final String propertyType; // 'house', 'apartment', 'villa', 'land'
  final String transactionType; // 'sale', 'rental'
  final int? surfaceArea;
  final int? rooms;
  final int? bedrooms;
  final int? bathrooms;
  final String address;
  final String city;
  final String? postalCode;
  final double? latitude;
  final double? longitude;
  final List<String> images;
  final String userId;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Property({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.propertyType,
    required this.transactionType,
    required this.address,
    required this.city,
    this.surfaceArea,
    this.rooms,
    this.bedrooms,
    this.bathrooms,
    this.postalCode,
    this.latitude,
    this.longitude,
    required this.images,
    required this.userId,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  // Convertir depuis JSON (Supabase)
  factory Property.fromJson(Map<String, dynamic> json) {
    return Property(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      propertyType: json['property_type'] ?? 'house',
      transactionType: json['transaction_type'] ?? 'sale',
      surfaceArea: json['surface_area'],
      rooms: json['rooms'],
      bedrooms: json['bedrooms'],
      bathrooms: json['bathrooms'],
      address: json['address'] ?? '',
      city: json['city'] ?? '',
      postalCode: json['postal_code'],
      latitude: json['latitude'] != null
          ? (json['latitude'] as num).toDouble()
          : null, // Handle null
      longitude: json['longitude'] != null
          ? (json['longitude'] as num).toDouble()
          : null,
      images: List<String>.from(json['images'] ?? []),
      userId: json['user_id'] ?? '',
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(
          json['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  // Convertir en JSON pour Supabase
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'price': price,
      'property_type': propertyType,
      'transaction_type': transactionType,
      'surface_area': surfaceArea,
      'rooms': rooms,
      'bedrooms': bedrooms,
      'bathrooms': bathrooms,
      'address': address,
      'city': city,
      'postal_code': postalCode,
      'latitude': latitude,
      'longitude': longitude,
      'images': images,
      'user_id': userId,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Getter pour afficher le type de transaction
  String get transactionTypeDisplay {
    return transactionType == 'sale' ? 'À vendre' : 'À louer';
  }

  // Getter pour formater le prix
  String get formattedPrice {
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(1)}M €';
    } else if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(0)}K €';
    }
    return '$price €';
  }

  // Getter pour l'adresse complète
  String get fullAddress {
    return '$address, $city${postalCode != null ? ' $postalCode' : ''}';
  }

  // NEW: Check if any image is base64
  bool get isBase64Image {
    return images.any((image) => image.startsWith('data:image'));
  }

  // NEW: Check if specific image is base64
  bool isImageBase64(int index) {
    if (images.length <= index) return false;
    return images[index].startsWith('data:image');
  }

  // NEW: Get base64 data from image
  String? getBase64Data(int index) {
    if (images.length <= index) return null;
    final image = images[index];
    if (image.startsWith('data:image')) {
      return image.split(',').last;
    }
    return null;
  }
}
