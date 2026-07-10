import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/custom_button.dart';
import '../../services/worker_service.dart';
import '../../services/storage_service.dart';
import '../../services/profile_service.dart';
import '../../providers/auth_provider.dart';

final _workerServiceProvider =
    Provider<WorkerService>((ref) => WorkerService());
final _storageServiceProvider =
    Provider<StorageService>((ref) => StorageService());
final _profileServiceProvider =
    Provider<ProfileService>((ref) => ProfileService());

class WorkerProfileSetupScreen extends ConsumerStatefulWidget {
  final String? workerId;
  const WorkerProfileSetupScreen({super.key, this.workerId});

  @override
  ConsumerState<WorkerProfileSetupScreen> createState() =>
      _WorkerProfileSetupScreenState();
}

class _WorkerProfileSetupScreenState
    extends ConsumerState<WorkerProfileSetupScreen> {
  final _bioController = TextEditingController();
  final _skillController = TextEditingController();
  final _areasController = TextEditingController();
  final List<String> _skills = [];
  final List<String> _serviceAreas = [];
  bool _isAvailable = true;
  bool _isSaving = false;
  String? _avatarUrl;

  @override
  void dispose() {
    _bioController.dispose();
    _skillController.dispose();
    _areasController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
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
      setState(() => _avatarUrl = url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final authService = ref.read(authServiceProvider);
      final user = authService.currentUser;
      if (user == null) throw Exception('Not logged in');

      final workerData = await _supabase
          .from('workers')
          .select('id')
          .eq('profile_id', user.id)
          .maybeSingle();

      if (workerData != null) {
        final workerId = workerData['id'] as String;
        await ref.read(_workerServiceProvider).updateWorker(workerId, {
          'bio': _bioController.text.trim(),
          'is_available': _isAvailable,
        });
        for (final skill in _skills) {
          await ref.read(_workerServiceProvider).addSkill(workerId, skill);
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile setup complete!'),
          backgroundColor: AppColors.success,
        ),
      );
      context.go('/worker-shell');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        actions: [
          TextButton(
            onPressed: () => context.go('/worker-shell'),
            child: const Text('Skip'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: AppColors.divider,
                      backgroundImage:
                          _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                      child: _avatarUrl == null
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
                          icon:
                              const Icon(Icons.camera_alt, color: Colors.white),
                          onPressed: _pickImage,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text('Add a profile photo',
                    style: TextStyle(color: AppColors.textSecondary)),
              ),
              const SizedBox(height: 24),
              const Text('Bio',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _bioController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Tell clients about yourself...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Skills',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _skillController,
                      decoration: const InputDecoration(
                        hintText: 'Add a skill...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_circle,
                        color: AppColors.primary, size: 36),
                    onPressed: () {
                      final skill = _skillController.text.trim();
                      if (skill.isNotEmpty && !_skills.contains(skill)) {
                        setState(() => _skills.add(skill));
                        _skillController.clear();
                      }
                    },
                  ),
                ],
              ),
              if (_skills.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _skills
                      .map((s) => Chip(
                            label: Text(s),
                            onDeleted: () => setState(() => _skills.remove(s)),
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 24),
              const Text('Service Areas',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _areasController,
                      decoration: const InputDecoration(
                        hintText: 'Add a service area...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.add_circle,
                        color: AppColors.primary, size: 36),
                    onPressed: () {
                      final area = _areasController.text.trim();
                      if (area.isNotEmpty && !_serviceAreas.contains(area)) {
                        setState(() => _serviceAreas.add(area));
                        _areasController.clear();
                      }
                    },
                  ),
                ],
              ),
              if (_serviceAreas.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _serviceAreas
                      .map((a) => Chip(
                            label: Text(a),
                            onDeleted: () =>
                                setState(() => _serviceAreas.remove(a)),
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 24),
              SwitchListTile(
                title: const Text('Available for Work'),
                value: _isAvailable,
                onChanged: (v) => setState(() => _isAvailable = v),
                activeTrackColor: AppColors.success,
              ),
              const SizedBox(height: 32),
              CustomButton(
                label: 'Save & Continue',
                isLoading: _isSaving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final _supabase = Supabase.instance.client;
