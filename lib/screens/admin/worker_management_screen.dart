import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';

import '../../services/worker_service.dart';

final _supabase = Supabase.instance.client;

final adminSearchQueryProvider = StateProvider<String>((ref) => '');
final adminCategoryFilterProvider = StateProvider<String?>((ref) => null);
final adminAreaFilterProvider = StateProvider<String?>((ref) => null);
final adminStatusFilterProvider = StateProvider<String>((ref) => 'All Workers');

final filteredWorkersProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final query = ref.watch(adminSearchQueryProvider);
  final category = ref.watch(adminCategoryFilterProvider);
  final area = ref.watch(adminAreaFilterProvider);
  final status = ref.watch(adminStatusFilterProvider);

  var request = _supabase.from('admin_worker_directory_view').select();

  if (query.isNotEmpty) {
    request = request.ilike('search_text', '%$query%');
  }
  if (category != null && category.isNotEmpty) {
    request = request.contains('categories', [category]);
  }
  if (area != null && area.isNotEmpty) {
    request = request.contains('areas', [area]);
  }
  
  if (status == 'Pending Verification') {
    request = request.eq('is_verified', false);
  }

  final data = await request;
  return List<Map<String, dynamic>>.from(data);
});

class WorkerManagementScreen extends ConsumerStatefulWidget {
  const WorkerManagementScreen({super.key});

  @override
  ConsumerState<WorkerManagementScreen> createState() =>
      _WorkerManagementScreenState();
}

class _WorkerManagementScreenState
    extends ConsumerState<WorkerManagementScreen> {

  @override
  Widget build(BuildContext context) {
    final workers = ref.watch(filteredWorkersProvider);
    final statusFilter = ref.watch(adminStatusFilterProvider);
    final searchQuery = ref.watch(adminSearchQueryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Worker Directory Dashboard')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search workers...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => ref.read(adminSearchQueryProvider.notifier).state = '',
                      )
                    : null,
              ),
              onChanged: (value) => ref.read(adminSearchQueryProvider.notifier).state = value,
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _buildFilterChip('All Workers', statusFilter),
                const SizedBox(width: 8),
                _buildFilterChip('Pending Verification', statusFilter),
              ],
            ),
          ),
          Expanded(
            child: workers.when(
              data: (list) {
                if (list.isEmpty) {
                  return const Center(child: Text('No workers found.'));
                }
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final w = list[i];
                    final String name = w['full_name'] ?? 'Unknown';
                    final String email = w['email'] ?? '';
                    final String avatarUrl = w['avatar_url'] ?? '';
                    final isVerified = w['is_verified'] == true;
                    final isAvailable = w['is_available'] == true;
                    
                    final activeOrders = (w['active_orders_count'] as num?)?.toInt() ?? 0;
                    final pendingOrders = (w['pending_orders_count'] as num?)?.toInt() ?? 0;
                    final completedOrders = (w['completed_orders_count'] as num?)?.toInt() ?? 0;
                    final totalEarnings = (w['total_earnings'] as num?)?.toDouble() ?? 0;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: InkWell(
                        onTap: () => _showWorkerProfile(context, w),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                                    child: avatarUrl.isEmpty ? Text(name.isNotEmpty ? name[0] : 'W') : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                        Text(email, style: TextStyle(fontSize: 13, color: Theme.of(context).hintColor)),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      if (isVerified) _buildVerifiedBadge(),
                                      const SizedBox(height: 4),
                                      _buildAvailabilityBadge(isAvailable),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildMetricBadge('Active: $activeOrders', Colors.blue),
                                  _buildMetricBadge('Pending: $pendingOrders', Colors.amber),
                                  _buildMetricBadge('Done: $completedOrders', Colors.green),
                                  _buildMetricBadge('Earned: ৳${totalEarnings.toStringAsFixed(0)}', Colors.purple),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String currentStatus) {
    final selected = currentStatus == label;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => ref.read(adminStatusFilterProvider.notifier).state = label,
    );
  }

  Widget _buildMetricBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }


  Widget _buildAvailabilityBadge(bool available) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: available
            ? AppColors.success.withValues(alpha: 0.1)
            : AppColors.textHint.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        available ? 'Available' : 'Unavailable',
        style: TextStyle(
          fontSize: 10,
          color: available ? AppColors.success : AppColors.textHint,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildVerifiedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: 12, color: AppColors.info),
          SizedBox(width: 2),
          Text('Verified',
              style: TextStyle(
                  fontSize: 10,
                  color: AppColors.info,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showWorkerProfile(BuildContext context, Map<String, dynamic> w) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _WorkerProfileSheet(
        worker: w,
        onManageDocs: () => _showDocuments(context, w['worker_id']),
      ),
    );
  }


  void _showDocuments(BuildContext context, String workerId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _WorkerDocumentsSheet(workerId: workerId),
    );
  }
}

