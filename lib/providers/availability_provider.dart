import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/availability_slot_model.dart';
import 'worker_provider.dart';

final availabilitySlotsProvider =
    FutureProvider.family<List<AvailabilitySlot>, String>(
        (ref, workerId) async {
  final sub = Supabase.instance.client.channel('slots_$workerId').onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'worker_availability_slots',
    filter: PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'worker_id',
      value: workerId,
    ),
    callback: (payload) {
      ref.invalidateSelf();
    },
  ).subscribe();

  ref.onDispose(() {
    sub.unsubscribe();
  });

  final workerService = ref.watch(workerServiceProvider);
  return await workerService.getAvailabilitySlots(workerId);
});
