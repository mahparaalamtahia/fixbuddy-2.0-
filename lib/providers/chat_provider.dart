import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/chat_service.dart';
import '../models/message_model.dart';
import '../models/chat_model.dart';
import 'auth_provider.dart';

final chatServiceProvider = Provider<ChatService>((ref) => ChatService());

final chatByIdProvider = FutureProvider.family<ChatModel, String>((ref, chatId) async {
  final chatService = ref.watch(chatServiceProvider);
  return await chatService.getChatById(chatId);
});

final chatMessagesProvider =
    FutureProvider.family<List<MessageModel>, String>((ref, chatId) async {
  final chatService = ref.watch(chatServiceProvider);
  return await chatService.getMessages(chatId);
});

final chatMessagesStreamProvider =
    StreamProvider.autoDispose.family<List<MessageModel>, String>((ref, chatId) {
  final chatService = ref.watch(chatServiceProvider);
  final controller = StreamController<List<MessageModel>>();
  
  final subscription = chatService.streamMessages(chatId).listen((data) {
    if (!controller.isClosed) controller.add(data);
  }, onError: (e) {
    if (!controller.isClosed) controller.addError(e);
  });

  ref.onDispose(() {
    subscription.cancel();
    controller.close();
  });

  return controller.stream;
});

final userChatsProvider = FutureProvider<List<ChatModel>>((ref) async {
  final user = ref.watch(currentUserProvider);
  final chatService = ref.watch(chatServiceProvider);
  if (user == null) return [];
  return await chatService.getUserChats(user.id);
});

final workerChatsProvider =
    FutureProvider.family<List<ChatModel>, String>((ref, workerId) async {
  final chatService = ref.watch(chatServiceProvider);
  return await chatService.getWorkerChats(workerId);
});

final userChatsStreamProvider = StreamProvider.autoDispose<List<ChatModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  final chatService = ref.watch(chatServiceProvider);
  if (user == null) return Stream.value([]);
  
  final controller = StreamController<List<ChatModel>>();
  final subscription = chatService.streamUserChats(user.id).listen((data) {
    if (!controller.isClosed) controller.add(data);
  }, onError: (e) {
    if (!controller.isClosed) controller.addError(e);
  });

  ref.onDispose(() {
    subscription.cancel();
    controller.close();
  });

  return controller.stream;
});

final workerChatsStreamProvider =
    StreamProvider.autoDispose.family<List<ChatModel>, String>((ref, workerId) {
  final chatService = ref.watch(chatServiceProvider);
  
  final controller = StreamController<List<ChatModel>>();
  final subscription = chatService.streamWorkerChats(workerId).listen((data) {
    if (!controller.isClosed) controller.add(data);
  }, onError: (e) {
    if (!controller.isClosed) controller.addError(e);
  });

  ref.onDispose(() {
    subscription.cancel();
    controller.close();
  });

  return controller.stream;
});

class TypingParams {
  final String chatId;
  final String otherUserId;
  TypingParams(this.chatId, this.otherUserId);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TypingParams &&
          chatId == other.chatId &&
          otherUserId == other.otherUserId;

  @override
  int get hashCode => chatId.hashCode ^ otherUserId.hashCode;
}

final typingStatusProvider =
    StreamProvider.autoDispose.family<bool, TypingParams>((ref, params) {
  final chatService = ref.watch(chatServiceProvider);
  
  final controller = StreamController<bool>();
  final subscription = chatService.streamTypingStatus(params.chatId, params.otherUserId).listen((data) {
    if (!controller.isClosed) controller.add(data);
  }, onError: (e) {
    if (!controller.isClosed) controller.addError(e);
  });

  ref.onDispose(() {
    subscription.cancel();
    controller.close();
  });

  return controller.stream;
});
