import 'package:flutter/material.dart';

class CategoryModel {
  final String id;
  final String name;
  final String iconName;
  final String colorHex;
  final String? description;
  final bool isActive;
  final int sortOrder;

  CategoryModel({
    required this.id,
    required this.name,
    required this.iconName,
    required this.colorHex,
    this.description,
    this.isActive = true,
    this.sortOrder = 0,
  });

  Color get color => Color(int.parse(colorHex.replaceFirst('#', '0xFF')));

  IconData get icon {
    switch (iconName) {
      case 'plumbing':
        return Icons.plumbing;
      case 'electrical_services':
        return Icons.electrical_services;
      case 'carpenter':
        return Icons.carpenter;
      case 'school':
        return Icons.school;
      case 'format_paint':
        return Icons.format_paint;
      case 'ac_unit':
        return Icons.ac_unit;
      case 'cleaning_services':
        return Icons.cleaning_services;
      case 'home_repair_service':
        return Icons.home_repair_service;
      case 'computer':
        return Icons.computer;
      case 'lock':
        return Icons.lock;
      default:
        return Icons.build;
    }
  }

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      iconName: json['icon_name'] as String,
      colorHex: json['color_hex'] as String,
      description: json['description'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'icon_name': iconName,
      'color_hex': colorHex,
      'description': description,
      'is_active': isActive,
      'sort_order': sortOrder,
    };
  }
}
