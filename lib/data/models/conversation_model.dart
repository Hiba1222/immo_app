import 'message_model.dart';

class Conversation {
  final String id;
  final String propertyId;
  final String buyerId;
  final String sellerId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? otherUserName;
  final String? otherUserAvatar;
  final String? propertyTitle;
  final Message? lastMessage;

  Conversation({
    required this.id,
    required this.propertyId,
    required this.buyerId,
    required this.sellerId,
    required this.createdAt,
    required this.updatedAt,
    this.otherUserName,
    this.otherUserAvatar,
    this.propertyTitle,
    this.lastMessage,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
  return Conversation(
    id: json['id'] as String? ?? '',
    propertyId: json['property_id'] as String? ?? '',
    buyerId: json['buyer_id'] as String? ?? '',
    sellerId: json['seller_id'] as String? ?? '',
    createdAt: json['created_at'] != null 
        ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
        : DateTime.now(),
    updatedAt: json['updated_at'] != null 
        ? DateTime.tryParse(json['updated_at'] as String) ?? DateTime.now()
        : DateTime.now(),
    otherUserName: json['other_user_name'] as String?, // Make sure this is set
    otherUserAvatar: json['other_user_avatar'] as String?,
    propertyTitle: json['property_title'] as String?,
    lastMessage: json['last_message'] != null 
        ? Message.fromJson(Map<String, dynamic>.from(json['last_message'] as Map))
        : null,
  );
}

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'property_id': propertyId,
      'buyer_id': buyerId,
      'seller_id': sellerId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}