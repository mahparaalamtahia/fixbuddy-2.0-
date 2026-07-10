import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/utils/date_formatter.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../models/chat_model.dart';

class WorkerChatListScreen extends ConsumerWidget {
  const WorkerChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentProfile = ref.watch(currentProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: currentProfile.when(
        data: (profile) => profile == null 
            ? const Center(child: Text('Not logged in', style: TextStyle(color: Colors.white)))
            : _ChatListContent(providerId: profile.id),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
      ),
    );
  }
}

class _ChatListContent extends ConsumerStatefulWidget {
  final String providerId;
  const _ChatListContent({required this.providerId});

  @override
  ConsumerState<_ChatListContent> createState() => _ChatListContentState();
}

class _ChatListContentState extends ConsumerState<_ChatListContent> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatsAsync = ref.watch(workerChatsStreamProvider(widget.providerId));

    return Stack(
      children: [
        // Main content
        Column(
          children: [
            SizedBox(height: MediaQuery.of(context).padding.top),
            // Top App Bar
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.menu, color: Color(0xFF004ac6)),
                        onPressed: () {
                          // Drawer open logic if needed
                          Scaffold.of(context).openDrawer();
                        },
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Messages',
                        style: TextStyle(
                          color: Color(0xFF004ac6),
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.search, color: Color(0xFF004ac6)),
                    onPressed: () {},
                  ),
                ],
              ),
            ),

            // Search & Filter Area
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val.toLowerCase();
                          });
                        },
                        decoration: const InputDecoration(
                          hintText: 'Search conversations...',
                          hintStyle: TextStyle(color: Color(0xFF737686)),
                          prefixIcon: Icon(Icons.search, color: Color(0xFF737686)),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 18),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.tune, color: Color(0xFF737686)),
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),

            // Conversations List
            Expanded(
              child: chatsAsync.when(
                data: (list) {
                  final filteredList = list.where((c) {
                    final nameMatch = (c.userName ?? '').toLowerCase().contains(_searchQuery);
                    final msgMatch = (c.lastMessage ?? '').toLowerCase().contains(_searchQuery);
                    return nameMatch || msgMatch;
                  }).toList();

                  if (filteredList.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 64, color: Color(0xFF737686)),
                          SizedBox(height: 16),
                          Text('No messages found', style: TextStyle(color: Color(0xFF737686))),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.only(left: 20, right: 20, bottom: 120),
                    itemCount: filteredList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      return _ChatTile(chat: filteredList[index]);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
              ),
            ),
          ],
        ),

        // Floating Action Button
        Positioned(
          right: 24,
          bottom: 100,
          child: FloatingActionButton(
            backgroundColor: const Color(0xFFfea619),
            foregroundColor: const Color(0xFF684000),
            elevation: 8,
            onPressed: () {},
            child: const Icon(Icons.add_comment),
          ),
        ),

        // Bottom Navigation Bar
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 72 + MediaQuery.of(context).padding.bottom,
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              boxShadow: [
                BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -2)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(icon: Icons.work, label: 'Jobs', isActive: false, onTap: () => context.go('/worker-shell')),
                _buildNavItem(icon: Icons.chat_bubble, label: 'Activity', isActive: true, onTap: () {}),
                _buildNavItem(icon: Icons.payments, label: 'Earnings', isActive: false, onTap: () => context.go('/worker-shell/earnings')),
                _buildNavItem(icon: Icons.person, label: 'Profile', isActive: false, onTap: () => context.go('/worker-shell/profile')),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavItem({required IconData icon, required String label, required bool isActive, required VoidCallback onTap}) {
    if (isActive) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFfea619),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: const Color(0xFF684000)),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(color: Color(0xFF684000), fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF434655)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Color(0xFF434655), fontSize: 12)),
        ],
      ),
    );
  }
}

class _ChatTile extends ConsumerStatefulWidget {
  final ChatModel chat;
  const _ChatTile({required this.chat});

  @override
  ConsumerState<_ChatTile> createState() => _ChatTileState();
}

class _ChatTileState extends ConsumerState<_ChatTile> {
  bool _isTapped = false;
  bool _hideDotLocally = false;

  @override
  Widget build(BuildContext context) {
    final chat = widget.chat;
    final isTypingAsync = ref.watch(typingStatusProvider(TypingParams(chat.id, chat.userId)));
    final isOtherTyping = isTypingAsync.whenOrNull(data: (v) => v) ?? false;

    // A fake unread logic just for demonstration mapping to HTML if we don't have unread count in DB yet.
    // Ideally use chat.unreadCount or something similar. For now, we will show dot if recent and not locally tapped.
    final hasUnread = !_hideDotLocally;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isTapped = true),
      onTapUp: (_) => setState(() => _isTapped = false),
      onTapCancel: () => setState(() => _isTapped = false),
      onTap: () {
        setState(() => _hideDotLocally = true);
        context.pushNamed('workerChat', pathParameters: {'id': chat.id});
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutQuad,
        transform: Matrix4.diagonal3Values(_isTapped ? 0.98 : 1.0, _isTapped ? 0.98 : 1.0, 1.0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                _buildAvatar(chat),
                if (hasUnread)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563eb),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF1E293B), width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          chat.userName ?? 'Client',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        chat.lastMessageAt != null ? DateFormatter.relativeTime(chat.lastMessageAt!) : '',
                        style: TextStyle(
                          color: hasUnread ? const Color(0xFF2563eb) : const Color(0xFF737686),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: isOtherTyping
                            ? const _TypingIndicator()
                            : Text(
                                chat.lastMessage ?? 'No messages',
                                style: const TextStyle(
                                  color: Color(0xFFc3c6d7),
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2563eb),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(ChatModel chat) {
    if (chat.userAvatar != null) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF2563eb), width: 2),
        ),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: chat.userAvatar!,
            fit: BoxFit.cover,
            errorWidget: (c, u, e) => _buildInitials(chat),
          ),
        ),
      );
    }
    return _buildInitials(chat);
  }

  Widget _buildInitials(ChatModel chat) {
    final name = chat.userName ?? 'Unknown';
    final initials = name.isNotEmpty
        ? name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : '?';

    // Different colors based on initials length
    final bgColor = initials.length > 1 ? const Color(0xFFfea619) : const Color(0xFF007d55);
    final fgColor = initials.length > 1 ? const Color(0xFF684000) : const Color(0xFFbdffdb);

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: fgColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator> with SingleTickerProviderStateMixin {
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
    return Row(
      children: [
        const Text(
          'typing',
          style: TextStyle(color: Color(0xFFc3c6d7), fontSize: 14, fontStyle: FontStyle.italic),
        ),
        const SizedBox(width: 4),
        AnimatedBuilder(
          animation: _controller,
          builder: (_, __) {
            final dots = String.fromCharCodes(
              List.generate(3, (i) {
                final delay = i * 0.2;
                final t = (_controller.value - delay).clamp(0.0, 1.0);
                final visible = (t * 4).ceil().clamp(0, 1);
                return visible == 1 ? 0x2022 : 0x2002;
              }),
            );
            return Text(dots, style: const TextStyle(color: Color(0xFFc3c6d7), fontSize: 14));
          },
        ),
      ],
    );
  }
}
