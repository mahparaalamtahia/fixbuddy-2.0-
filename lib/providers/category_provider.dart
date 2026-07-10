import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/category_service.dart';
import '../models/category_model.dart';

final categoryServiceProvider =
    Provider<CategoryService>((ref) => CategoryService());

final activeCategoriesProvider =
    FutureProvider<List<CategoryModel>>((ref) async {
  final categoryService = ref.watch(categoryServiceProvider);
  return await categoryService.getActiveCategories();
});

final allCategoriesProvider = FutureProvider<List<CategoryModel>>((ref) async {
  final categoryService = ref.watch(categoryServiceProvider);
  return await categoryService.getAllCategories();
});
