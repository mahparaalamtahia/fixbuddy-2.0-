import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  final SupabaseClient _supabase = Supabase.instance.client;

  String _getMimeType(XFile file) {
    if (file.mimeType != null && file.mimeType!.isNotEmpty) {
      return file.mimeType!;
    }
    final name = file.name.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.pdf')) return 'application/pdf';
    return 'image/jpeg';
  }

  Future<String> uploadAvatar({
    required String userId,
    required XFile file,
  }) async {
    final fileBytes = await file.readAsBytes();
    final fileName = '$userId/avatar.jpg';
    await _supabase.storage.from('avatars').uploadBinary(
          fileName,
          fileBytes,
          fileOptions: FileOptions(upsert: true, contentType: _getMimeType(file)),
        );
    return _supabase.storage.from('avatars').getPublicUrl(fileName);
  }

  Future<String> uploadWorkerDoc({
    required String userId,
    required XFile file,
    String? fileName,
  }) async {
    final fileBytes = await file.readAsBytes();
    final ext = _getExtension(file.name).isEmpty ? '.jpg' : _getExtension(file.name);
    var name = fileName ?? 'doc_${DateTime.now().millisecondsSinceEpoch}$ext';
    if (!name.contains('.')) name = '$name$ext';
    final path = '$userId/$name';
    await _supabase.storage.from('worker_docs').uploadBinary(
          path,
          fileBytes,
          fileOptions: FileOptions(upsert: true, contentType: _getMimeType(file)),
        );
    return path;
  }

  Future<void> deleteAvatar(String userId) async {
    await _supabase.storage.from('avatars').remove([userId]);
  }

  Future<void> deleteWorkerDoc(String path) async {
    await _supabase.storage.from('worker_docs').remove([path]);
  }

  Future<String> uploadReviewPhoto({
    required String userId,
    required String reviewId,
    required XFile file,
    int sortOrder = 0,
  }) async {
    final fileBytes = await file.readAsBytes();
    final ext = _getExtension(file.name).isEmpty ? '.jpg' : _getExtension(file.name);
    final fileName = '$userId/${reviewId}_$sortOrder$ext';
    await _supabase.storage.from('review_photos').uploadBinary(
      fileName,
      fileBytes,
      fileOptions: FileOptions(upsert: true, contentType: _getMimeType(file)),
    );
    return _supabase.storage.from('review_photos').getPublicUrl(fileName);
  }

  Future<String> uploadCategoryIcon({
    required String categoryId,
    required XFile file,
  }) async {
    final fileBytes = await file.readAsBytes();
    final ext = _getExtension(file.name).isEmpty ? '.png' : _getExtension(file.name);
    final fileName = 'category_icons/$categoryId$ext';
    await _supabase.storage.from('category_icons').uploadBinary(
      fileName,
      fileBytes,
      fileOptions: FileOptions(upsert: true, contentType: _getMimeType(file)),
    );
    return _supabase.storage.from('category_icons').getPublicUrl(fileName);
  }

  String getAvatarUrl(String userId) {
    return _supabase.storage
        .from('avatars')
        .getPublicUrl('$userId/avatar.jpg');
  }

  String _getExtension(String path) {
    final parts = path.split('.');
    return parts.length > 1 ? '.${parts.last}' : '';
  }
}
