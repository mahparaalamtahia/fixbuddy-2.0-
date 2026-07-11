class WorkerModel {
  final String id;
  final String profileId;
  final String? fullName;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final String? areaName;
  final String? areaId;
  final String? bio;
  final int experienceYears;
  final double hourlyRate;
  final bool isAvailable;
  final bool isVerified;
  final double avgRating;
  final int reviewCount;
  final int totalBookings;
  final List<CategoryInfo>? categories;
  final List<String>? skills;
  final List<AreaInfo>? serviceAreas;
  final DateTime? createdAt;
  final String mode;

  // Fallback getter to fix NoSuchMethodError on .rating
  double get rating => avgRating;

  WorkerModel({
    required this.id,
    required this.profileId,
    this.fullName,
    this.email,
    this.phone,
    this.avatarUrl,
    this.areaName,
    this.areaId,
    this.bio,
    this.experienceYears = 0,
    this.hourlyRate = 0,
    this.isAvailable = true,
    this.isVerified = false,
    this.avgRating = 0,
    this.reviewCount = 0,
    this.totalBookings = 0,
    this.categories,
    this.skills,
    this.serviceAreas,
    this.createdAt,
    this.mode = 'providing',
  });

  factory WorkerModel.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    final areaData = profile?['areas'] as Map<String, dynamic>?;

    List<CategoryInfo>? cats;
    if (json['worker_categories'] != null) {
      cats = (json['worker_categories'] as List)
          .map((e) => CategoryInfo.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    List<String>? skillList;
    if (json['worker_skills'] != null) {
      skillList = (json['worker_skills'] as List)
          .map((e) => (e as Map<String, dynamic>)['skill'] as String)
          .toList();
    }

    List<AreaInfo>? sAreas;
    if (json['worker_areas'] != null) {
      sAreas = (json['worker_areas'] as List)
          .map((e) => AreaInfo.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return WorkerModel(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      fullName: profile?['full_name'] as String?,
      email: profile?['email'] as String?,
      phone: profile?['phone'] as String?,
      avatarUrl: profile?['avatar_url'] as String?,
      areaName: areaData?['name'] as String?,
      areaId: profile?['area_id'] as String?,
      bio: json['bio'] as String?,
      experienceYears: (json['experience_years'] as num?)?.toInt() ?? 0,
      hourlyRate: (json['hourly_rate'] as num?)?.toDouble() ?? 0,
      isAvailable: json['is_available'] as bool? ?? true,
      isVerified: json['is_verified'] as bool? ?? false,
      avgRating: (json['avg_rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
      totalBookings: (json['total_bookings'] as num?)?.toInt() ?? 0,
      categories: cats,
      skills: skillList,
      serviceAreas: sAreas,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      mode: json['mode'] as String? ?? 'providing',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bio': bio,
      'experience_years': experienceYears,
      'hourly_rate': hourlyRate,
      'is_available': isAvailable,
      'mode': mode,
    };
  }
}

class CategoryInfo {
  final String? categoryId;
  final String? name;
  final String? iconName;
  final String? colorHex;

  CategoryInfo({this.categoryId, this.name, this.iconName, this.colorHex});

  factory CategoryInfo.fromJson(Map<String, dynamic> json) {
    final cat = json['categories'] as Map<String, dynamic>?;
    return CategoryInfo(
      categoryId: json['category_id'] as String?,
      name: cat?['name'] as String?,
      iconName: cat?['icon_name'] as String?,
      colorHex: cat?['color_hex'] as String?,
    );
  }
}

class AreaInfo {
  final String? areaId;
  final String? name;

  AreaInfo({this.areaId, this.name});

  factory AreaInfo.fromJson(Map<String, dynamic> json) {
    final area = json['areas'] as Map<String, dynamic>?;
    return AreaInfo(
      areaId: json['area_id'] as String?,
      name: area?['name'] as String?,
    );
  }
}
