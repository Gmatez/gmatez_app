import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/di/core_providers.dart';
import '../../../../core/realtime/realtime_service.dart';
import '../../../../core/utils/debouncer.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../auth/presentation/state/auth_notifier.dart';
import '../../domain/entities/chat_models.dart';
import 'conversations_screen.dart';

class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <ChatMessage>[];
  final _typingDebounce = Debouncer(delay: const Duration(milliseconds: 400));
  StreamSubscription<RealtimeEvent>? _sub;
  StreamSubscription<RealtimeConnectionState>? _connSub;
  bool _loading = true;
  bool _loadingOlder = false;
  bool _sending = false;
  bool _peerTyping = false;
  bool _hasMore = true;
  String? _nextCursor;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final realtime = ref.read(realtimeServiceProvider);
      _sub = realtime.events.listen(_onRealtime);
      _connSub = realtime.connection.listen((state) {
        if (state == RealtimeConnectionState.connected) {
          unawaited(_reconcileAfterReconnect());
        }
      });
      realtime.emit('conversation.subscribe', {
        'conversationId': widget.conversationId,
      });
      _load();
    });
  }

  @override
  void dispose() {
    ref.read(realtimeServiceProvider).emit('conversation.unsubscribe', {
      'conversationId': widget.conversationId,
    });
    _sub?.cancel();
    _connSub?.cancel();
    _typingDebounce.dispose();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients || _loadingOlder || !_hasMore) {
      return;
    }
    if (_scroll.position.pixels <= 80) {
      unawaited(_loadOlder());
    }
  }

  Future<void> _reconcileAfterReconnect() async {
    ref.read(realtimeServiceProvider).emit('conversation.subscribe', {
      'conversationId': widget.conversationId,
    });
    final result = await ref
        .read(chatRepositoryProvider)
        .messages(widget.conversationId);
    if (!mounted) {
      return;
    }
    if (result case Success(:final value)) {
      setState(() {
        for (final message in value.items) {
          _upsert(message);
        }
        _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      });
      unawaited(
        ref.read(chatRepositoryProvider).markRead(widget.conversationId),
      );
    }
  }

  void _onRealtime(RealtimeEvent event) {
    if (event.name == 'message.created') {
      final message = ChatMessage.fromJson(event.payload);
      if (message.conversationId != widget.conversationId) {
        return;
      }
      setState(() {
        _peerTyping = false;
        _upsert(message);
      });
      unawaited(
        ref.read(chatRepositoryProvider).markRead(widget.conversationId),
      );
      return;
    }
    if (event.name == 'message.read') {
      final conversationId = event.payload['conversationId'] as String?;
      if (conversationId != widget.conversationId) {
        return;
      }
      final me = ref.read(authNotifierProvider).user?.id;
      setState(() {
        for (var i = 0; i < _messages.length; i++) {
          final message = _messages[i];
          if (message.senderId == me && message.readAt == null) {
            _messages[i] = message.copyWith(
              readAt: DateTime.now(),
              status: 'READ',
            );
          }
        }
      });
      return;
    }
    if (event.name == 'message.typing') {
      final conversationId = event.payload['conversationId'] as String?;
      final userId = event.payload['userId'] as String?;
      final me = ref.read(authNotifierProvider).user?.id;
      if (conversationId != widget.conversationId || userId == me) {
        return;
      }
      setState(() => _peerTyping = event.payload['typing'] != false);
    }
  }

  void _upsert(ChatMessage message) {
    final index = _messages.indexWhere(
      (row) =>
          row.id == message.id ||
          (message.idempotencyKey != null &&
              row.idempotencyKey == message.idempotencyKey) ||
          (row.localStatus == 'sending' &&
              row.body == message.body &&
              row.senderId == message.senderId),
    );
    if (index >= 0) {
      _messages[index] = message.copyWith(
        localStatus: 'sent',
        idempotencyKey: message.idempotencyKey ?? _messages[index].idempotencyKey,
      );
    } else {
      _messages.add(message);
    }
  }

  Future<void> _load() async {
    final repo = ref.read(chatRepositoryProvider);
    final result = await repo.messages(widget.conversationId);
    await repo.markRead(widget.conversationId);
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
      switch (result) {
        case Success(:final value):
          _messages
            ..clear()
            ..addAll(value.items);
          _nextCursor = value.nextCursor;
          _hasMore = value.nextCursor != null;
        case Failure(:final failure):
          _error = failure.userMessage;
      }
    });
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder || !_hasMore || _nextCursor == null) {
      return;
    }
    setState(() => _loadingOlder = true);
    final previousMax = _scroll.hasClients ? _scroll.position.maxScrollExtent : 0;
    final result = await ref
        .read(chatRepositoryProvider)
        .messages(widget.conversationId, cursor: _nextCursor);
    if (!mounted) {
      return;
    }
    setState(() {
      _loadingOlder = false;
      if (result case Success(:final value)) {
        final existing = _messages.map((m) => m.id).toSet();
        final older = value.items.where((m) => !existing.contains(m.id));
        _messages.insertAll(0, older);
        _nextCursor = value.nextCursor;
        _hasMore = value.nextCursor != null;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) {
        return;
      }
      final delta = _scroll.position.maxScrollExtent - previousMax;
      if (delta > 0) {
        _scroll.jumpTo(_scroll.position.pixels + delta);
      }
    });
  }

  Future<void> _send({ChatMessage? retry}) async {
    final text = retry?.body ?? _controller.text.trim();
    if (text.isEmpty || _sending) {
      return;
    }
    final key = retry?.idempotencyKey ?? const Uuid().v4();
    final me = ref.read(authNotifierProvider).user?.id ?? '';
    final pending =
        retry?.copyWith(localStatus: 'sending') ??
        ChatMessage(
          id: 'local-$key',
          conversationId: widget.conversationId,
          senderId: me,
          body: text,
          createdAt: DateTime.now(),
          localStatus: 'sending',
          idempotencyKey: key,
        );
    setState(() {
      _sending = true;
      if (retry == null) {
        _messages.add(pending);
        _controller.clear();
      } else {
        _upsert(pending);
      }
    });
    ref.read(realtimeServiceProvider).emit('message.typing', {
      'conversationId': widget.conversationId,
      'typing': false,
    });
    final result = await ref
        .read(chatRepositoryProvider)
        .send(
          conversationId: widget.conversationId,
          body: text,
          idempotencyKey: key,
        );
    if (!mounted) {
      return;
    }
    setState(() => _sending = false);
    if (result case Success(:final value)) {
      setState(() => _upsert(value.copyWith(idempotencyKey: key)));
    } else if (result case Failure(:final failure)) {
      setState(() {
        _upsert(pending.copyWith(localStatus: 'failed', idempotencyKey: key));
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.userMessage)));
    }
  }

  void _onChanged(String value) {
    ref.read(realtimeServiceProvider).emit('message.typing', {
      'conversationId': widget.conversationId,
      'typing': true,
    });
    _typingDebounce.run(() {
      ref.read(realtimeServiceProvider).emit('message.typing', {
        'conversationId': widget.conversationId,
        'typing': false,
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final myId = ref.watch(authNotifierProvider).user?.id;
    return MistScaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: AsyncBody(
        loading: _loading,
        error: _error,
        onRetry: _load,
        skeleton: const ScreenSkeleton.chat(),
        child: Column(
          children: [
            if (_loadingOlder)
              const LinearProgressIndicator(
                minHeight: 2,
                color: AppColors.primary,
                backgroundColor: AppColors.surfaceMuted,
              ),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  final mine = message.senderId == myId;
                  return Align(
                    alignment: mine
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.sizeOf(context).width * 0.78,
                      ),
                      child: GestureDetector(
                        onTap: message.localStatus == 'failed'
                            ? () => _send(retry: message)
                            : null,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: mine
                                ? AppColors.primary
                                : AppColors.surfaceElevated,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(AppRadii.md),
                              topRight: const Radius.circular(AppRadii.md),
                              bottomLeft: Radius.circular(
                                mine ? AppRadii.md : AppRadii.xs,
                              ),
                              bottomRight: Radius.circular(
                                mine ? AppRadii.xs : AppRadii.md,
                              ),
                            ),
                            border: mine
                                ? null
                                : Border.all(color: AppColors.border),
                            boxShadow: mine
                                ? const [
                                    BoxShadow(
                                      color: AppColors.softShadow,
                                      blurRadius: 12,
                                      offset: Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                message.body,
                                style: TextStyle(
                                  color: mine
                                      ? AppColors.onPrimary
                                      : AppColors.textPrimary,
                                  height: 1.35,
                                ),
                              ),
                              if (message.localStatus == 'sending')
                                Text(
                                  'Sending…',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: mine
                                        ? AppColors.onPrimary.withValues(
                                            alpha: 0.75,
                                          )
                                        : AppColors.textMuted,
                                  ),
                                ),
                              if (message.localStatus == 'failed')
                                Text(
                                  'Failed · tap to retry',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: mine
                                        ? AppColors.accent
                                        : AppColors.danger,
                                  ),
                                ),
                              if (mine &&
                                  message.localStatus == 'sent' &&
                                  (message.status == 'READ' ||
                                      message.readAt != null))
                                Text(
                                  'Read',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.onPrimary.withValues(
                                      alpha: 0.75,
                                    ),
                                  ),
                                )
                              else if (mine && message.localStatus == 'sent')
                                Text(
                                  'Sent',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.onPrimary.withValues(
                                      alpha: 0.75,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_peerTyping)
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.md,
                  bottom: AppSpacing.xs,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Typing…',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            AppCard(
              bordered: false,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _controller,
                      label: 'Message',
                      maxLines: 4,
                      onChanged: _onChanged,
                    ),
                  ),
                  IconButton(
                    onPressed: _sending ? null : () => _send(),
                    color: AppColors.primary,
                    icon: _sending
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
            SizedBox(height: MediaQuery.paddingOf(context).bottom),
          ],
        ),
      ),
    );
  }
}
