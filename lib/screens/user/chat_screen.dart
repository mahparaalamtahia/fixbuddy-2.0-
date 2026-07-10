import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/router/app_router.dart';
import '../../core/utils/date_formatter.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/booking_provider.dart';
import '../../services/chat_service.dart';
import '../../models/message_model.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _chatServiceProvider = Provider<ChatService>((ref) => ChatService());

class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  const ChatScreen({super.key, required this.chatId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  String? _otherUserId;
  bool _isSendingTyping = false;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = ref.read(currentUserProvider);
      if (user != null) {
        ref.read(_chatServiceProvider).markAsRead(widget.chatId, user.id);
        _resolveOtherUser(user.id);
      }
    });
  }

  @override
  void dispose() {
    _clearTyping();
    _typingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _resolveOtherUser(String userId) {
    ref.read(chatByIdProvider(widget.chatId).future).then((chat) {
      if (!mounted) return;
      setState(() {
        if (chat.seekerId == userId || chat.userId == userId) {
          _otherUserId = chat.providerId ?? chat.workerId;
        } else {
          _otherUserId = chat.seekerId ?? chat.userId;
        }
      });
    });
  }

  void _emitTyping(bool isTyping) {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null || _isSendingTyping) return;
    _isSendingTyping = true;
    ref
        .read(_chatServiceProvider)
        .updateTypingStatus(widget.chatId, userId, isTyping)
        .then((_) => _isSendingTyping = false);
  }

  void _clearTyping() {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId != null) {
      ref
          .read(_chatServiceProvider)
          .updateTypingStatus(widget.chatId, userId, false);
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(currentUserProvider);
    if (user == null || _otherUserId == null) return;

    ref.read(_chatServiceProvider).sendMessage(
          chatId: widget.chatId,
          senderId: user.id,
          receiverId: _otherUserId!,
          text: text,
        );
    _messageController.clear();
    analyticsService.trackEvent(AnalyticsService.chatMessageSent,
        parameters: {'chat_id': widget.chatId});
    _typingTimer?.cancel();
    _emitTyping(false);
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesStreamProvider(widget.chatId));
    final userId = ref.watch(currentUserProvider)?.id;
    final chatAsync = ref.watch(chatByIdProvider(widget.chatId));

    ref.listen(chatMessagesStreamProvider(widget.chatId), (prev, next) {
      next.whenData((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) return;
          if (_scrollController.hasClients &&
              _scrollController.position.pixels > 100) {
            _scrollController.animateTo(
              0.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
            );
          }
        });
      });
    });

    final otherName = chatAsync.whenOrNull(
          data: (c) => c.userId == userId ? (c.workerName ?? 'Worker') : (c.userName ?? 'User'),
        ) ??
        'Chat';

    final otherAvatarUrl = chatAsync.whenOrNull(
      data: (c) => c.userId == userId ? c.workerAvatar : c.userAvatar,
    );

    final canSend = _messageController.text.trim().isNotEmpty;
    final otherTyping = _otherUserId != null
        ? ref.watch(
            typingStatusProvider(TypingParams(widget.chatId, _otherUserId!)))
        : const AsyncLoading<bool>();

    final isOtherTyping = otherTyping.whenOrNull(data: (v) => v) ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(72),
        child: Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            right: 8,
            bottom: 8,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.divider)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/shell');
                      }
                    },
                  ),
                  const SizedBox(width: 4),
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.divider,
                        backgroundImage: otherAvatarUrl != null
                            ? CachedNetworkImageProvider(otherAvatarUrl)
                            : null,
                        child: otherAvatarUrl == null
                            ? const Icon(Icons.person, color: AppColors.textSecondary)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.surface, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(otherName,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary)),
                      const Text('Online',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.success,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.location_on, color: AppColors.primary),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          chatAsync.when(
            data: (c) {
              if (c.bookingId == null) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: AppColors.primary.withValues(alpha: 0.05),
                  child: const Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Pre-booking Chat',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                );
              }
              final bAsync = ref.watch(bookingByIdProvider(c.bookingId!));
              return bAsync.when(
                data: (b) => Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: AppColors.primary.withValues(alpha: 0.05),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Booking ${b.status.replaceAll('_', ' ')}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.primary),
                            ),
                            if (b.categoryName != null)
                              Text(
                                b.categoryName!,
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.primary),
                              ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          final user = ref.read(currentUserProvider);
                          if (user != null) {
                            if (b.workerId == user.id || user.role == 'worker') {
                              context.push('/worker-shell/bookings/${b.id}');
                            } else {
                              context.push('/shell/bookings/${b.id}');
                            }
                          }
                        },
                        child: const Text('View Booking'),
                      ),
                    ],
                  ),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: messages.when(
                    data: (list) => list.isEmpty
                        ? const Center(
                            child: Text('No messages yet. Start a conversation!', style: TextStyle(color: AppColors.textSecondary)))
                        : ListView.builder(
                            controller: _scrollController,
                            reverse: true,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                            itemCount: list.length,
                            itemBuilder: (_, i) {
                              final msg = list[i];
                              final isMe = msg.senderId == userId;
                              final avatarUrl = chatAsync.whenOrNull(
                                  data: (c) => msg.senderId == c.userId
                                      ? c.userAvatar
                                      : c.workerAvatar);
                              return _MessageBubble(
                                  message: msg, isMe: isMe, avatarUrl: avatarUrl);
                            },
                          ),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                  ),
                ),
                if (isOtherTyping)
                  Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 56, bottom: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const _TypingDots(),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$otherName is typing...',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          
          // Bottom Dock
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: MediaQuery.of(context).padding.bottom + 12,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4))
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.1),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.call, color: AppColors.primary),
                    onPressed: () async {
                      if (_otherUserId == null) return;
                      final profileData = await Supabase.instance.client
                          .from('profiles')
                          .select('phone')
                          .eq('id', _otherUserId!)
                          .maybeSingle();
                      final phone = profileData?['phone'] as String?;
                      if (phone == null || phone.isEmpty) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No phone number available')));
                        }
                        return;
                      }
                      final cleanPhone = phone.replaceAll(RegExp(r'[\s\-]'), '');
                      final Uri telUrl = Uri.parse('tel:$cleanPhone');
                      if (await canLaunchUrl(telUrl)) {
                        await launchUrl(telUrl);
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch phone dialer')));
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: const InputDecoration(
                              hintText: 'Type message here...',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) {
                              _sendMessage();
                              _emitTyping(false);
                            },
                            onChanged: (_) {
                              setState(() {});
                              _typingTimer?.cancel();
                              _emitTyping(true);
                              _typingTimer = Timer(const Duration(seconds: 2), () {
                                _emitTyping(false);
                              });
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.attach_file, color: AppColors.textSecondary),
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: canSend ? AppColors.primary : AppColors.divider,
                    boxShadow: canSend ? [
                      BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2))
                    ] : null,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: canSend ? _sendMessage : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.2;
            final t = (_controller.value - delay).clamp(0.0, 1.0);
            double bounce = 0.0;
            if (t > 0 && t < 0.5) {
              bounce = t * 2;
            } else if (t >= 0.5 && t < 1.0) {
              bounce = (1 - t) * 2;
            }
            return Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              transform: Matrix4.translationValues(0, -bounce * 4, 0),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final String? avatarUrl;
  const _MessageBubble({required this.message, required this.isMe, this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.divider,
              backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl!) : null,
              child: avatarUrl == null ? const Icon(Icons.person, size: 16, color: AppColors.textSecondary) : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75),
                  decoration: BoxDecoration(
                    color: isMe ? AppColors.primary : AppColors.primary.withValues(alpha: 0.05),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(0),
                      bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
                    ),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: isMe ? Colors.white : AppColors.textPrimary,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.createdAt != null
                          ? DateFormatter.relativeTime(message.createdAt!)
                          : '',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.done_all, size: 14, color: AppColors.primary),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
