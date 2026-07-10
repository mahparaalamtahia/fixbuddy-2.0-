import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

final profileUpdateProvider =
    FutureProvider.family<void, Map<String, dynamic>>((ref, updates) async {
  final authService = ref.watch(authServiceProvider);
  final profileService = ref.watch(profileServiceProvider);
  final user = authService.currentUser;
  if (user == null) throw Exception('Not logged in');
  await profileService.updateProfile(user.id, updates);
  ref.invalidate(currentProfileProvider);
});
