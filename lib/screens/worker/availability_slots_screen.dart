import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/custom_button.dart';
import '../../providers/worker_provider.dart';
import '../../providers/availability_provider.dart';

final _dayNames = [
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

const _periods = ['morning', 'afternoon', 'evening'];
const _periodLabels = {
  'morning': 'Morning\n6AM-12PM',
  'afternoon': 'Afternoon\n12PM-6PM',
  'evening': 'Evening\n6PM-12AM',
};

class AvailabilitySlotsScreen extends ConsumerStatefulWidget {
  const AvailabilitySlotsScreen({super.key});

  @override
  ConsumerState<AvailabilitySlotsScreen> createState() =>
      _AvailabilitySlotsScreenState();
}

class _AvailabilitySlotsScreenState
    extends ConsumerState<AvailabilitySlotsScreen> {
  late Set<String> _selected;
  bool _isSaving = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _selected = {};
  }

  String _key(int day, String period) => '$day-$period';

  @override
  Widget build(BuildContext context) {
    final worker = ref.watch(currentWorkerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Weekly Availability')),
      body: worker.when(
        data: (w) {
          if (w == null) {
            return const Center(child: Text('Worker not found'));
          }
          if (!_loaded) {
            _loadExisting(w.id);
          }
          return _buildBody(w.id);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  void _loadExisting(String workerId) {
    ref.read(availabilitySlotsProvider(workerId).future).then((slots) {
      if (!mounted) return;
      setState(() {
        for (final s in slots) {
          if (s.isAvailable) {
            _selected.add(_key(s.dayOfWeek, s.period));
          }
        }
        _loaded = true;
      });
    });
  }

  Widget _buildBody(String workerId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.grey[900]! : Colors.grey[50]!;

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Tap on time slots to toggle your availability.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: 7,
            itemBuilder: (_, day) => _buildDayRow(day, workerId, bgColor),
          ),
        ),
        _buildBottomBar(workerId),
      ],
    );
  }

  Widget _buildDayRow(int day, String workerId, Color bgColor) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 90,
              child: Text(
                _dayNames[day],
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                children: _periods.map((period) {
                  final key = _key(day, period);
                  final on = _selected.contains(key);
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          if (on) {
                            _selected.remove(key);
                          } else {
                            _selected.add(key);
                          }
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: on ? AppColors.primary : bgColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: on ? AppColors.primary : AppColors.divider,
                          ),
                        ),
                        child: Text(
                          _periodLabels[period]!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight:
                                on ? FontWeight.w600 : FontWeight.normal,
                            color: on ? Colors.white : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(String workerId) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: CustomButton(
          label: 'Save Availability',
          isLoading: _isSaving,
          onPressed: () => _save(workerId),
        ),
      ),
    );
  }

  Future<void> _save(String workerId) async {
    setState(() => _isSaving = true);
    try {
      final slots = <Map<String, dynamic>>[];
      for (var day = 0; day < 7; day++) {
        for (final period in _periods) {
          slots.add({
            'day_of_week': day,
            'period': period,
            'is_available': _selected.contains(_key(day, period)),
          });
        }
      }
      final workerService = ref.read(workerServiceProvider);
      await workerService.setAvailabilitySlots(workerId, slots);
      ref.invalidate(availabilitySlotsProvider(workerId));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Availability saved successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
