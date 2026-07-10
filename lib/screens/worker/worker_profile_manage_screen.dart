import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import 'package:go_router/go_router.dart';
import '../../providers/worker_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/area_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/storage_service.dart';

final _storageServiceProvider = Provider<StorageService>((ref) => StorageService());

class WorkerProfileManageScreen extends ConsumerStatefulWidget {
  const WorkerProfileManageScreen({super.key});

  @override
  ConsumerState<WorkerProfileManageScreen> createState() => _WorkerProfileManageScreenState();
}

class _WorkerProfileManageScreenState extends ConsumerState<WorkerProfileManageScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();
  final _skillController = TextEditingController();
  final _rateController = TextEditingController();
  final _expController = TextEditingController();
  final _picker = ImagePicker();

  double _hourlyRate = 0;
  final List<String> _selectedAreaIds = [];
  final List<String> _newSkillList = [];
  final _selectedCategoryIds = <String>{};
  bool _isInitialized = false;
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _skillController.dispose();
    _rateController.dispose();
    _expController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final worker = ref.watch(currentWorkerProvider);
    final categories = ref.watch(activeCategoriesProvider);
    final areas = ref.watch(activeAreasProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A).withValues(alpha: 0.8),
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFF1F5F9)),
          onPressed: () => context.pop(),
        ),
        title: Text(_isEditing ? 'Manage Profile' : 'Professional Profile', style: const TextStyle(color: Color(0xFFF1F5F9), fontWeight: FontWeight.bold, fontSize: 20)),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit, color: Color(0xFFF1F5F9)),
              onPressed: () => setState(() => _isEditing = true),
            )
          else
            TextButton(
              onPressed: () {
                setState(() {
                  _isEditing = false;
                  // Reset form fields
                  _isInitialized = false; 
                });
              },
              child: const Text('CANCEL', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold, fontSize: 12)),
            ),
        ],
      ),
      body: worker.when(
        data: (w) {
          if (w != null && !_isInitialized) {
            _nameController.text = w.fullName ?? '';
            _phoneController.text = w.phone ?? '';
            _hourlyRate = w.hourlyRate.toDouble();
            _rateController.text = w.hourlyRate.toStringAsFixed(0);
            _expController.text = w.experienceYears.toString();
            _bioController.text = w.bio ?? '';
            _selectedCategoryIds.clear();
            if (w.categories != null) {
              _selectedCategoryIds.addAll(w.categories!.map((c) => c.categoryId as String));
            }
            if (w.serviceAreas != null) {
              _selectedAreaIds.addAll(w.serviceAreas!.map((a) => a.areaId!).where((id) => id.isNotEmpty));
            } else if (w.areaId != null) {
              _selectedAreaIds.add(w.areaId!);
            }
            _isInitialized = true;
          }
          return Stack(
            children: [
              SingleChildScrollView(
                padding: EdgeInsets.only(left: 20, right: 20, top: 16, bottom: _isEditing ? 100 : 20),
                child: _isEditing
                    ? _buildEditView(w, categories.valueOrNull, areas.valueOrNull)
                    : _buildReadOnlyView(w, categories.valueOrNull, areas.valueOrNull),
              ),

              if (_isEditing)
              // Footer: Sticky Save Button
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.9),
                    border: const Border(top: BorderSide(color: Color(0xFF334155))),
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563eb),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 8,
                    ),
                    onPressed: w != null && !_isSaving ? () => _save(w) : null,
                    child: _isSaving
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.save),
                              SizedBox(width: 8),
                              Text('Save Changes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    String? prefixText,
    String? suffixText,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (prefixText != null) Text(prefixText, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 16)),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              style: const TextStyle(color: Color(0xFFF1F5F9), fontSize: 16),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (suffixText != null) Text(suffixText, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildTextAreaField({
    required TextEditingController controller,
    required String hint,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: TextField(
        controller: controller,
        maxLines: 4,
        style: const TextStyle(color: Color(0xFFF1F5F9), fontSize: 16),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
          border: InputBorder.none,
          isDense: true,
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildSkillChip(String label, {required VoidCallback onDeleted}) {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 12, top: 6, bottom: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF334155),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: const Color(0xFF475569)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFFF1F5F9), fontSize: 14)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDeleted,
            child: const Icon(Icons.close, color: Color(0xFFF1F5F9), size: 16),
          ),
        ],
      ),
    );
  }



  bool _isUploadingAvatar = false;

  void _showImagePickerSheet(dynamic worker) {
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
                _pickImage(ImageSource.camera, worker);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery, worker);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection(dynamic worker) {
    final avatarUrl = worker?.avatarUrl as String?;
    final ImageProvider? bgImage;
    if (avatarUrl != null) {
      bgImage = NetworkImage(avatarUrl);
    } else {
      bgImage = null;
    }

    return GestureDetector(
      onTap: () => _showImagePickerSheet(worker),
      child: Stack(
        children: [
          Container(
            width: 128,
            height: 128,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF2563eb).withValues(alpha: 0.2), width: 4),
            ),
            child: CircleAvatar(
              backgroundColor: const Color(0xFF1E293B),
              backgroundImage: bgImage,
              child: _isUploadingAvatar 
                  ? const CircularProgressIndicator()
                  : (avatarUrl == null
                      ? const Icon(Icons.person, size: 48, color: Colors.grey)
                      : null),
            ),
          ),
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2563eb),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF0F172A), width: 2),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: const Icon(Icons.edit, size: 20, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source, dynamic worker) async {
    final file = await _picker.pickImage(source: source, imageQuality: 80, maxWidth: 512, maxHeight: 512);
    if (file == null) return;
    
    setState(() => _isUploadingAvatar = true);
    try {
      final profile = await ref.read(currentProfileProvider.future);
      final profileId = profile?.id ?? worker.profileId;
      if (profileId == null) return;

      final url = await ref.read(_storageServiceProvider).uploadAvatar(userId: profileId, file: file);
      await ref.read(profileServiceProvider).updateProfile(profileId, {'avatar_url': url});
      
      ref.invalidate(currentProfileProvider);
      ref.invalidate(currentWorkerProvider);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo updated!'), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }



  Future<void> _save(worker) async {
    setState(() => _isSaving = true);
    try {
      final profile = await ref.read(currentProfileProvider.future);
      final profileId = profile?.id ?? worker.profileId;
      final workerId = worker.id;
      final workerService = ref.read(workerServiceProvider);
      final profileService = ref.read(profileServiceProvider);

      final profileUpdates = <String, dynamic>{};
      if (_nameController.text.trim().isNotEmpty) profileUpdates['full_name'] = _nameController.text.trim();
      if (_phoneController.text.trim().isNotEmpty) profileUpdates['phone'] = _phoneController.text.trim();
      if (_selectedAreaIds.isNotEmpty) profileUpdates['area_id'] = _selectedAreaIds.first;

      if (profileUpdates.isNotEmpty) await profileService.updateProfile(profileId, profileUpdates);

      final currentAreas = worker.serviceAreas?.map((a) => a.areaId).toList() ?? [];
      final areasToAdd = _selectedAreaIds.where((id) => !currentAreas.contains(id)).toList();
      final areasToRemove = currentAreas.where((id) => !_selectedAreaIds.contains(id)).toList();

      for (final id in areasToAdd) {
        await workerService.addArea(workerId, id);
      }
      for (final id in areasToRemove) {
        if (id != null) {
          await workerService.removeArea(workerId, id);
        }
      }

      final workerUpdates = <String, dynamic>{
        'bio': _bioController.text.trim(),
        'hourly_rate': _hourlyRate.round(),
        'experience_years': int.tryParse(_expController.text.trim()) ?? 0,
      };
      await workerService.updateWorker(workerId, workerUpdates);

      final currentCats = worker.categories?.map((c) => c.categoryId).toList() ?? [];
      final catsToAdd = _selectedCategoryIds.where((id) => !currentCats.contains(id)).toList();
      final catsToRemove = currentCats.where((id) => !_selectedCategoryIds.contains(id)).toList();

      for (final id in catsToAdd) {
        await workerService.addCategory(workerId, id);
      }
      for (final id in catsToRemove) {
        if (id != null) {
          await workerService.removeCategory(workerId, id);
        }
      }

      for (final skill in _newSkillList) {
        await workerService.addSkill(workerId, skill);
      }
      _newSkillList.clear();



      ref.invalidate(currentWorkerProvider);
      ref.invalidate(currentProfileProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully!'), backgroundColor: AppColors.success));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _isSaving = false);
      if (mounted) setState(() => _isEditing = false);
    }
  }

  Widget _buildEditView(w, cats, areaList) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Segment 1: Avatar & Basic Info
        Center(
          child: Column(
            children: [
              _buildPhotoSection(w),
              const SizedBox(height: 32),
            ],
          ),
        ),
        _buildInputLabel('Full Name'),
        _buildInputField(
          controller: _nameController,
          hint: 'Emon',
        ),
        const SizedBox(height: 16),
        _buildInputLabel('Phone Number'),
        _buildInputField(
          controller: _phoneController,
          hint: '01745787878',
          prefixText: '+88  ',
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 32),

        // Segment 2: Bio & Category
        _buildInputLabel('Bio'),
        _buildTextAreaField(
          controller: _bioController,
          hint: 'Professional plumber with 5+ years of experience in leak detection and bathroom fittings...',
        ),
        const SizedBox(height: 16),
        _buildInputLabel('Primary Category'),
        if (cats != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: null,
                    isExpanded: true,
                    hint: const Text('Add a category', style: TextStyle(color: Color(0xFF94A3B8))),
                    dropdownColor: const Color(0xFF1E293B),
                    icon: const Icon(Icons.add_circle_outline, color: Color(0xFF94A3B8)),
                    items: (cats as List<dynamic>)
                        .where((c) => !_selectedCategoryIds.contains(c.id))
                        .map((cat) => DropdownMenuItem<String>(
                      value: cat.id,
                      child: Text(cat.name, style: const TextStyle(color: Color(0xFFF1F5F9))),
                    )).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _selectedCategoryIds.add(v));
                      }
                    },
                  ),
                ),
              ),
              if (_selectedCategoryIds.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectedCategoryIds.map((id) {
                    final match = cats.where((c) => c.id == id);
                    final catName = match.isNotEmpty ? match.first.name : 'Unknown';
                    return Container(
                      padding: const EdgeInsets.only(left: 12, right: 8, top: 6, bottom: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(catName, style: const TextStyle(color: Color(0xFF10B981), fontSize: 14)),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => setState(() => _selectedCategoryIds.remove(id)),
                            child: const Icon(Icons.close, color: Color(0xFF10B981), size: 18),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          )
        else const LinearProgressIndicator(),
        const SizedBox(height: 32),

        // Segment 3: Rate & Experience
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInputLabel('Hourly Rate'),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Standard Rate', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563eb).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFF2563eb).withValues(alpha: 0.3)),
                              ),
                              child: Text('৳ ${_hourlyRate.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFF2563eb), fontWeight: FontWeight.bold, fontSize: 14)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 6,
                            thumbColor: const Color(0xFF2563eb),
                            activeTrackColor: const Color(0xFF2563eb),
                            inactiveTrackColor: const Color(0xFF334155),
                            overlayColor: const Color(0xFF2563eb).withValues(alpha: 0.2),
                          ),
                          child: Slider(
                            value: _hourlyRate.clamp(0, 5000),
                            min: 0,
                            max: 5000,
                            divisions: 100,
                            onChanged: (v) {
                              setState(() {
                                _hourlyRate = v;
                                _rateController.text = v.toStringAsFixed(0);
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInputLabel('Experience'),
                  _buildInputField(
                    controller: _expController,
                    hint: '5',
                    keyboardType: TextInputType.number,
                    suffixText: 'YEARS',
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Segment 4: Area & Skills
        _buildInputLabel('Service Areas'),
        if (areaList != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: null,
                    isExpanded: true,
                    hint: const Text('Add an area', style: TextStyle(color: Color(0xFF94A3B8))),
                    dropdownColor: const Color(0xFF1E293B),
                    icon: const Icon(Icons.add_location, color: Color(0xFF94A3B8)),
                    items: (areaList as List<dynamic>)
                        .where((a) => !_selectedAreaIds.contains(a.id))
                        .map((a) => DropdownMenuItem<String>(
                      value: a.id,
                      child: Text(a.name, style: const TextStyle(color: Color(0xFFF1F5F9))),
                    )).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _selectedAreaIds.add(v));
                      }
                    },
                  ),
                ),
              ),
              if (_selectedAreaIds.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectedAreaIds.map((id) {
                    final match = areaList.where((a) => a.id == id);
                    final areaName = match.isNotEmpty ? match.first.name : 'Unknown';
                    return Container(
                      padding: const EdgeInsets.only(left: 12, right: 8, top: 6, bottom: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563eb).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: const Color(0xFF2563eb).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(areaName, style: const TextStyle(color: Color(0xFF2563eb), fontSize: 14)),
                          const SizedBox(width: 4),
                          GestureDetector(
                            onTap: () => setState(() => _selectedAreaIds.remove(id)),
                            child: const Icon(Icons.close, color: Color(0xFF2563eb), size: 18),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          )
        else const LinearProgressIndicator(),
        const SizedBox(height: 24),
        _buildInputLabel('Specialized Skills'),
        Row(
          children: [
            Expanded(
              child: _buildInputField(
                controller: _skillController,
                hint: 'Add a skill (e.g. PVC Leakage)',
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () {
                final text = _skillController.text.trim();
                if (text.isNotEmpty && !_newSkillList.contains(text)) {
                  setState(() => _newSkillList.add(text));
                  _skillController.clear();
                }
              },
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563eb),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: const Icon(Icons.add, color: Colors.white),
              ),
            ),
          ],
        ),
        if ((w?.skills?.isNotEmpty == true) || _newSkillList.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...((w?.skills ?? [])).map((s) => _buildSkillChip(s, onDeleted: () {
                ref.read(workerServiceProvider).removeSkill(w!.id, s);
                ref.invalidate(currentWorkerProvider);
              })),
              ..._newSkillList.map((s) => _buildSkillChip(s, onDeleted: () => setState(() => _newSkillList.remove(s)))),
            ],
          ),
        ],
        const SizedBox(height: 32),

        // Segment 5: Schedule & Docs
        GestureDetector(
          onTap: () => context.go('/worker-shell/availability'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563eb).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.schedule, color: Color(0xFF2563eb), size: 20),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Weekly Schedule', style: TextStyle(color: Color(0xFFF1F5F9), fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('9:00 AM - 6:00 PM, Sun-Thu', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: () => context.go('/worker-shell/verification'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4edea3).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified_user, color: Color(0xFF4edea3), size: 20),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Verification Documents', style: TextStyle(color: Color(0xFFF1F5F9), fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('NID, Trade License, Certificates', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyView(w, cats, areaList) {
    String primaryCategory = 'Professional';
    if (w?.categories?.isNotEmpty == true && cats != null) {
      try {
        final match = (cats as List<dynamic>).firstWhere((c) => c.id == w.categories!.first.categoryId);
        primaryCategory = match.name;
      } catch (_) {}
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Component 1: Hero Card
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 15, offset: const Offset(0, 8)),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF006242).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: const Color(0xFF006242).withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.verified, color: Color(0xFF4edea3), size: 16),
                      SizedBox(width: 4),
                      Text('Verified', style: TextStyle(color: Color(0xFF4edea3), fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF2563eb).withValues(alpha: 0.2), width: 4),
                        ),
                        child: CircleAvatar(
                          backgroundColor: const Color(0xFF0F172A),
                          backgroundImage: w?.avatarUrl != null ? NetworkImage(w!.avatarUrl!) : null,
                          child: w?.avatarUrl == null ? const Icon(Icons.person, size: 48, color: Colors.grey) : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: const Color(0xFF006242),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF1E293B), width: 2),
                          ),
                          child: const Icon(Icons.check, color: Colors.white, size: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(w?.fullName ?? 'Unknown', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563eb).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: const Color(0xFF2563eb).withValues(alpha: 0.2)),
                        ),
                        child: Text(primaryCategory, style: const TextStyle(color: Color(0xFF3b82f6), fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF855300).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: const Color(0xFF855300).withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, color: Color(0xFFfea619), size: 16),
                            const SizedBox(width: 4),
                            Text('${w?.rating?.toStringAsFixed(1) ?? "0.0"} Rating', style: const TextStyle(color: Color(0xFFfea619), fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF475569).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: const Color(0xFF475569).withValues(alpha: 0.2)),
                        ),
                        child: Text('${w?.experienceYears ?? 0} Years Experience', style: const TextStyle(color: Color(0xFF94a3b8), fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Component 2: About Section
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.person_search, color: Color(0xFF3b82f6)),
                  SizedBox(width: 8),
                  Text('About the Professional', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 12),
              Text(w?.bio ?? 'No bio provided.', style: const TextStyle(color: Color(0xFF94a3b8), fontSize: 16, height: 1.5)),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Component 3: Service Logistics Grid
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('HOURLY BASE RATE', style: TextStyle(color: Color(0xFF94a3b8), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('৳ ${w?.hourlyRate ?? 0}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                        const Padding(
                          padding: EdgeInsets.only(bottom: 4),
                          child: Text(' / hr', style: TextStyle(color: Color(0xFF94a3b8), fontSize: 16)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ACTIVE AVAILABILITY', style: TextStyle(color: Color(0xFF94a3b8), fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: Color(0xFF4edea3), size: 24),
                        SizedBox(width: 8),
                        Text('Available', style: TextStyle(color: Color(0xFF4edea3), fontSize: 14, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Component 4: Sectors & Skills
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Operational Sectors', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: (w?.serviceAreas ?? []).map<Widget>((a) {
                  final match = (areaList as List<dynamic>?)?.where((area) => area.id == a.areaId);
                  final areaName = match?.isNotEmpty == true ? match!.first.name : 'Unknown';
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3b82f6).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF3b82f6).withValues(alpha: 0.3)),
                    ),
                    child: Text(areaName, style: const TextStyle(color: Color(0xFF3b82f6), fontSize: 14)),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Verified Skills Inventory', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: (w?.skills ?? []).map<Widget>((s) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF475569)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.build, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(s, style: const TextStyle(color: Colors.white, fontSize: 14)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Component 5: Verification Status
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Trust & Verification Status', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              Column(
                children: [
                  _buildVerificationRow(Icons.shield, 'National NID Identification Verified'),
                  const SizedBox(height: 16),
                  _buildVerificationRow(Icons.domain_verification, 'Commercial Trade License Verified'),
                  const SizedBox(height: 16),
                  _buildVerificationRow(Icons.card_membership, 'Professional Certifications Attached'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationRow(IconData icon, String title) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF006242).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF4edea3), size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16))),
      ],
    );
  }
}