class _EditWorkerDialog extends StatefulWidget {
  final Map<String, dynamic> worker;
  final VoidCallback onSaved;
  const _EditWorkerDialog({required this.worker, required this.onSaved});

  @override
  State<_EditWorkerDialog> createState() => _EditWorkerDialogState();
}

class _EditWorkerDialogState extends State<_EditWorkerDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _bioController;
  late TextEditingController _rateController;
  late TextEditingController _experienceController;
  late String _mode;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.worker['profiles'] as Map<String, dynamic>?;
    _nameController = TextEditingController(text: profile?['full_name'] ?? '');
    _phoneController = TextEditingController(text: profile?['phone'] ?? '');
    _bioController = TextEditingController(text: widget.worker['bio'] ?? '');
    _rateController = TextEditingController(text: (widget.worker['hourly_rate'] as num?)?.toString() ?? '');
    _experienceController = TextEditingController(text: (widget.worker['experience_years'] as num?)?.toString() ?? '');
    _mode = widget.worker['mode'] ?? 'online';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _rateController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      // 1. Update Profile (Name, Phone)
      await _supabase.from('profiles').update({
        'full_name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
      }).eq('id', widget.worker['profile_id']);

      // 2. Update Worker (Bio, Hourly Rate, Mode, Experience)
      await _supabase.from('workers').update({
        'bio': _bioController.text.trim(),
        'hourly_rate': double.tryParse(_rateController.text.trim()) ?? 0.0,
        'experience_years': int.tryParse(_experienceController.text.trim()) ?? 0,
        'mode': _mode,
      }).eq('id', widget.worker['worker_id']);

      if (mounted) {
        widget.onSaved();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Worker updated successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Worker'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Profile Details', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              const Text('Worker Details', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(labelText: 'Bio'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _rateController,
                      decoration: const InputDecoration(labelText: 'Hourly Rate (৳)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _experienceController,
                      decoration: const InputDecoration(labelText: 'Experience (Years)'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _mode,
                decoration: const InputDecoration(labelText: 'Working Mode'),
                items: const [
                  DropdownMenuItem(value: 'online', child: Text('Online')),
                  DropdownMenuItem(value: 'in-person', child: Text('In-Person')),
                  DropdownMenuItem(value: 'both', child: Text('Both')),
                ],
                onChanged: (v) => setState(() => _mode = v!),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _isLoading ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
        ),
      ],
    );
  }
}

class _WorkerDocumentsSheet extends ConsumerStatefulWidget {
  final String workerId;
  const _WorkerDocumentsSheet({required this.workerId});
  @override
  ConsumerState<_WorkerDocumentsSheet> createState() => _WorkerDocumentsSheetState();
}

class _WorkerDocumentsSheetState extends ConsumerState<_WorkerDocumentsSheet> {
  bool _isLoading = true;
  List<dynamic> _docs = [];

  @override
  void initState() {
    super.initState();
    _loadDocs();
  }

  Future<void> _loadDocs() async {
    final docs = await WorkerService().getWorkerDocuments(widget.workerId);
    if (!mounted) return;
    
    List<Map<String, dynamic>> processedDocs = [];
    for (var doc in docs) {
      final signedUrl = await _supabase.storage.from('worker_docs').createSignedUrl(doc.filePath, 60);
      processedDocs.add({
        'id': doc.id,
        'type': doc.documentType,
        'status': doc.status,
        'url': signedUrl,
      });
    }
    setState(() {
      _docs = processedDocs;
      _isLoading = false;
    });
  }

  Future<void> _updateStatus(String docId, String status, [String? reason]) async {
    await WorkerService().verifyDocument(docId, status, reason);
    await _loadDocs();
  }

