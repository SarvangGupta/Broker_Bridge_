import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../data/chat_gateway.dart';
import '../domain/chat_models.dart';
import 'chat_screen.dart';

/// The caller's conversations, newest first, with real unread counts.
class ChatInboxScreen extends StatefulWidget {
  final ChatGateway? gateway;
  final String emptyText;

  const ChatInboxScreen({
    super.key,
    this.gateway,
    this.emptyText = 'No conversations yet.',
  });

  @override
  State<ChatInboxScreen> createState() => _ChatInboxScreenState();
}

class _ChatInboxScreenState extends State<ChatInboxScreen> {
  late final ChatGateway _gateway = widget.gateway ?? SupabaseChatGateway();
  List<ChatConversationSummary> _rows = [];
  bool _loading = true;
  String? _error;
  bool _opening = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _gateway.inbox();
      if (!mounted) return;
      setState(() {
        // Defensive dedupe; the backend guarantees one row per pair.
        final seen = <String>{};
        _rows = [
          for (final r in rows)
            if (seen.add(r.id)) r,
        ];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load conversations. Check your connection.';
        _loading = false;
      });
    }
  }

  Future<void> _open(ChatConversationSummary r) async {
    if (_opening) return;
    _opening = true;
    await context.push('/chats/${r.id}');
    _opening = false;
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: const Text('Messages'),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          tooltip: 'Back',
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.rotateCw),
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: RefreshIndicator(onRefresh: _load, child: _body()),
    );
  }

  Widget _body() {
    Widget fill(Widget child) => ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [SizedBox(height: 360, child: Center(child: child))],
    );
    if (_loading) return fill(const CircularProgressIndicator());
    if (_error != null) {
      return fill(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              style: const TextStyle(color: AppColors.textSecondaryLight),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Try Again')),
          ],
        ),
      );
    }
    if (_rows.isEmpty) {
      return fill(
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            widget.emptyText,
            key: const Key('chat-inbox-empty'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondaryLight),
          ),
        ),
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _rows.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, indent: 76, color: AppColors.borderLight),
      itemBuilder: (context, i) {
        final r = _rows[i];
        final unread = r.unreadCount > 0;
        return InkWell(
          key: Key('chat-row-${r.id}'),
          onTap: () => _open(r),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                chatAvatar(r.counterpartName),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              r.counterpartName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: unread
                                    ? FontWeight.w800
                                    : FontWeight.w700,
                                color: AppColors.textPrimaryLight,
                              ),
                            ),
                          ),
                          if (r.lastMessageAt != null)
                            Text(
                              _when(r.lastMessageAt!.toLocal()),
                              style: TextStyle(
                                fontSize: 11,
                                color: unread
                                    ? AppColors.primary
                                    : AppColors.textMutedLight,
                              ),
                            ),
                        ],
                      ),
                      if (r.counterpartCompany != null)
                        Text(
                          r.counterpartCompany!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondaryLight,
                          ),
                        ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              r.lastMessagePreview ?? 'No messages yet',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: unread
                                    ? AppColors.textPrimaryLight
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                          ),
                          if (unread)
                            Container(
                              key: Key('chat-unread-${r.id}'),
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                r.unreadCount > 99 ? '99+' : '${r.unreadCount}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _when(DateTime t) {
    final now = DateTime.now();
    if (t.year == now.year && t.month == now.month && t.day == now.day) {
      return DateFormat('h:mm a').format(t);
    }
    return DateFormat('d MMM').format(t);
  }
}
