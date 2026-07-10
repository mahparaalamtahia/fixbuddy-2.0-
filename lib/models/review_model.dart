class ReviewModel {
  final String id;
  final String bookingId;
  final String userId;
  final String workerId;
  final int rating;
  final String? comment;
  final bool isFlagged;
  final DateTime? createdAt;

  // Joined fields
  final String? userName;
  final String? userAvatar;
  final String? workerName;

  ReviewModel({
    required this.id,
    required this.bookingId,
    required this.userId,
    required this.workerId,
    required this.rating,
    this.comment,
    this.isFlagged = false,
    this.createdAt,
    this.userName,
    this.userAvatar,
    this.workerName,
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    final userData = json['profiles'] as Map<String, dynamic>?;
    final workerData = json['workers'] as Map<String, dynamic>?;
    final workerProfile = workerData?['profiles'] as Map<String, dynamic>?;
    return ReviewModel(
      id: json['id'] as String,
      bookingId: json['booking_id'] as String,
      userId: json['user_id'] as String,
      workerId: json['worker_id'] as String,
      rating: (json['rating'] as num).toInt(),
      comment: json['comment'] as String?,
      isFlagged: json['is_flagged'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      userName: userData?['full_name'] as String?,
      userAvatar: userData?['avatar_url'] as String?,
      workerName: workerProfile?['full_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'booking_id': bookingId,
      'user_id': userId,
      'worker_id': workerId,
      'rating': rating,
      'comment': comment,
    };
  }
}
