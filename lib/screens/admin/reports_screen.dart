import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../admin/admin_dashboard_screen.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isExporting = false;

  String get _todayDate {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _exportUsersReport(Map<String, dynamic> data) async {
    setState(() => _isExporting = true);
    try {
      final totalUsers = data['total_users'] ?? 0;
      final totalWorkers = data['total_workers'] ?? 0;
      final totalAccounts = (totalUsers as int) + (totalWorkers as int);

      final csv = [
        'Metric,Value',
        'Total Users,$totalUsers',
        'Total Workers,$totalWorkers',
        'Total Accounts,$totalAccounts',
      ].join('\n');

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/fixbuddy_users_report_$_todayDate.csv');
      await file.writeAsString(csv);

      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: 'Users Report'),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _exportBookingsReport(Map<String, dynamic> data) async {
    setState(() => _isExporting = true);
    try {
      final total = data['total_bookings'] ?? 0;

      int cancelled = 0;
      int pending = 0;
      try {
        final cancelledResult = await _supabase
            .from('bookings')
            .select('id')
            .eq('status', 'cancelled');
        cancelled = (cancelledResult as List).length;

        final pendingResult = await _supabase
            .from('bookings')
            .select('id')
            .eq('status', 'pending');
        pending = (pendingResult as List).length;
      } catch (_) {}

      final completed = data['completed_bookings'] ?? 0;

      final csv = [
        'Metric,Value',
        'Total Bookings,$total',
        'Completed Bookings,$completed',
        'Pending Bookings,$pending',
        'Cancelled Bookings,$cancelled',
      ].join('\n');

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/fixbuddy_bookings_report_$_todayDate.csv');
      await file.writeAsString(csv);

      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: 'Bookings Report'),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _exportEarningsReport() async {
    setState(() => _isExporting = true);
    try {
      final result = await _supabase
          .from('bookings')
          .select('total_amount')
          .eq('status', 'completed');

      final bookings = result as List;
      final completedCount = bookings.length;
      final totalRevenue = bookings.fold<double>(
        0,
        (sum, b) => sum + ((b['total_amount'] as num?)?.toDouble() ?? 0),
      );
      final avgRevenue = completedCount > 0
          ? (totalRevenue / completedCount).toStringAsFixed(2)
          : '0.00';

      final csv = [
        'Metric,Value',
        'Completed Bookings,$completedCount',
        'Total Revenue,${totalRevenue.toStringAsFixed(2)}',
        'Average per Booking,$avgRevenue',
      ].join('\n');

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/fixbuddy_earnings_report_$_todayDate.csv');
      await file.writeAsString(csv);

      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: 'Earnings Report'),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(adminStatsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: stats.when(
        data: (data) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Platform Summary',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _ReportCard(title: 'Users Breakdown', children: [
              _ReportRow(
                  label: 'Total Users', value: '${data['total_users'] ?? 0}'),
              _ReportRow(
                  label: 'Total Workers',
                  value: '${data['total_workers'] ?? 0}'),
              _ReportRow(
                  label: 'Total Accounts',
                  value:
                      '${(data['total_users'] ?? 0) + (data['total_workers'] ?? 0)}'),
            ]),
            const SizedBox(height: 12),
            _ReportCard(title: 'Booking Statistics', children: [
              _ReportRow(
                  label: 'Total Bookings',
                  value: '${data['total_bookings'] ?? 0}'),
              _ReportRow(
                  label: "Today's Bookings",
                  value: '${data['bookings_today'] ?? 0}'),
              _ReportRow(
                  label: 'Completed Bookings',
                  value: '${data['completed_bookings'] ?? 0}'),
              _ReportRow(
                  label: 'Pending Approvals',
                  value: '${data['pending_approvals'] ?? 0}'),
            ]),
            const SizedBox(height: 12),
            _ReportCard(title: 'Platform Health', children: [
              _ReportRow(
                  label: 'Active Categories',
                  value: '${data['active_categories'] ?? 0}'),
              _ReportRow(
                  label: 'Active Areas', value: '${data['active_areas'] ?? 0}'),
            ]),
            const SizedBox(height: 24),
            const Text('Export',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildExportDropdown(data),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildExportDropdown(Map<String, dynamic> data) {
    return PopupMenuButton<String>(
      onSelected: (value) async {
        switch (value) {
          case 'users':
            await _exportUsersReport(data);
            break;
          case 'bookings':
            await _exportBookingsReport(data);
            break;
          case 'earnings':
            await _exportEarningsReport();
            break;
        }
      },
      onOpened: () => setState(() {}),
      offset: const Offset(0, -120),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'users',
          child: ListTile(
            leading: Icon(Icons.people),
            title: Text('Export Users Report'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'bookings',
          child: ListTile(
            leading: Icon(Icons.book),
            title: Text('Export Bookings Report'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'earnings',
          child: ListTile(
            leading: Icon(Icons.attach_money),
            title: Text('Export Earnings Report'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () {},
          icon: _isExporting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download),
          label: Text(_isExporting ? 'Exporting...' : 'Export Report'),
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _ReportCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  final String label;
  final String value;
  const _ReportRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}
