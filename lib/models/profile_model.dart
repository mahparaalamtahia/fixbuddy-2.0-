class ProfileModel {
  final String id;
  final String role;
  final String fullName;
  final String email;
  final String? phone;
  final String? avatarUrl;
  final String? areaId;
  final String? areaName;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  ProfileModel({
    required this.id,
    required this.role,
    required this.fullName,
    required this.email,
    this.phone,
    this.avatarUrl,
    this.areaId,
    this.areaName,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as String,
      role: json['role'] as String,
      fullName: json['full_name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      areaId: json['area_id'] as String?,
      areaName: _extractAreaName(json),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'role': role,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'avatar_url': avatarUrl,
      'area_id': areaId,
      'is_active': isActive,
    };
  }

  ProfileModel copyWith({
    String? fullName,
    String? phone,
    String? avatarUrl,
    String? areaId,
    bool? isActive,
  }) {
    return ProfileModel(
      id: id,
      role: role,
      fullName: fullName ?? this.fullName,
      email: email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      areaId: areaId ?? this.areaId,
      areaName: areaName,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// Supabase returns the joined areas table under the key 'areas'.
/// Some older code or manual JSON may use 'area'.  Handle both.
String? _extractAreaName(Map<String, dynamic> json) {
  final areas = json['areas'];
  if (areas is Map) return areas['name'] as String?;
  final area = json['area'];
  if (area is Map) return area['name'] as String?;
  return null;
}
