import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/booking_model.dart';

class BookingService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<BookingModel> createBooking(Map<String, dynamic> data) async {
    final result = await _supabase.from('bookings').insert(data).select('''
          *,
          workers!inner(profiles(full_name, avatar_url, phone)),
          categories(name, icon_name),
          areas(name)
        ''').single();
    return BookingModel.fromJson(result);
  }

  Future<List<BookingModel>> getUserBookings(String userId) async {
    final data = await _supabase.from('bookings').select('''
          *,
          workers!inner(profiles(full_name, avatar_url, phone)),
          categories(name, icon_name),
          areas(name)
        ''').eq('user_id', userId).order('created_at', ascending: false);
    return (data as List).map((e) => BookingModel.fromJson(e)).toList();
  }

  Future<List<BookingModel>> getWorkerBookings(String workerId) async {
    final data = await _supabase.from('bookings').select('''
          *,
          workers!inner(profiles(full_name, avatar_url, phone)),
          categories(name, icon_name),
          areas(name),
          profiles!bookings_user_id_fkey(full_name, avatar_url, phone)
        ''').eq('worker_id', workerId).order('created_at', ascending: false);
    return (data as List).map((e) => BookingModel.fromJson(e)).toList();
  }

  Future<BookingModel> getBookingById(String bookingId) async {
    final data = await _supabase.from('bookings').select('''
          *,
          workers!inner(profiles(full_name, avatar_url, phone)),
          categories(name, icon_name),
          areas(name)
        ''').eq('id', bookingId).single();
    return BookingModel.fromJson(data);
  }

  Future<void> updateBookingStatus(String bookingId, String status,
      {String? declineReason}) async {
    final updates = <String, dynamic>{'status': status};
    if (declineReason != null && status == 'declined') {
      updates['decline_reason'] = declineReason;
    }
    await _supabase.from('bookings').update(updates).eq('id', bookingId);
  }

  Future<void> cancelBooking(String bookingId) async {
    await _supabase
        .from('bookings')
        .update({'status': 'cancelled'})
        .eq('id', bookingId)
        .filter('status', 'in', '("pending","confirmed")');
  }

  Stream<List<BookingModel>> streamUserBookings(String userId) {
    return _supabase
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((data) => data.map((e) => BookingModel.fromJson(e)).toList());
  }

  Stream<List<BookingModel>> streamWorkerBookings(String workerId) {
    return _supabase
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('worker_id', workerId)
        .order('created_at', ascending: false)
        .map((data) => data.map((e) => BookingModel.fromJson(e)).toList());
  }
}
