import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/custom_button.dart';
import '../../providers/auth_provider.dart';
import '../../providers/area_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/worker_provider.dart';
import '../../services/profile_service.dart';
import '../../services/storage_service.dart';
import '../../services/worker_service.dart';

final _profileServiceProvider =
    Provider<ProfileService>((ref) => ProfileService());
final _storageServiceProvider =
    Provider<StorageService>((ref) => StorageService());
final _workerServiceProvider =
    Provider<WorkerService>((ref) => WorkerService());

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();
  final _hourlyRateController = TextEditingController();
  final _experienceController = TextEditingController();
  final _skillController = TextEditingController();
  final List<String> _skills = [];
  String? _selectedAreaId;
  String? _selectedCategoryId;
  String? _tempAreaToAdd;
  final List<String> _selectedWorkerAreaIds = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  Future<void> _loadProfile() async {
    final authService = ref.read(authServiceProvider);
    final user = authService.currentUser;
    if (user == null) return;

    var profile = ref.read(currentProfileProvider).valueOrNull;
    if (profile == null) {
      try {
        profile = await ref.read(_profileServiceProvider).getProfile(user.id);
      } catch (_) {}
    }
    if (profile != null) {
      _nameController.text = profile.fullName;
      _phoneController.text = profile.phone ?? '';
      _selectedAreaId = profile.areaId;
    }
    final workerData = await _supabase
        .from('workers')
        .select('id, bio, hourly_rate, experience_years, category_id')
        .eq('profile_id', user.id)
        .maybeSingle();
    if (workerData != null) {
      _bioController.text = workerData['bio'] as String? ?? '';
      _selectedCategoryId = workerData['category_id'] as String?;
      final rate = (workerData['hourly_rate'] as num?)?.toDouble() ?? 0;
      _hourlyRateController.text = rate > 0 ? rate.toStringAsFixed(0) : '';
      final exp = (workerData['experience_years'] as num?)?.toInt() ?? 0;
      _experienceController.text = exp > 0 ? exp.toString() : '';

      final skillsData = await _supabase
          .from('worker_skills')
          .select('skill')
          .eq('worker_id', workerData['id']) as List;
      _skills.addAll(
          skillsData.map((e) => (e as Map)['skill'] as String).toList());

      final areasData = await _supabase
          .from('worker_areas')
          .select('area_id')
          .eq('worker_id', workerData['id']) as List;
      _selectedWorkerAreaIds.addAll(
          areasData.map((e) => (e as Map)['area_id'] as String).toList());
      // Make sure primary area is in the list
      if (_selectedAreaId != null && !_selectedWorkerAreaIds.contains(_selectedAreaId)) {
        _selectedWorkerAreaIds.add(_selectedAreaId!);
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _hourlyRateController.dispose();
    _experienceController.dispose();
    _skillController.dispose();
    super.dispose();
  }

  bool _isUploadingAvatar = false;

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
        source: source, maxWidth: 512, maxHeight: 512, imageQuality: 75);
    if (image == null) return;
    
    setState(() => _isUploadingAvatar = true);
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Photo updated!'),
            backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  void _showImagePickerSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final authService = ref.read(authServiceProvider);
      final user = authService.currentUser;
      if (user == null) throw Exception('Not logged in');

      final updates = <String, dynamic>{
        'full_name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'area_id': _selectedAreaId,
      };
      await ref.read(_profileServiceProvider).updateProfile(user.id, updates);

      final profile = ref.read(currentProfileProvider).valueOrNull;
      if (profile?.role == 'worker') {
        final workerData = await _supabase
            .from('workers')
            .select('id')
            .eq('profile_id', user.id)
            .maybeSingle();
        if (workerData != null) {
          final workerId = workerData['id'] as String;
          final workerUpdates = <String, dynamic>{};
          if (_bioController.text.trim().isNotEmpty) {
            workerUpdates['bio'] = _bioController.text.trim();
          }
          if (_selectedCategoryId != null) {
            workerUpdates['category_id'] = _selectedCategoryId;
          }
          final rate = double.tryParse(_hourlyRateController.text) ?? 0;
          if (rate > 0) workerUpdates['hourly_rate'] = rate;
          final exp = int.tryParse(_experienceController.text) ?? 0;
          if (exp > 0) workerUpdates['experience_years'] = exp;
          if (workerUpdates.isNotEmpty) {
            await ref
                .read(_workerServiceProvider)
                .updateWorker(workerId, workerUpdates);
          }
          
          // Update worker_areas
          final existingAreasData = await _supabase
              .from('worker_areas')
              .select('area_id')
              .eq('worker_id', workerId) as List;
          final existingAreas = existingAreasData.map((e) => (e as Map)['area_id'] as String).toSet();
          final newAreas = _selectedWorkerAreaIds.toSet();

          final toAdd = newAreas.difference(existingAreas);
          final toRemove = existingAreas.difference(newAreas);

          final workerService = ref.read(_workerServiceProvider);
          for (final a in toAdd) {
            await workerService.addArea(workerId, a);
          }
          for (final a in toRemove) {
            await workerService.removeArea(workerId, a);
          }
        }
      }

      ref.invalidate(currentProfileProvider);
      ref.invalidate(currentWorkerProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Profile updated!'),
            backgroundColor: AppColors.success),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentProfileProvider);
    final areas = ref.watch(activeAreasProvider);
    final categories = ref.watch(activeCategoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: profile.when(
        data: (p) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Center(
                child: GestureDetector(
                  onTap: _showImagePickerSheet,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundImage: p?.avatarUrl != null
                            ? CachedNetworkImageProvider(p!.avatarUrl!)
                            : null,
                        child: _isUploadingAvatar
                            ? const CircularProgressIndicator()
                            : (p?.avatarUrl == null
                                ? const Icon(Icons.person, size: 48)
                                : null),
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
                            onPressed: _showImagePickerSheet,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  prefixIcon: Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              areas.when(
                data: (areaList) => DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Area',
                    prefixIcon: Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(),
                  ),
                  value: areaList.any((a) => a.id == _selectedAreaId) ? _selectedAreaId : null,
                  items: areaList
                      .map((a) =>
                          DropdownMenuItem(value: a.id, child: Text(a.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedAreaId = v),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              if (p?.role == 'worker') ...[
                const SizedBox(height: 24),
                const Divider(),
                const Text('Worker Details',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                categories.when(
                  data: (catList) => DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Primary Category',
                      prefixIcon: Icon(Icons.category_outlined),
                      border: OutlineInputBorder(),
                    ),
                    initialValue: _selectedCategoryId,
                    items: catList
                        .map((c) =>
                            DropdownMenuItem(value: c.id, child: Text(c.name)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedCategoryId = v),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),
                areas.when(
                  data: (areaList) {
                    final availableAreas = areaList
                        .where((a) => !_selectedWorkerAreaIds.contains(a.id))
                        .toList();
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Service Areas',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                key: ValueKey(_selectedWorkerAreaIds.length),
                                decoration: const InputDecoration(
                                  hintText: 'Select an area...',
                                  border: OutlineInputBorder(),
                                ),
                                initialValue: _tempAreaToAdd,
                                items: availableAreas
                                    .map((a) => DropdownMenuItem(
                                          value: a.id,
                                          child: Text(a.name),
                                        ))
                                    .toList(),
                                onChanged: (v) => setState(() => _tempAreaToAdd = v),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle,
                                  color: AppColors.primary, size: 36),
                              onPressed: () {
                                if (_tempAreaToAdd != null) {
                                  setState(() {
                                    _selectedWorkerAreaIds.add(_tempAreaToAdd!);
                                    _tempAreaToAdd = null;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                        if (_selectedWorkerAreaIds.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: _selectedWorkerAreaIds.map((id) {
                              final name = areaList
                                  .firstWhere((a) => a.id == id,
                                      orElse: () => areaList.first)
                                  .name;
                              return Chip(
                                label: Text(name),
                                onDeleted: () => setState(
                                    () => _selectedWorkerAreaIds.remove(id)),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _bioController,
                  decoration: const InputDecoration(
                    labelText: 'Bio',
                    prefixIcon: Icon(Icons.info_outlined),
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _hourlyRateController,
                  decoration: const InputDecoration(
                    labelText: 'Hourly Rate (BDT)',
                    prefixIcon: Icon(Icons.attach_money),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _experienceController,
                  decoration: const InputDecoration(
                    labelText: 'Experience (Years)',
                    prefixIcon: Icon(Icons.work_outlined),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                const Text('Skills',
                    style:
                        TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _skillController,
                        decoration: const InputDecoration(
                          hintText: 'Add skill...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle,
                          color: AppColors.primary, size: 36),
                      onPressed: () {
                        final s = _skillController.text.trim();
                        if (s.isNotEmpty && !_skills.contains(s)) {
                          setState(() => _skills.add(s));
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
                              onDeleted: () =>
                                  setState(() => _skills.remove(s)),
                            ))
                        .toList(),
                  ),
                ],
              ],
              const SizedBox(height: 32),
              CustomButton(
                label: 'Save Changes',
                isLoading: _isSaving,
                onPressed: _save,
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

final _supabase = Supabase.instance.client;
