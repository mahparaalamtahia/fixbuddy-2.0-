import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/worker_provider.dart';
import '../../providers/booking_provider.dart';

class WorkerEarningsScreen extends ConsumerWidget {
  const WorkerEarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentWorker = ref.watch(currentWorkerProvider);

    return currentWorker.when(
      data: (worker) => worker == null
          ? const Scaffold(body: Center(child: Text('Worker not found')))
          : _EarningsContent(workerId: worker.id),
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}

class _EarningsContent extends ConsumerWidget {
  final String workerId;
  const _EarningsContent({required this.workerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(workerBookingsProvider(workerId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Earnings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/worker-shell'),
        ),
      ),
      body: bookings.when(
        data: (list) {
          final completed = list.where((b) => b.status == 'completed').toList();
          final totalEarned =
              completed.fold<double>(0, (sum, b) => sum + (b.totalAmount ?? 0));

          final now = DateTime.now();
          final thisMonthCompleted = completed
              .where((b) =>
                  b.createdAt != null &&
                  b.createdAt!.month == now.month &&
                  b.createdAt!.year == now.year)
              .toList();
          final thisMonthEarned = thisMonthCompleted.fold<double>(
              0, (sum, b) => sum + (b.totalAmount ?? 0));

          final Map<String, List> monthlyGroups = {};
          for (final b in completed) {
            if (b.createdAt != null) {
              final key = DateFormat('yyyy-MM').format(b.createdAt!);
              monthlyGroups.putIfAbsent(key, () => []);
              monthlyGroups[key]!.add(b);
            }
          }
          final sortedMonths = monthlyGroups.keys.toList()..sort();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const Text('Total Earnings',
                          style: TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      Text('৳${totalEarned.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: AppColors.success)),
                      const SizedBox(height: 8),
                      Text('${completed.length} jobs completed',
                          style:
                              const TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.calendar_today,
                            color: AppColors.primary, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('This Month',
                              style: TextStyle(color: AppColors.textSecondary)),
                          const SizedBox(height: 4),
                          Text('৳${thisMonthEarned.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontSize: 24, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (sortedMonths.isNotEmpty) ...[
                const Text('Monthly Breakdown',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...sortedMonths.reversed.map((key) {
                  final monthBookings = monthlyGroups[key]!;
                  final monthTotal = monthBookings.fold<double>(
                      0, (s, b) => s + (b.totalAmount ?? 0));
                  final dateParts = key.split('-');
                  final monthNum = int.parse(dateParts[1]);
                  final yearNum = int.parse(dateParts[0]);
                  final monthName = DateFormat('MMMM yyyy')
                      .format(DateTime(yearNum, monthNum));

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(monthName,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600)),
                            Text('৳${monthTotal.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.success)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...monthBookings.map((b) => Card(
                              margin: const EdgeInsets.only(bottom: 6),
                              child: ListTile(
                                dense: true,
                                leading: const Icon(Icons.check_circle,
                                    color: AppColors.success),
                                title: Text(
                                  DateFormat('MMM dd, yyyy')
                                      .format(b.scheduledDate),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500),
                                ),
                                subtitle: const Row(
                                  children: [
                                    Icon(Icons.money,
                                        size: 14,
                                        color: AppColors.textSecondary),
                                    SizedBox(width: 4),
                                    Text('Cash',
                                        style: TextStyle(
                                            color: AppColors.textSecondary)),
                                  ],
                                ),
                                trailing: Text(
                                    '৳${b.totalAmount?.toStringAsFixed(0) ?? '0'}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                              ),
                            )),
                      ],
                    ),
                  );
                }),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
