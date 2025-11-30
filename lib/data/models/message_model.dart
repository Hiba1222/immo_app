class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String receiverId; // NEW
  final String content;
  final DateTime createdAt;
  final bool isSentByMe;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId, // NEW
    required this.content,
    required this.createdAt,
    required this.isSentByMe,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String? ?? '',
      conversationId: json['conversation_id'] as String? ?? '',
      senderId: json['sender_id'] as String? ?? '',
      receiverId: json['receiver_id'] as String? ?? '', // NEW
      content: json['content'] as String? ?? '',
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      isSentByMe: json['is_sent_by_me'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'sender_id': senderId,
      'receiver_id': receiverId, // NEW
      'content': content,
      'created_at': createdAt.toIso8601String(),
    };
  }
}