import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../models/profile_model.dart';
import '../services/profile_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final profileServiceProvider =
    Provider<ProfileService>((ref) => ProfileService());

final authStateProvider = StreamProvider<AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authState;
});

final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.value?.session?.user;
});

final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});

/// Real-time stream of the current user's profile row.
/// Uses Supabase `.stream()` so the dashboard always reflects live DB state
/// for the authenticated user — never stale or cached data.
final currentProfileProvider = StreamProvider<ProfileModel?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(null);

  final service = ref.read(profileServiceProvider);
  return Supabase.instance.client
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('id', user.id)
      .asyncMap((rows) async {
        if (rows.isEmpty) return null;
        try {
          final p = await service.getProfile(user.id);
          if (p != null) return p;
        } catch (_) {}
        return ProfileModel.fromJson(rows.first);
      });
});

final userRoleProvider = Provider<String?>((ref) {
  final profile = ref.watch(currentProfileProvider).valueOrNull;
  return profile?.role;
});