  void _rejectDocument(String docId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Reject Document'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Reason for rejection', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (controller.text.isEmpty) return;
              Navigator.pop(c);
              _updateStatus(docId, 'rejected', controller.text);
            },
            child: const Text('Reject', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(height: 300, child: Center(child: CircularProgressIndicator()));
    }
    if (_docs.isEmpty) {
      return const SizedBox(height: 300, child: Center(child: Text('No documents uploaded.')));
    }
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text('Worker Documents', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _docs.length,
              itemBuilder: (ctx, i) {
                final doc = _docs[i];
                return Card(
                  child: Column(
                    children: [
                      ListTile(
                        title: Text(doc['type'].toString().toUpperCase()),
                        subtitle: Text('Status: ${doc['status']}'),
                      ),
                      Image.network(doc['url'], height: 200, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.error, size: 50)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          if (doc['status'] != 'verified')
                            TextButton.icon(
                              icon: const Icon(Icons.check, color: Colors.green),
                              label: const Text('Approve', style: TextStyle(color: Colors.green)),
                              onPressed: () => _updateStatus(doc['id'], 'verified'),
                            ),
                          if (doc['status'] != 'rejected')
                            TextButton.icon(
                              icon: const Icon(Icons.close, color: Colors.red),
                              label: const Text('Reject', style: TextStyle(color: Colors.red)),
                              onPressed: () => _rejectDocument(doc['id']),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkerProfileSheet extends StatelessWidget {
  final Map<String, dynamic> worker;
  final VoidCallback onManageDocs;

  const _WorkerProfileSheet({
    required this.worker,
    required this.onManageDocs,
  });

  @override
  Widget build(BuildContext context) {
    final profile = worker['profiles'] as Map<String, dynamic>?;
    final name = profile?['full_name'] ?? 'Unknown';
    final email = profile?['email'] ?? '';
    final phone = profile?['phone'] ?? '';
    final isVerified = worker['is_verified'] == true;
    final isAvailable = worker['is_available'] == true;
    final avgRating = (worker['avg_rating'] as num?)?.toDouble() ?? 0;
    final totalBookings = (worker['total_bookings'] as num?)?.toInt() ?? 0;
    final bio = worker['bio'] ?? 'No bio provided';
    final experience = (worker['experience_years'] as num?)?.toInt() ?? 0;
    final rate = (worker['hourly_rate'] as num?)?.toDouble() ?? 0.0;
    final mode = worker['mode'] ?? 'online';

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Worker Profile', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurface),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: profile?['avatar_url'] != null ? NetworkImage(profile!['avatar_url'] as String) : null,
                    child: profile?['avatar_url'] == null ? Text(name.toString().isNotEmpty ? name.toString()[0] : 'W', style: const TextStyle(fontSize: 32)) : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(name, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                      if (isVerified) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.verified, color: AppColors.info, size: 20),
                      ]
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(email, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
                  if (phone.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(phone, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
                  ],
                  const SizedBox(height: 24),
                  
                  // Stats row
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(title: 'Total Bookings', value: totalBookings.toString()),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _StatCard(title: 'Rating', value: avgRating.toStringAsFixed(1)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Info cards
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Bio', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 8),
                          Text(bio),
                        ],
                      ),
                    ),
                  ),
                  
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      children: [
                        ListTile(dense: true, title: const Text('Experience'), trailing: Text('$experience years')),
                        const Divider(height: 1),
                        ListTile(dense: true, title: const Text('Hourly Rate'), trailing: Text('৳${rate.toStringAsFixed(2)}')),
                        const Divider(height: 1),
                        ListTile(dense: true, title: const Text('Mode'), trailing: Text(mode.toUpperCase())),
                        const Divider(height: 1),
                        ListTile(dense: true, title: const Text('Availability'), trailing: Text(isAvailable ? 'Available' : 'Unavailable', style: TextStyle(color: isAvailable ? Colors.green : Colors.grey, fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onManageDocs();
                    },
                    icon: const Icon(Icons.file_present),
                    label: const Text('Manage Verification Documents'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Reuse the _StatCard logic (from user_management_screen) or declare a simple one here.
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  const _StatCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary)),
        ],
      ),
    );
  }
}
