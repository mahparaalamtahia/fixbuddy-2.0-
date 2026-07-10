class AreaModel {
  final String id;
  final String name;
  final String city;
  final bool isActive;
  final int sortOrder;

  AreaModel({
    required this.id,
    required this.name,
    this.city = 'Dhaka',
    this.isActive = true,
    this.sortOrder = 0,
  });

  factory AreaModel.fromJson(Map<String, dynamic> json) {
    return AreaModel(
      id: json['id'] as String,
      name: json['name'] as String,
      city: json['city'] as String? ?? 'Dhaka',
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'city': city,
      'is_active': isActive,
      'sort_order': sortOrder,
    };
  }
}
