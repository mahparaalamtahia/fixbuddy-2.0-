import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';

class ChatService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<ChatModel>> getUserChats(String userId) async {
    final data = await _supabase
        .from('chats')
        .select(
            '*, profiles!chats_user_id_fkey(full_name, avatar_url), workers!chats_worker_id_fkey(profiles:profile_id(full_name, avatar_url))')
        .eq('user_id', userId)
        .order('last_message_at', ascending: false);
    return (data as List).map((e) => ChatModel.fromJson(e)).toList();
  }

  Future<String> getOrCreateChat({
    required String userId,
    required String workerId,
    String? bookingId,
  }) async {
    if (bookingId != null) {
      // Check if chat exists for this booking
      final existing = await _supabase
          .from('chats')
          .select('id')
          .eq('booking_id', bookingId)
          .limit(1)
          .maybeSingle();

      if (existing != null) {
        return existing['id'] as String;
      }
    } else {
      // Check if a direct chat (no booking) exists
      final existing = await _supabase
          .from('chats')
          .select('id')
          .eq('user_id', userId)
          .eq('worker_id', workerId)
          .isFilter('booking_id', null)
          .limit(1)
          .maybeSingle();

      if (existing != null) {
        return existing['id'] as String;
      }
    }

    // Create new chat
    final newChat = await _supabase.from('chats').insert({
      'user_id': userId,
      'worker_id': workerId,
      if (bookingId != null) 'booking_id': bookingId,
    }).select('id').single();

    return newChat['id'] as String;
  }

  Future<ChatModel> getChatById(String chatId) async {
    final data = await _supabase
        .from('chats')
        .select(
            '*, profiles!chats_user_id_fkey(full_name, avatar_url), workers!chats_worker_id_fkey(profiles:profile_id(full_name, avatar_url))')
        .eq('id', chatId)
        .single();
    return ChatModel.fromJson(data);
  }

  Future<List<ChatModel>> getWorkerChats(String workerId) async {
    final data = await _supabase
        .from('chats')
        .select(
            '*, profiles!chats_user_id_fkey(full_name, avatar_url), workers!chats_worker_id_fkey(profiles:profile_id(full_name, avatar_url))')
        .eq('worker_id', workerId)
        .order('last_message_at', ascending: false);
    return (data as List).map((e) => ChatModel.fromJson(e)).toList();
  }

  Future<List<MessageModel>> getMessages(String chatId) async {
    final data = await _supabase
        .from('messages')
        .select('*')
        .eq('chat_id', chatId)
        .order('created_at', ascending: false);
    return (data as List).map((e) => MessageModel.fromJson(e)).toList();
  }

  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String text,
  }) async {
    await _supabase.from('messages').insert({
      'chat_id': chatId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'text': text,
    });
  }

  Stream<List<MessageModel>> streamMessages(String chatId) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', chatId)
        .order('created_at', ascending: false)
        .map((data) => data.map((e) => MessageModel.fromJson(e)).toList());
  }

  Future<void> markAsRead(String chatId, String userId) async {
    await _supabase
        .from('messages')
        .update({'is_read': true})
        .eq('chat_id', chatId)
        .neq('sender_id', userId)
        .eq('is_read', false);
  }

  Stream<List<ChatModel>> streamUserChats(String userId) {
    final controller = StreamController<List<ChatModel>>();

    void fetchAndAdd() async {
      try {
        final data = await _supabase
            .from('chats')
            .select(
                '*, profiles!chats_user_id_fkey(full_name, avatar_url), workers!chats_worker_id_fkey(profiles:profile_id(full_name, avatar_url))')
            .eq('user_id', userId)
            .order('last_message_at', ascending: false);
        if (!controller.isClosed) {
          controller
              .add((data as List).map((e) => ChatModel.fromJson(e)).toList());
        }
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    fetchAndAdd();

    final sub = _supabase
        .from('chats')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .listen((_) => fetchAndAdd(), onError: (e) {
          if (!controller.isClosed) controller.addError(e);
        });

    controller.onCancel = () {
      sub.cancel();
      controller.close();
    };

    return controller.stream;
  }

  Stream<List<ChatModel>> streamWorkerChats(String providerId) {
    final controller = StreamController<List<ChatModel>>();

    void fetchAndAdd() async {
      try {
        final data = await _supabase
            .from('chats')
            .select(
                '*, profiles!chats_user_id_fkey(full_name, avatar_url), workers!chats_worker_id_fkey(profiles:profile_id(full_name, avatar_url))')
            .eq('provider_id', providerId)
            .order('last_message_at', ascending: false);
        if (!controller.isClosed) {
          controller
              .add((data as List).map((e) => ChatModel.fromJson(e)).toList());
        }
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    }

    fetchAndAdd();

    final sub = _supabase
        .from('chats')
        .stream(primaryKey: ['id'])
        .eq('provider_id', providerId)
        .listen((_) => fetchAndAdd(), onError: (e) {
          if (!controller.isClosed) controller.addError(e);
        });

    controller.onCancel = () {
      sub.cancel();
      controller.close();
    };

    return controller.stream;
  }

  Future<void> updateTypingStatus(
      String chatId, String userId, bool isTyping) async {
    await _supabase.from('typing_status').upsert({
      'chat_id': chatId,
      'user_id': userId,
      'is_typing': isTyping,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'chat_id, user_id');
  }

  Stream<bool> streamTypingStatus(String chatId, String otherUserId) {
    final controller = StreamController<bool>();

    void checkStatus() async {
      try {
        final data = await _supabase
            .from('typing_status')
            .select()
            .eq('chat_id', chatId)
            .eq('user_id', otherUserId)
            .maybeSingle();
        if (data == null) {
          if (!controller.isClosed) controller.add(false);
          return;
        }
        final isTyping = data['is_typing'] as bool? ?? false;
        if (!isTyping) {
          if (!controller.isClosed) controller.add(false);
          return;
        }
        final updatedAt = data['updated_at'] as String?;
        if (updatedAt == null) {
          if (!controller.isClosed) controller.add(false);
          return;
        }
        final updated = DateTime.parse(updatedAt);
        final stillTyping =
            DateTime.now().toUtc().difference(updated).inSeconds < 5;
        if (!controller.isClosed) controller.add(stillTyping);
      } catch (_) {
        if (!controller.isClosed) controller.add(false);
      }
    }

    checkStatus();

    final channel = _supabase
        .channel('typing-$chatId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'typing_status',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: chatId,
          ),
          callback: (_) => checkStatus(),
        )
        .subscribe();

    final timer = Timer.periodic(const Duration(seconds: 3), (_) {
      checkStatus();
    });

    controller.onCancel = () {
      timer.cancel();
      _supabase.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }
}
