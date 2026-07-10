import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/auth_provider.dart';
import '../../providers/worker_provider.dart';
import '../../services/storage_service.dart';
import '../../models/worker_document_model.dart';

class WorkerVerificationScreen extends ConsumerStatefulWidget {
  const WorkerVerificationScreen({super.key});

  @override
  ConsumerState<WorkerVerificationScreen> createState() => _WorkerVerificationScreenState();
}

class _WorkerVerificationScreenState extends ConsumerState<WorkerVerificationScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  String? _uploadingType;

  Future<void> _uploadDocument(String documentType) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() {
        _isUploading = true;
        _uploadingType = documentType;
      });

      final storageService = StorageService();
      final ext = image.name.contains('.') ? '.${image.name.split('.').last}' : '.jpg';
      final fileName = '${documentType}_${DateTime.now().millisecondsSinceEpoch}$ext';
      final path = await storageService.uploadWorkerDoc(
        userId: user.id,
        file: image,
        fileName: fileName,
      );

      final workerService = ref.read(workerServiceProvider);
      final fileSize = await image.length();
      
      await workerService.uploadWorkerDocument({
        'worker_id': user.id,
        'document_type': documentType,
        'file_name': image.name,
        'file_path': path,
        'file_size': fileSize,
        'mime_type': image.mimeType != null && image.mimeType!.isNotEmpty ? image.mimeType! : 'image/jpeg',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document uploaded successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadingType = null;
        });
      }
    }
  }

  Widget _buildDocRow(String title, String type, List<WorkerDocumentModel> docs) {
    // Find the latest document of this type
    WorkerDocumentModel? latestDoc;
    try {
      latestDoc = docs.firstWhere((d) => d.documentType == type);
    } catch (_) {}

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      _buildStatusIndicator(latestDoc),
                    ],
                  ),
                ),
                if (_isUploading && _uploadingType == type)
                  const CircularProgressIndicator()
                else
                  ElevatedButton.icon(
                    onPressed: () => _uploadDocument(type),
                    icon: const Icon(Icons.upload_file),
                    label: Text(latestDoc == null ? 'Upload' : 'Replace'),
                  ),
              ],
            ),
            if (latestDoc != null && latestDoc.status == 'rejected' && latestDoc.rejectionReason != null)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Text(
                  'Reason: ${latestDoc.rejectionReason}',
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(WorkerDocumentModel? doc) {
    if (doc == null) {
      return const Text('Not uploaded', style: TextStyle(color: Colors.grey));
    }
    switch (doc.status) {
      case 'pending':
        return const Text('Pending review', style: TextStyle(color: Colors.orange));
      case 'verified':
        return const Text('Approved', style: TextStyle(color: Colors.green));
      case 'rejected':
        return const Text('Rejected', style: TextStyle(color: Colors.red));
      default:
        return Text(doc.status, style: const TextStyle(color: Colors.grey));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final docsAsync = ref.watch(workerDocumentsProvider(user?.id ?? ''));

    return Scaffold(
      appBar: AppBar(title: const Text('Identity Verification')),
      body: docsAsync.when(
        data: (docs) {
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Please upload a clear photo of your National ID and any relevant trade license or skill certificate. This helps build trust with customers and allows you to start receiving bookings.',
                  style: TextStyle(color: Colors.blue, height: 1.5),
                ),
              ),
              const SizedBox(height: 24),
              _buildDocRow('National ID', 'nid', docs),
              _buildDocRow('Trade License', 'trade_license', docs),
              _buildDocRow('Skill Certificate', 'certificate', docs),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
