import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/worker_provider.dart';
import '../../models/worker_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/chat_service.dart';

class WorkerProfileScreen extends ConsumerWidget {
  final String workerId;
  const WorkerProfileScreen({super.key, required this.workerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workerAsync = ref.watch(workerByIdProvider(workerId));

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: workerAsync.when(
        data: (worker) => worker == null
            ? const Center(child: Text('Worker not found', style: TextStyle(color: Colors.white)))
            : _WorkerProfileContent(worker: worker),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
      ),
    );
  }
}

class _WorkerProfileContent extends StatefulWidget {
  final WorkerModel worker;
  const _WorkerProfileContent({required this.worker});

  @override
  State<_WorkerProfileContent> createState() => _WorkerProfileContentState();
}

class _WorkerProfileContentState extends State<_WorkerProfileContent> {
  @override
  Widget build(BuildContext context) {
    final worker = widget.worker;
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isOwnProfile = currentUserId == worker.profileId;

    return Stack(
      children: [
        // Main content
        ListView(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 60,
            left: 20,
            right: 20,
            bottom: 120, // Space for bottom bar
          ),
          children: [
            _buildHeroCard(worker),
            const SizedBox(height: 24),
            _buildAboutSection(worker),
            const SizedBox(height: 24),
            _buildLogisticsGrid(worker),
            const SizedBox(height: 24),
            _buildSectorsAndSkills(worker),
            const SizedBox(height: 24),
            _buildVerificationStatus(),
          ],
        ),

        // App Bar overlay
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top,
              left: 20,
              right: 20,
              bottom: 8,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.9),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCircularButton(
                  icon: Icons.arrow_back,
                  onTap: () => context.pop(),
                ),
                const Text(
                  'Professional Profile',
                  style: TextStyle(
                    color: Color(0xFFF1F5F9),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isOwnProfile)
                  _buildCircularButton(
                    icon: Icons.edit,
                    onTap: () => context.push('/worker-shell/profile'),
                  )
                else
                  const SizedBox(width: 40), // Placeholder to balance title
              ],
            ),
          ),
        ),

        // Bottom Action Bar
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildBottomActionBar(context, worker, isOwnProfile),
        ),
      ],
    );
  }

  Widget _buildHeroCard(WorkerModel worker) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Stack(
        children: [
          // Verified Badge
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
                mainAxisSize: MainAxisSize.min,
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
              // Avatar
              Stack(
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF2563eb).withValues(alpha: 0.2), width: 4),
                    ),
                    child: ClipOval(
                      child: worker.avatarUrl != null
                          ? CachedNetworkImage(imageUrl: worker.avatarUrl!, fit: BoxFit.cover)
                          : const Icon(Icons.person, size: 64, color: Colors.grey),
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
              
              // Name & Details
              Text(
                worker.fullName ?? 'Professional',
                style: const TextStyle(color: Color(0xFFF1F5F9), fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  // Category Tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563eb).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: const Color(0xFF2563eb).withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      worker.categories?.isNotEmpty == true ? (worker.categories!.first.name ?? 'Service Professional') : 'Service Professional',
                      style: const TextStyle(color: Color(0xFF2563eb), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  
                  // Rating Tag
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
                        const Icon(Icons.star, color: Color(0xFFfea619), size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${worker.avgRating.toStringAsFixed(1)} Rating',
                          style: const TextStyle(color: Color(0xFFfea619), fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  
                  // Experience Tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF475569).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: const Color(0xFF475569).withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      '${worker.experienceYears} Years Experience',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection(WorkerModel worker) {
    return Container(
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
              Icon(Icons.person_search, color: Color(0xFF2563eb)),
              SizedBox(width: 8),
              Text('About the Professional', style: TextStyle(color: Color(0xFFF1F5F9), fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            worker.bio?.isNotEmpty == true ? worker.bio! : 'No biography provided yet.',
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildLogisticsGrid(WorkerModel worker) {
    return Row(
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
                const Text('HOURLY BASE RATE', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('৳ ${worker.hourlyRate.toStringAsFixed(0)}', style: const TextStyle(color: Color(0xFFF1F5F9), fontSize: 24, fontWeight: FontWeight.bold)),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 4, left: 4),
                      child: Text(' / hr', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ACTIVE AVAILABILITY', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(worker.isAvailable ? Icons.check_circle : Icons.cancel, color: worker.isAvailable ? const Color(0xFF4edea3) : Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Text(worker.isAvailable ? 'Available Now' : 'Unavailable', style: TextStyle(color: worker.isAvailable ? const Color(0xFF4edea3) : Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectorsAndSkills(WorkerModel worker) {
    return Column(
      children: [
        // Operational Sectors
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Operational Sectors', style: TextStyle(color: Color(0xFFF1F5F9), fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: (worker.serviceAreas?.isNotEmpty == true ? worker.serviceAreas!.map((a) => a.name ?? 'Unknown').toList() : ['All Areas']).map((area) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563eb).withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2563eb).withValues(alpha: 0.3)),
                  ),
                  child: Text(area, style: const TextStyle(color: Color(0xFF2563eb), fontSize: 14)),
                )).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Verified Skills
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Verified Skills Inventory', style: TextStyle(color: Color(0xFFF1F5F9), fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: (worker.skills?.isNotEmpty == true ? worker.skills! : ['General Maintenance']).map((skill) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF475569)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.handyman, color: Color(0xFF94A3B8), size: 16),
                      const SizedBox(width: 8),
                      Text(skill, style: const TextStyle(color: Color(0xFFF1F5F9), fontSize: 14)),
                    ],
                  ),
                )).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationStatus() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Trust & Verification Status', style: TextStyle(color: Color(0xFFF1F5F9), fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildVerifyItem(Icons.shield, 'National NID Identification Verified'),
          const SizedBox(height: 16),
          _buildVerifyItem(Icons.domain_verification, 'Commercial Trade License Verified'),
          const SizedBox(height: 16),
          _buildVerifyItem(Icons.card_membership, 'Professional Certifications Attached'),
        ],
      ),
    );
  }

  Widget _buildVerifyItem(IconData icon, String text) {
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
        Expanded(child: Text(text, style: const TextStyle(color: Color(0xFFF1F5F9), fontSize: 14))),
      ],
    );
  }

  Widget _buildBottomActionBar(BuildContext context, WorkerModel worker, bool isOwnProfile) {
    // If it's the worker viewing their own profile, we might show a different nav or nothing.
    // For now, if they are the worker, they don't book themselves.
    if (isOwnProfile) {
      return Container(
        height: 80,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildNavItem(Icons.home, 'Home', false, () => context.go('/worker-shell')),
            _buildNavItem(Icons.receipt_long, 'Activity', false, () => context.go('/worker-shell/history')),
            _buildNavItem(Icons.person, 'Profile', true, () {}),
          ],
        ),
      );
    }

    // Otherwise, show the Chat & Book buttons for normal users
    return Container(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 28),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.95),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Row(
        children: [
          // Chat Button
          InkWell(
            onTap: () async {
              final currentUser = Supabase.instance.client.auth.currentUser;
              if (currentUser == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to chat')));
                return;
              }
              try {
                final bookingsResponse = await Supabase.instance.client
                    .from('bookings')
                    .select('id')
                    .eq('user_id', currentUser.id)
                    .eq('worker_id', worker.id)
                    .order('created_at', ascending: false)
                    .limit(1);

                String? bookingId;
                if ((bookingsResponse as List).isNotEmpty) {
                  bookingId = bookingsResponse.first['id'] as String;
                }
                final chatId = await ChatService().getOrCreateChat(
                  userId: currentUser.id,
                  workerId: worker.id,
                  bookingId: bookingId,
                );
                if (context.mounted) {
                  context.push('/shell/chat/$chatId');
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error creating chat: $e')));
                }
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: const Icon(Icons.chat_bubble_outline, color: Color(0xFF2563eb)),
            ),
          ),
          const SizedBox(width: 16),
          // Call Button
          InkWell(
            onTap: () async {
              if (worker.phone == null || worker.phone!.isEmpty) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No phone number available for this professional')));
                }
                return;
              }
              final cleanPhone = worker.phone!.replaceAll(RegExp(r'[\s\-]'), '');
              final Uri telUrl = Uri.parse('tel:$cleanPhone');
              if (await canLaunchUrl(telUrl)) {
                await launchUrl(telUrl);
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch phone dialer')));
                }
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: const Icon(Icons.call_outlined, color: Color(0xFF2563eb)),
            ),
          ),
          const SizedBox(width: 16),
          // Book Button
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563eb),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: () => context.push('/shell/book', extra: worker.id),
              child: const Text('Book Service Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: isActive ? const Color(0xFF2563eb) : const Color(0xFF94A3B8)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: isActive ? const Color(0xFF2563eb) : const Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildCircularButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Icon(icon, color: const Color(0xFFF1F5F9), size: 20),
      ),
    );
  }
}
