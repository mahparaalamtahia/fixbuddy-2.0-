import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/booking_service.dart';
import '../models/booking_model.dart';
import 'auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final bookingServiceProvider =
    Provider<BookingService>((ref) => BookingService());

final userBookingsProvider = FutureProvider<List<BookingModel>>((ref) async {
  final user = ref.watch(currentUserProvider);
  final bookingService = ref.watch(bookingServiceProvider);
  if (user == null) return [];
  return await bookingService.getUserBookings(user.id);
});

final workerBookingsProvider =
    FutureProvider.family<List<BookingModel>, String>((ref, workerId) async {
  final sub = Supabase.instance.client.channel('worker_bookings_$workerId').onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'bookings',
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

  final bookingService = ref.watch(bookingServiceProvider);
  return await bookingService.getWorkerBookings(workerId);
});

final bookingByIdProvider =
    FutureProvider.family<BookingModel, String>((ref, bookingId) async {
  final sub = Supabase.instance.client.channel('booking_$bookingId').onPostgresChanges(
    event: PostgresChangeEvent.all,
    schema: 'public',
    table: 'bookings',
    filter: PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'id',
      value: bookingId,
    ),
    callback: (payload) {
      ref.invalidateSelf();
    },
  ).subscribe();

  ref.onDispose(() {
    sub.unsubscribe();
  });

  final bookingService = ref.watch(bookingServiceProvider);
  return await bookingService.getBookingById(bookingId);
});

final userBookingsStreamProvider = StreamProvider<List<BookingModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  final bookingService = ref.watch(bookingServiceProvider);
  if (user == null) return Stream.value([]);
  return bookingService.streamUserBookings(user.id);
});

final workerBookingsStreamProvider =
    StreamProvider.family<List<BookingModel>, String>((ref, workerId) {
  final bookingService = ref.watch(bookingServiceProvider);
  return bookingService.streamWorkerBookings(workerId);
});
