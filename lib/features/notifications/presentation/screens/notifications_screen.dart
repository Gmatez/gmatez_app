import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../../../../l10n/app_strings.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_layout.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/constants/api_paths.dart';
import '../../../../core/di/core_providers.dart';
import '../../../../core/motion/app_motion.dart';
import '../../../../core/realtime/realtime_service.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../auth/presentation/state/auth_notifier.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  List<Map<String, dynamic>> _items = const [];
  StreamSubscription<RealtimeEvent>? _sub;
  bool _loading = true;
  String? _error;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sub = ref.read(realtimeServiceProvider).events.listen((event) {
        if (event.name == 'notification.received') {
          unawaited(_load(silent: true));
        }
      });
      _load();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    final result = await ref
        .read(apiClientProvider)
        .get(
          ApiPaths.notifications,
          parser: (data) {
            if (data is List) {
              return data.whereType<Map<String, dynamic>>().toList();
            }
            if (data is Map<String, dynamic> && data['items'] is List) {
              return (data['items'] as List)
                  .whereType<Map<String, dynamic>>()
                  .toList();
            }
            return const <Map<String, dynamic>>[];
          },
        );
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
      switch (result) {
        case Success(:final value):
          _items = value;
        case Failure(:final failure):
          _error = failure.userMessage;
      }
    });
  }

  bool _matches(Map<String, dynamic> item) {
    final type = (item['type'] ?? item['category'] ?? '')
        .toString()
        .toUpperCase();
    return switch (_filter) {
      'calls' => type.contains('CALL'),
      'payments' =>
        type.contains('PAY') ||
            type.contains('WALLET') ||
            type.contains('EARN'),
      'system' => type.contains('SYSTEM') || type.contains('HOST'),
      _ => true,
    };
  }

  IconData _icon(Map<String, dynamic> item) {
    final type = (item['type'] ?? '').toString().toUpperCase();
    if (type.contains('CALL')) {
      return Icons.call_rounded;
    }
    if (type.contains('EARN') || type.contains('PAY')) {
      return Icons.payments_rounded;
    }
    if (type.contains('MESSAGE')) {
      return Icons.chat_bubble_rounded;
    }
    return Icons.notifications_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final host = ref.watch(authNotifierProvider).user?.isActiveHost == true;
    final visible = _items.where(_matches).toList();
    final horizontal = AppLayout.pagePadding(context).horizontal / 2;

    return MistScaffold(
      appBar: AppBar(
        title: Text(AppStrings.of(context)('notifications')),
        actions: [
          TextButton(
            onPressed: () async {
              await ref
                  .read(apiClientProvider)
                  .post(ApiPaths.notificationsReadAll, parser: (_) {});
              await _load();
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: SafeArea(
        child: AppLayout.constrain(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  AppSpacing.sm,
                  horizontal,
                  AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    SoftChip(
                      label: 'All',
                      selected: _filter == 'all',
                      onSelected: (_) => setState(() => _filter = 'all'),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    SoftChip(
                      label: 'Calls',
                      selected: _filter == 'calls',
                      onSelected: (_) => setState(() => _filter = 'calls'),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    SoftChip(
                      label: host ? 'Earnings' : 'Payments',
                      selected: _filter == 'payments',
                      onSelected: (_) => setState(() => _filter = 'payments'),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    SoftChip(
                      label: 'System',
                      selected: _filter == 'system',
                      onSelected: (_) => setState(() => _filter = 'system'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: AsyncBody(
                  loading: _loading,
                  error: _error,
                  onRetry: _load,
                  empty: visible.isEmpty,
                  emptyMessage: 'No notifications in this filter.',
                  emptyIcon: Icons.notifications_none_rounded,
                  skeleton: const ScreenSkeleton.list(),
                  child: RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        horizontal,
                        AppSpacing.sm,
                        horizontal,
                        AppSpacing.lg,
                      ),
                      itemCount: visible.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final item = visible[index];
                        final unread = item['readAt'] == null;
                        return FadeInUp(
                          delay: Duration(milliseconds: 40 * (index % 10)),
                          child: AppCard(
                            onTap: () async {
                              final id = item['id'] as String?;
                              if (id != null) {
                                await ref
                                    .read(apiClientProvider)
                                    .post(
                                      ApiPaths.notificationRead(id),
                                      parser: (_) {},
                                    );
                              }
                              if (!context.mounted) {
                                return;
                              }
                              final data = item['data'];
                              final map = data is Map
                                  ? Map<String, dynamic>.from(data)
                                  : const <String, dynamic>{};
                              final type =
                                  '${map['type'] ?? item['type'] ?? ''}'
                                      .toUpperCase();
                              if (type.contains('CALL') &&
                                  map['callId'] is String) {
                                unawaited(
                                  context.push(
                                    AppRoutes.callFor(map['callId'] as String),
                                  ),
                                );
                              } else if (type.contains('CHAT') &&
                                  map['conversationId'] is String) {
                                unawaited(
                                  context.push(
                                    AppRoutes.chatFor(
                                      map['conversationId'] as String,
                                    ),
                                  ),
                                );
                              } else if (type.contains('PAY') ||
                                  type.contains('WALLET')) {
                                unawaited(context.push(AppRoutes.wallet));
                              } else if (type.contains('PAYOUT') ||
                                  type.contains('EARN')) {
                                unawaited(context.push(AppRoutes.earnings));
                              }
                              await _load(silent: true);
                            },
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius:
                                        BorderRadius.circular(AppRadii.sm),
                                  ),
                                  child: Icon(
                                    _icon(item),
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${item['title'] ?? ''}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: unread
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '${item['body'] ?? ''}',
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.textSecondary,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (unread)
                                  const Padding(
                                    padding: EdgeInsets.only(
                                      left: AppSpacing.xs,
                                      top: AppSpacing.xs,
                                    ),
                                    child: Icon(
                                      Icons.circle,
                                      size: 8,
                                      color: AppColors.accent,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

