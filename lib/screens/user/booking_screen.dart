import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/custom_button.dart';
import '../../providers/worker_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/area_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/booking_service.dart';
import '../../core/router/app_router.dart';



final _bookingServiceProvider =
    Provider<BookingService>((ref) => BookingService());

class BookingScreen extends ConsumerStatefulWidget {
  final String workerId;
  const BookingScreen({super.key, required this.workerId});

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedTime = const TimeOfDay(hour: 10, minute: 0);
  String? _selectedPeriod;
  String? _selectedCategoryId;
  String? _selectedAreaId;
  int _estimatedHours = 1;
  final String _paymentMethod = 'cash';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final worker = ref.watch(workerByIdProvider(widget.workerId));
    final categories = ref.watch(activeCategoriesProvider);
    final areas = ref.watch(activeAreasProvider);

    final hourlyRate = worker.whenOrNull(data: (w) => w?.hourlyRate) ?? 0;
    final totalCost = hourlyRate * _estimatedHours;

    return Scaffold(
      appBar: AppBar(title: const Text('Book Service')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              worker.when(
                data: (w) => Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: w?.avatarUrl != null
                          ? CachedNetworkImageProvider(w!.avatarUrl!)
                          : null,
                      child: w?.avatarUrl == null
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: Text(w?.fullName ?? 'Worker'),
                    subtitle: Text(
                        '\u09F3${w?.hourlyRate.toStringAsFixed(0) ?? '0'}/hr'),
                  ),
                ),
                loading: () =>
                    const Card(child: ListTile(title: Text('Loading...'))),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),
              const Text('Service Category *',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              categories.when(
                data: (cats) => DropdownButtonFormField<String>(
                  decoration:
                      const InputDecoration(prefixIcon: Icon(Icons.category)),
                  hint: const Text('Select category'),
                  initialValue: _selectedCategoryId,
                  items: cats
                      .map((c) =>
                          DropdownMenuItem(value: c.id, child: Text(c.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCategoryId = v),
                  validator: (v) => v == null ? 'Select a category' : null,
                ),
                loading: () =>
                    DropdownButtonFormField(items: const [], onChanged: null),
                error: (_, __) =>
                    DropdownButtonFormField(items: const [], onChanged: null),
              ),
              const SizedBox(height: 16),
              const Text('Area *',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              areas.when(
                data: (areaList) => DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.location_on)),
                  hint: const Text('Select area'),
                  initialValue: _selectedAreaId,
                  items: areaList
                      .map((a) =>
                          DropdownMenuItem(value: a.id, child: Text(a.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedAreaId = v),
                  validator: (v) => v == null ? 'Select an area' : null,
                ),
                loading: () =>
                    DropdownButtonFormField(items: const [], onChanged: null),
                error: (_, __) =>
                    DropdownButtonFormField(items: const [], onChanged: null),
              ),
              const SizedBox(height: 20),
              const Text('Payment Method',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              _PaymentMethodCard(
                method: 'cash',
                icon: Icons.money,
                label: 'Cash on Service',
                subtitle:
                    'Pay the worker directly in cash after service completion.',
                selected: true,
                onTap: () {}, // Static
              ),
              const SizedBox(height: 20),
              const Text('Estimated Hours',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton.filled(
                    onPressed: _estimatedHours > 1
                        ? () => setState(() => _estimatedHours--)
                        : null,
                    icon: const Icon(Icons.remove),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textOnPrimary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.divider),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$_estimatedHours hr',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton.filled(
                    onPressed: _estimatedHours < 8
                        ? () => setState(() => _estimatedHours++)
                        : null,
                    icon: const Icon(Icons.add),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textOnPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Total: ',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  Text('\u09F3${totalCost.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary)),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Select Date', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: 30,
                  itemBuilder: (context, index) {
                    final date = DateTime.now().add(Duration(days: index + 1));
                    final isSelected = DateUtils.isSameDay(_selectedDate, date);
                    return GestureDetector(
                      onTap: () => setState(() {
                        _selectedDate = date;
                        _selectedPeriod = null; // Reset period when date changes
                      }),
                      child: Container(
                        width: 60,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isSelected ? AppColors.primary : AppColors.divider),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _getShortWeekday(date.weekday),
                              style: TextStyle(
                                fontSize: 12,
                                color: isSelected ? Colors.white : AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              date.day.toString(),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              const Text('Available Slots', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 8),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: Supabase.instance.client.rpc('get_available_slots', params: {
                  'p_worker_id': widget.workerId,
                  'p_date': DateFormatter.apiDate(_selectedDate)
                }).then((res) => (res as List).cast<Map<String, dynamic>>()),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }
                  if (snapshot.hasError) {
                    return const Text('Error loading slots', style: TextStyle(color: AppColors.error));
                  }
                  final slots = snapshot.data ?? [];
                  if (slots.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('No slots available on this date.', style: TextStyle(color: AppColors.error)),
                    );
                  }
                  return Wrap(
                    spacing: 10,
                    children: slots.map((slot) {
                      final period = slot['period'] as String;
                      final isAvailable = slot['is_available'] as bool;
                      final isSelected = _selectedPeriod == period;
                      return ChoiceChip(
                        label: Text(_getPeriodLabel(period)),
                        selected: isSelected,
                        onSelected: isAvailable ? (selected) {
                          if (selected) {
                            setState(() {
                              _selectedPeriod = period;
                              _selectedTime = _getTimeForPeriod(period);
                            });
                          }
                        } : null,
                        backgroundColor: isAvailable ? null : Colors.grey.shade300,
                        labelStyle: TextStyle(color: isAvailable ? null : Colors.grey),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: AppStrings.notes,
                  hintText: 'Describe the job...',
                  prefixIcon: Icon(Icons.note_outlined),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              CustomButton(
                label: 'Confirm Booking',
                isLoading: _isLoading,
                onPressed: _submitBooking,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getShortWeekday(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  String _getPeriodLabel(String period) {
    switch (period) {
      case 'morning': return 'Morning (8am-12pm)';
      case 'afternoon': return 'Afternoon (12pm-4pm)';
      case 'evening': return 'Evening (4pm-8pm)';
      default: return period;
    }
  }

  TimeOfDay _getTimeForPeriod(String period) {
    switch (period) {
      case 'morning': return const TimeOfDay(hour: 9, minute: 0);
      case 'afternoon': return const TimeOfDay(hour: 14, minute: 0);
      case 'evening': return const TimeOfDay(hour: 17, minute: 0);
      default: return const TimeOfDay(hour: 10, minute: 0);
    }
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPeriod == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an available time slot.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final bookingService = ref.read(_bookingServiceProvider);
      final authService = ref.read(authServiceProvider);
      final user = authService.currentUser;
      if (user == null) throw Exception('Not logged in');

      final worker = await ref.read(workerByIdProvider(widget.workerId).future);
      final hourlyRate = worker?.hourlyRate ?? 0;
      final totalAmount = hourlyRate * _estimatedHours;

      final booking = await bookingService.createBooking({
        'user_id': user.id,
        'worker_id': widget.workerId,
        'category_id': _selectedCategoryId,
        'area_id': _selectedAreaId,
        'scheduled_date': DateFormatter.apiDate(_selectedDate),
        'scheduled_time':
            '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}:00',
        'notes': _notesController.text.trim(),
        'total_amount': totalAmount,
      });

      analyticsService.trackEvent(AnalyticsService.bookingCreated);

      if (!mounted) return;
      context.go('/shell/book/confirm', extra: {
        'id': booking.id,
        'worker_name': booking.workerName,
        'category_name': booking.categoryName,
        'scheduled_date': DateFormatter.formatDate(_selectedDate),
        'scheduled_time': _selectedTime.format(context),
        'total_amount': totalAmount,
        'payment_method': _paymentMethod,
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
}

class _PaymentMethodCard extends StatelessWidget {
  final String method;
  final IconData icon;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _PaymentMethodCard({
    required this.method,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textSecondary;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.divider,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: selected
                                ? AppColors.primary
                                : AppColors.textPrimary)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              if (selected)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 16, color: Colors.white),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
