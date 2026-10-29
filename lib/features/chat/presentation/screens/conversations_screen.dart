import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../l10n/app_strings.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_layout.dart';
import '../../../../core/di/core_providers.dart';
import '../../../../core/motion/app_motion.dart';
import '../../../../core/pagination/cursor_page.dart';
import '../../../../core/realtime/realtime_service.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/widgets/enterprise_widgets.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../data/chat_repository.dart';
import '../../domain/entities/chat_models.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(apiClientProvider));
});

class ConversationsScreen extends ConsumerStatefulWidget {
  const ConversationsScreen({super.key});

  @override
  ConsumerState<ConversationsScreen> createState() =>
      _ConversationsScreenState();
}

class _ConversationsScreenState extends ConsumerState<ConversationsScreen> {
  CursorPage<ConversationSummary>? _page;
  StreamSubscription<RealtimeEvent>? _sub;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sub = ref.read(realtimeServiceProvider).events.listen((event) {
        if (event.name == 'message.created' || event.name == 'message.read') {
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
    final result = await ref.read(chatRepositoryProvider).list();
    if (!mounted) {
      return;
    }
    setState(() {
      _loading = false;
      switch (result) {
        case Success(:final value):
          _page = value;
        case Failure(:final failure):
          if (!silent) {
            _error = failure.userMessage;
          }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = _page?.items ?? const <ConversationSummary>[];
    final isEmpty = !_loading && _error == null && items.isEmpty;
    final pad = AppLayout.pagePadding(context);

    return MistScaffold(
      body: SafeArea(
        child: AppLayout.constrain(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHeader(
                title: AppStrings.of(context)('messages'),
                subtitle: 'Secure conversations with listeners',
                action: IconButton(
                  tooltip: 'Find people',
                  onPressed: () => context.go(AppRoutes.discover),
                  icon: const Icon(Icons.person_search_outlined),
                ),
              ),
              Expanded(
                child: _loading
                    ? const ScreenSkeleton.list()
                    : _error != null
                    ? EmptyState(
                        icon: Icons.wifi_off_rounded,
                        title: 'Couldn’t load messages',
                        message: _error!,
                        actionLabel: 'Try again',
                        onAction: _load,
                      )
                    : isEmpty
                    ? Padding(
                        padding: EdgeInsets.fromLTRB(
                          pad.left,
                          8,
                          pad.right,
                          20,
                        ),
                        child: EnterpriseEmptyState(
                          icon: Icons.forum_outlined,
                          title: 'No conversations yet',
                          message:
                              'Browse Discover and tap Message to open a secure chat thread.',
                          actionLabel: 'Go to Discover',
                          onAction: () => context.go(AppRoutes.discover),
                        ),
                      )
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            pad.left,
                            4,
                            pad.right,
                            24,
                          ),
                          itemCount: items.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return FadeInUp(
                              delay: Duration(milliseconds: 35 * (index % 10)),
                              child: EnterpriseListTile(
                              leading: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  UserAvatar(
                                    name: item.peerDisplayName,
                                    size: 44,
                                  ),
                                  if (item.peerOnline)
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: AppColors.success,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: AppColors.surfaceElevated,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              title: item.peerDisplayName,
                              subtitle: item.lastMessagePreview.isEmpty
                                  ? 'No messages yet'
                                  : item.lastMessagePreview,
                              trailing: item.unreadCount > 0
                                  ? Container(
                                      constraints: const BoxConstraints(
                                        minWidth: 22,
                                      ),
                                      height: 22,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                      ),
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary,
                                        borderRadius: BorderRadius.circular(
                                          99,
                                        ),
                                      ),
                                      child: Text(
                                        '${item.unreadCount}',
                                        style: GoogleFonts.figtree(
                                          color: AppColors.onPrimary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.chevron_right_rounded,
                                      color: AppColors.textMuted,
                                    ),
                              onTap: () =>
                                  context.push(AppRoutes.chatFor(item.id)),
                              ),
                            );
                          },
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
