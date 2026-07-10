import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/category_model.dart';

class CategoryService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<CategoryModel>> getActiveCategories() async {
    final data = await _supabase
        .from('categories')
        .select('*')
        .eq('is_active', true)
        .order('sort_order');
    return (data as List).map((e) => CategoryModel.fromJson(e)).toList();
  }

  Future<List<CategoryModel>> getAllCategories() async {
    final data =
        await _supabase.from('categories').select('*').order('sort_order');
    return (data as List).map((e) => CategoryModel.fromJson(e)).toList();
  }

  Future<CategoryModel> createCategory(Map<String, dynamic> data) async {
    final result =
        await _supabase.from('categories').insert(data).select().single();
    return CategoryModel.fromJson(result);
  }

  Future<void> updateCategory(String id, Map<String, dynamic> data) async {
    await _supabase.from('categories').update(data).eq('id', id);
  }

  Future<void> deleteCategory(String id) async {
    await _supabase.from('categories').delete().eq('id', id);
  }
}
