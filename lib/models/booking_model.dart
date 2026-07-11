class BookingModel {
  final String id;
  final String userId;
  final String workerId;
  final String categoryId;
  final String areaId;
  final DateTime scheduledDate;
  final String scheduledTime;
  final String status;
  final String? notes;
  final double? totalAmount;
  final bool isReviewed;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // Joined fields
  final String? workerName;
  final String? workerAvatar;
  final String? categoryName;
  final String? categoryIcon;
  final String? areaName;
  final String? workerPhone;
  final String? paymentMethod;
  final String? declineReason;
  
  final String? userName;
  final String? userAvatar;
  final String? userPhone;

  BookingModel({
    required this.id,
    required this.userId,
    required this.workerId,
    required this.categoryId,
    required this.areaId,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.status,
    this.notes,
    this.totalAmount,
    this.isReviewed = false,
    this.createdAt,
    this.updatedAt,
    this.workerName,
    this.workerAvatar,
    this.categoryName,
    this.categoryIcon,
    this.areaName,
    this.workerPhone,
    this.paymentMethod,
    this.declineReason,
    this.userName,
    this.userAvatar,
    this.userPhone,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    final workerData = json['workers'] as Map<String, dynamic>?;
    final workerProfile = workerData?['profiles'] as Map<String, dynamic>?;
    final categoryData = json['categories'] as Map<String, dynamic>?;
    final areaData = json['areas'] as Map<String, dynamic>?;
    final userProfile = json['profiles'] as Map<String, dynamic>?;

    return BookingModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      workerId: json['worker_id'] as String,
      categoryId: json['category_id'] as String,
      areaId: json['area_id'] as String,
      scheduledDate: DateTime.parse(json['scheduled_date'] as String),
      scheduledTime: json['scheduled_time'] as String,
      status: json['status'] as String,
      notes: json['notes'] as String?,
      totalAmount: (json['total_amount'] as num?)?.toDouble(),
      isReviewed: json['is_reviewed'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      workerName: workerProfile?['full_name'] as String?,
      workerAvatar: workerProfile?['avatar_url'] as String?,
      categoryName: categoryData?['name'] as String?,
      categoryIcon: categoryData?['icon_name'] as String?,
      areaName: areaData?['name'] as String?,
      workerPhone: workerProfile?['phone'] as String?,
      paymentMethod: json['payment_method'] as String?,
      declineReason: json['decline_reason'] as String?,
      userName: userProfile?['full_name'] as String?,
      userAvatar: userProfile?['avatar_url'] as String?,
      userPhone: userProfile?['phone'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'worker_id': workerId,
      'category_id': categoryId,
      'area_id': areaId,
      'scheduled_date': scheduledDate.toIso8601String().split('T')[0],
      'scheduled_time': scheduledTime,
      'status': status,
      'notes': notes,
      'total_amount': totalAmount,
    };
  }

  BookingModel copyWith(
      {String? status, bool? isReviewed, String? declineReason}) {
    return BookingModel(
      id: id,
      userId: userId,
      workerId: workerId,
      categoryId: categoryId,
      areaId: areaId,
      scheduledDate: scheduledDate,
      scheduledTime: scheduledTime,
      status: status ?? this.status,
      notes: notes,
      totalAmount: totalAmount,
      isReviewed: isReviewed ?? this.isReviewed,
      createdAt: createdAt,
      updatedAt: updatedAt,
      workerName: workerName,
      workerAvatar: workerAvatar,
      categoryName: categoryName,
      categoryIcon: categoryIcon,
      areaName: areaName,
      workerPhone: workerPhone,
      paymentMethod: paymentMethod,
      declineReason: declineReason ?? this.declineReason,
    );
  }
}
