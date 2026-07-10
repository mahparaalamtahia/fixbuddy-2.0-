class ChatModel {
  final String id;
  final String? bookingId;
  final String userId;
  final String workerId;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;
  final String? seekerId;
  final String? providerId;

  // Joined fields
  final String? userName;
  final String? userAvatar;
  final String? workerName;
  final String? workerAvatar;

  ChatModel({
    required this.id,
    required this.bookingId,
    required this.userId,
    required this.workerId,
    this.lastMessage,
    this.lastMessageAt,
    this.createdAt,
    this.seekerId,
    this.providerId,
    this.userName,
    this.userAvatar,
    this.workerName,
    this.workerAvatar,
  });

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    final profiles = json['profiles'] as Map<String, dynamic>?;
    final workers = json['workers'] as Map<String, dynamic>?;
    final workerProfiles = workers?['profiles'] as Map<String, dynamic>?;

    return ChatModel(
      id: json['id'] as String,
      bookingId: json['booking_id'] as String?,
      userId: json['user_id'] as String,
      workerId: json['worker_id'] as String,
      seekerId: json['seeker_id'] as String?,
      providerId: json['provider_id'] as String?,
      lastMessage: json['last_message'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      userName: profiles?['full_name'] as String?,
      userAvatar: profiles?['avatar_url'] as String?,
      workerName: workerProfiles?['full_name'] as String?,
      workerAvatar: workerProfiles?['avatar_url'] as String?,
    );
  }
}
