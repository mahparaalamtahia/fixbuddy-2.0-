import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/profile_service.dart';
import '../../services/storage_service.dart';
import '../../providers/area_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/worker_provider.dart';

final _profileServiceProvider =
    Provider<ProfileService>((ref) => ProfileService());
final _storageServiceProvider =
    Provider<StorageService>((ref) => StorageService());

class UserProfileScreen extends ConsumerWidget {
  const UserProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final areas = ref.watch(activeAreasProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: profile.when(
        data: (p) {
          String areaLabel = p?.areaName ?? '';
          if (areaLabel.isEmpty && p?.areaId != null) {
            final areaList = areas.valueOrNull ?? [];
            final matched = areaList.where((a) => a.id == p!.areaId).firstOrNull;
            if (matched != null) areaLabel = matched.name;
          }
          if (areaLabel.isEmpty) areaLabel = 'Not set';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundImage: p?.avatarUrl != null
                          ? CachedNetworkImageProvider(p!.avatarUrl!)
                          : null,
                      child: p?.avatarUrl == null
                          ? const Icon(Icons.person, size: 48)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.primary,
                        child: IconButton(
                          iconSize: 16,
                          icon: const Icon(Icons.camera_alt, color: Colors.white),
                          onPressed: () => _pickImage(context, ref),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(p?.fullName ?? 'User',
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(p?.email ?? '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 24),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.edit_outlined),
                      title: const Text('Edit Profile'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go('/shell/profile/edit'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: const Text('Full Name'),
                      subtitle: Text(p?.fullName ?? ''),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.email_outlined),
                      title: const Text('Email'),
                      subtitle: Text(p?.email ?? ''),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.phone_outlined),
                      title: const Text('Phone'),
                      subtitle: Text(p?.phone ?? 'Not set'),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.location_on_outlined),
                      title: const Text('Area'),
                      subtitle: Text(areaLabel),
                      trailing: const Icon(Icons.edit),
                      onTap: () => _editArea(context, ref, p?.id ?? '', areas),
                    ),
                  ],
                ),
              ),
            if (p?.role == 'worker') ...[
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.dashboard_outlined),
                      title: const Text('Switch to Providing'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final p = ref.read(currentProfileProvider).valueOrNull;
                        if (p != null) {
                          // Fetch worker ID
                          final supabase = Supabase.instance.client;
                          final w = await supabase.from('workers').select('id').eq('profile_id', p.id).maybeSingle();
                          if (w != null) {
                            await ref.read(workerServiceProvider).updateWorker(w['id'], {'mode': 'providing'});
                            ref.invalidate(currentWorkerProvider);
                          }
                        }
                        if (context.mounted) {
                          context.go('/worker-shell');
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.bookmark_outline),
                    title: const Text('My Bookings'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/shell/bookings'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.notifications_outlined),
                    title: const Text('Notifications'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/shell/notifications'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('Notification Preferences'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go('/shell/notifications/prefs'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () async {
                await ref.read(authServiceProvider).signOut();
                if (context.mounted) context.go('/login');
              },
              icon: const Icon(Icons.logout, color: AppColors.error),
              label: const Text('Logout',
                  style: TextStyle(color: AppColors.error)),
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error)),
            ),
          ],
        );
      },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _pickImage(BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 512, maxHeight: 512);
    if (image == null) return;

    try {
      final authService = ref.read(authServiceProvider);
      final userId = authService.currentUser?.id;
      if (userId == null) return;

      final url = await ref
          .read(_storageServiceProvider)
          .uploadAvatar(userId: userId, file: image);
      await ref
          .read(_profileServiceProvider)
          .updateProfile(userId, {'avatar_url': url});
      ref.invalidate(currentProfileProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Photo updated!')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'), backgroundColor: AppColors.error));
      }
    }
  }

  void _editArea(BuildContext context, WidgetRef ref, String userId,
      AsyncValue<List> areas) {
    areas.whenData((areaList) {
      showDialog(
        context: context,
        builder: (ctx) => SimpleDialog(
          title: const Text('Select Area'),
          children: areaList
              .map((area) => SimpleDialogOption(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await ref
                          .read(_profileServiceProvider)
                          .updateProfile(userId, {'area_id': area.id});
                      ref.invalidate(currentProfileProvider);
                    },
                    child: Text(area.name),
                  ))
              .toList(),
        ),
      );
    });
  }
}
