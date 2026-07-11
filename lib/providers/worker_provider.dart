import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/worker_service.dart';
import '../models/worker_model.dart';
import '../models/worker_document_model.dart';
import 'auth_provider.dart';

final workerServiceProvider = Provider<WorkerService>((ref) => WorkerService());

final availableWorkersProvider =
    FutureProvider.family<List<WorkerModel>, WorkerSearchFilters>(
        (ref, filters) async {
  final workerService = ref.watch(workerServiceProvider);
  return await workerService.getAvailableWorkers(
    categoryId: filters.categoryId,
    areaId: filters.areaId,
    searchQuery: filters.searchQuery,
    sortBy: filters.sortBy,
    page: filters.page,
    limit: filters.limit,
  );
});

final featuredWorkersProvider = FutureProvider<List<WorkerModel>>((ref) async {
  final workerService = ref.watch(workerServiceProvider);
  return await workerService.getFeaturedWorkers(limit: 100);
});

final workerByIdProvider =
    FutureProvider.family<WorkerModel?, String>((ref, workerId) async {
  final workerService = ref.watch(workerServiceProvider);
  return await workerService.getWorkerById(workerId);
});

/// Real-time stream of the current authenticated worker's row.
/// Uses Supabase `.stream()` keyed on the worker's `profile_id` so the
/// dashboard header, stats, and availability toggle are always live.
/// A blocking loading indicator is shown until the first snapshot arrives.
final currentWorkerProvider = StreamProvider<WorkerModel?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(null);

  return Supabase.instance.client
      .from('workers')
      .stream(primaryKey: ['id'])
      .eq('profile_id', user.id)
      .asyncMap((rows) async {
        if (rows.isEmpty) return null;
        // The stream only gives us the workers row.  Fetch the full
        // joined profile so we have name, avatar, categories, areas etc.
        final workerService = WorkerService();
        return await workerService.getCurrentWorker(user.id);
      });
});

final workerStatsProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, workerId) async {
  final workerService = ref.watch(workerServiceProvider);
  return await workerService.getWorkerStats(workerId);
});

final workerDocumentsProvider =
    StreamProvider.family<List<WorkerDocumentModel>, String>((ref, workerId) {
  final workerService = ref.watch(workerServiceProvider);
  return workerService.watchWorkerDocuments(workerId);
});

class WorkerSearchFilters {
  final String? categoryId;
  final String? areaId;
  final String? searchQuery;
  final String sortBy;
  final int page;
  final int limit;

  WorkerSearchFilters({
    this.categoryId,
    this.areaId,
    this.searchQuery,
    this.sortBy = 'top_rated',
    this.page = 0,
    this.limit = 10,
  });

  WorkerSearchFilters copyWith({
    String? categoryId,
    String? areaId,
    String? searchQuery,
    String? sortBy,
    int? page,
    int? limit,
  }) {
    return WorkerSearchFilters(
      categoryId: categoryId ?? this.categoryId,
      areaId: areaId ?? this.areaId,
      searchQuery: searchQuery ?? this.searchQuery,
      sortBy: sortBy ?? this.sortBy,
      page: page ?? this.page,
      limit: limit ?? this.limit,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkerSearchFilters &&
          runtimeType == other.runtimeType &&
          categoryId == other.categoryId &&
          areaId == other.areaId &&
          searchQuery == other.searchQuery &&
          sortBy == other.sortBy &&
          page == other.page &&
          limit == other.limit;

  @override
  int get hashCode =>
      categoryId.hashCode ^
      areaId.hashCode ^
      searchQuery.hashCode ^
      sortBy.hashCode ^
      page.hashCode ^
      limit.hashCode;
}
