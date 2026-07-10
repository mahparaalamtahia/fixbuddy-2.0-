class AppConfigModel {
  final String id;
  final String key;
  final String value;
  final String? description;

  AppConfigModel({
    required this.id,
    required this.key,
    required this.value,
    this.description,
  });

  factory AppConfigModel.fromJson(Map<String, dynamic> json) {
    return AppConfigModel(
      id: json['id'] as String,
      key: json['key'] as String,
      value: json['value'] as String,
      description: json['description'] as String?,
    );
  }

  bool get boolValue => value.toLowerCase() == 'true';
  int get intValue => int.tryParse(value) ?? 0;
  double get doubleValue => double.tryParse(value) ?? 0;
}
