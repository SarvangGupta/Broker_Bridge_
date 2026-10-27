import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/theme/app_colors.dart';
import '../data/chat_gateway.dart';
import '../domain/chat_models.dart';
import 'chat_controller.dart';

/// One Buyer <-> Broker conversation. Shows "Start a conversation" until the
/// first message exists. No presence, typing or call features: the backend
/// has none, so none are shown.
class ChatScreen extends StatefulWidget {
  final String? conversationId;
  final String? brokerId;

  /// Header identity before the conversation summary loads (e.g. the broker
  /// record the buyer tapped). Replaced by the server's view once available.
  final String? fallbackName;
  final String? fallbackCompany;

  /// Context line in the empty state, e.g. what buyers can discuss.
  final String emptyHint;
  final ChatGateway? gateway;

  const ChatScreen({
    super.key,
    this.conversationId,
    this.brokerId,
    this.fallbackName,
    this.fallbackCompany,
    this.emptyHint = 'Discuss requirements, pricing, lot matching or dispatch. Seller identities stay protected.',
    this.gateway,
  }) : assert(conversationId != null || brokerId != null);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  late final ChatController _c;
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _c = ChatController(
      gateway: widget.gateway ?? SupabaseChatGateway(),
      conversationId: widget.conversationId,
      brokerId: widget.brokerId,
    )..addListener(_changed);
    _c.init();
    _scroll.addListener(() {
      // Reversed list: maxScrollExtent is the oldest end.
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 120) {
        _c.loadOlder();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _c.refresh();
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _c
      ..removeListener(_changed)
      ..dispose();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    if (_c.send(_input.text)) {
      _input.clear();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _c.summary;
    final name = s?.counterpartName ?? widget.fallbackName ?? 'Conversation';
    final company = s?.counterpartCompany ?? widget.fallbackCompany;
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          tooltip: 'Back',
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: Row(
          children: [
            _Avatar(name: name, size: 38),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                  if (company != null)
                    Text(
                      company,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_c.conversationId != null &&
                _c.connection == ChatConnection.reconnecting)
              Container(
                key: const Key('chat-reconnecting'),
                width: double.infinity,
                color: AppColors.warningBackground,
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: const Text(
                  'Reconnecting… new messages may be delayed.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.warning),
                ),
              ),
            Expanded(child: _body()),
            if (!_c.loading && _c.error == null) _composer(),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_c.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_c.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                LucideIcons.cloudOff,
                size: 40,
                color: AppColors.textMutedLight,
              ),
              const SizedBox(height: 12),
              Text(
                _c.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondaryLight),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _c.init,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }
    if (_c.messages.isEmpty) {
      return Center(
        key: const Key('chat-empty'),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppColors.successBackground,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.messagesSquare,
                  size: 32,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Start a conversation',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.emptyHint,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final msgs = _c.messages.reversed.toList();
    final seenId = _c.seenMessageId;
    return ListView.builder(
      key: const Key('chat-list'),
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      itemCount: msgs.length + (_c.loadingOlder ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == msgs.length) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        final m = msgs[i];
        final older = i + 1 < msgs.length ? msgs[i + 1] : null;
        final local = m.createdAt.toLocal();
        final showDay =
            older == null || !_sameDay(older.createdAt.toLocal(), local);
        return Column(
          children: [
            if (showDay) _DayChip(day: local),
            _Bubble(
              message: m,
              mine: m.senderId == _c.me,
              seen: m.id != null && m.id == seenId,
              onRetry: () => _c.retry(m),
            ),
          ],
        );
      },
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _composer() {
    final canSend = _input.text.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: const BoxDecoration(
        color: AppColors.surfaceLight,
        border: Border(top: BorderSide(color: AppColors.borderLight)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              key: const Key('chat-input'),
              controller: _input,
              minLines: 1,
              maxLines: 5,
              maxLength: kChatMaxLength,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Type a message…',
                counterText: '',
                filled: true,
                fillColor: AppColors.backgroundLight,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: 'Send message',
            child: Material(
              key: const Key('chat-send'),
              color: canSend ? AppColors.primary : AppColors.borderLight,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: canSend ? _send : null,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(
                    LucideIcons.sendHorizontal,
                    size: 20,
                    color: canSend ? Colors.white : AppColors.textMutedLight,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  final DateTime day;
  const _DayChip({required this.day});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(day.year, day.month, day.day);
    final label = d == today
        ? 'Today'
        : d == today.subtract(const Duration(days: 1))
        ? 'Yesterday'
        : DateFormat('d MMM yyyy').format(day);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondaryLight,
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool mine;
  final bool seen;
  final VoidCallback onRetry;

  const _Bubble({
    required this.message,
    required this.mine,
    required this.seen,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final failed = message.delivery == ChatDelivery.failed;
    final pending = message.delivery == ChatDelivery.pending;
    final status = failed
        ? 'Not sent'
        : pending
        ? 'Sending…'
        : DateFormat('h:mm a').format(message.createdAt.toLocal()) +
              (seen ? ' · Seen' : '');

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.76,
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      decoration: BoxDecoration(
        color: mine
            ? (failed ? AppColors.errorBackground : AppColors.primary)
            : AppColors.surfaceLight,
        border: mine ? null : Border.all(color: AppColors.borderLight),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(mine ? 16 : 4),
          bottomRight: Radius.circular(mine ? 4 : 16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Plain text only; never parsed as markup.
          SelectableText(
            message.body,
            style: TextStyle(
              fontSize: 14,
              height: 1.35,
              color: mine && !failed
                  ? Colors.white
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (pending)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(
                    LucideIcons.clock,
                    size: 11,
                    color: Colors.white70,
                  ),
                ),
              if (failed)
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(
                    LucideIcons.circleAlert,
                    size: 12,
                    color: AppColors.error,
                  ),
                ),
              Text(
                status,
                style: TextStyle(
                  fontSize: 10.5,
                  color: failed
                      ? AppColors.error
                      : mine
                      ? Colors.white70
                      : AppColors.textMutedLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Column(
          crossAxisAlignment: mine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            bubble,
            if (failed)
              TextButton.icon(
                key: Key('chat-retry-${message.clientMessageId}'),
                onPressed: onRetry,
                icon: const Icon(LucideIcons.rotateCw, size: 14),
                label: const Text('Retry'),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
              ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final double size;
  const _Avatar({required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    final t = name.trim();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Text(
        t.isEmpty ? '?' : t[0].toUpperCase(),
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

/// Avatar shared with the inbox.
Widget chatAvatar(String name, {double size = 48}) =>
    _Avatar(name: name, size: size);
