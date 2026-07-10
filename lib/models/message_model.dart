class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String? receiverId;
  final String text;
  final bool isRead;
  final DateTime? createdAt;

  MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.receiverId,
    required this.text,
    this.isRead = false,
    this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      chatId: json['chat_id'] as String,
      senderId: json['sender_id'] as String,
      receiverId: json['receiver_id'] as String?,
      text: json['text'] as String,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chat_id': chatId,
      'sender_id': senderId,
      if (receiverId != null) 'receiver_id': receiverId,
      'text': text,
    };
  }
}
