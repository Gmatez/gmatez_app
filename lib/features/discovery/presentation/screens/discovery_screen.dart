import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../l10n/app_strings.dart';
import '../../../../core/constants/speaking_languages.dart';
import '../../../../app/theme/app_layout.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/motion/app_motion.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../state/discovery_notifier.dart';
import '../state/discovery_state.dart';
import '../widgets/discovery_user_tile.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key, this.callType});

  final String? callType;

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final notifier = ref.read(discoveryNotifierProvider.notifier);
      final callType = widget.callType;
      if (callType != null && callType.isNotEmpty) {
        await notifier.setCallType(callType);
        return;
      }
      await notifier.loadInitial();
    });
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 240) {
      ref.read(discoveryNotifierProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(discoveryNotifierProvider);
    final notifier = ref.read(discoveryNotifierProvider.notifier);
    final horizontal = AppLayout.pagePadding(context).horizontal;

    return MistScaffold(
      body: SafeArea(
        child: AppLayout.constrain(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHeader(
                title: AppStrings.of(context)('discover'),
                subtitle: AppStrings.of(context)('discoverSubtitle'),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  horizontal / 2,
                  AppSpacing.xs,
                  horizontal / 2,
                  AppSpacing.sm,
                ),
                child: AppTextField(
                  controller: _search,
                  label: AppStrings.of(context)('searchPeople'),
                  textInputAction: TextInputAction.search,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: state.query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _search.clear();
                            notifier.setQuery('');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  onChanged: notifier.setQuery,
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontal / 2),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      SoftChip(
                        label: AppStrings.of(context)('online'),
                        selected: state.onlineOnly,
                        onSelected: notifier.setOnlineOnly,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      SoftChip(
                        label: 'All languages',
                        selected: state.language == null || state.language!.isEmpty,
                        onSelected: (_) => notifier.setLanguage(null),
                      ),
                      for (final entry in speakingLanguages.entries) ...[
                        const SizedBox(width: AppSpacing.xs),
                        SoftChip(
                          label: entry.value,
                          selected: state.language == entry.key,
                          onSelected: (selected) {
                            notifier.setLanguage(selected ? entry.key : null);
                          },
                        ),
                      ],
                      const SizedBox(width: AppSpacing.xs),
                      SoftChip(
                        label: AppStrings.of(context)('voice'),
                        selected: state.callType == 'VOICE',
                        onSelected: (selected) {
                          notifier.setCallType(selected ? 'VOICE' : null);
                        },
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      SoftChip(
                        label: AppStrings.of(context)('video'),
                        selected: state.callType == 'VIDEO',
                        onSelected: (selected) {
                          notifier.setCallType(selected ? 'VIDEO' : null);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(child: _body(state, notifier, horizontal / 2)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(
    DiscoveryState state,
    DiscoveryNotifier notifier,
    double horizontalPadding,
  ) {
    if (state.status == DiscoveryStatus.loading && state.users.isEmpty) {
      return DiscoverySkeleton(padding: horizontalPadding);
    }
    if (state.status == DiscoveryStatus.error && state.users.isEmpty) {
      return AsyncBody(
        loading: false,
        error: state.failure?.userMessage,
        onRetry: notifier.loadInitial,
        child: const SizedBox.shrink(),
      );
    }
    if (state.status == DiscoveryStatus.empty) {
      return AsyncBody(
        loading: false,
        empty: true,
        emptyMessage: state.query.trim().length >= 2
            ? 'No hosts match that search.'
            : 'No hosts to discover yet.',
        emptyIcon: Icons.explore_outlined,
        child: const SizedBox.shrink(),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: notifier.refresh,
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          AppSpacing.sm,
          horizontalPadding,
          AppSpacing.lg,
        ),
        itemCount: state.users.length + (state.loadingMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          if (index >= state.users.length) {
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: ShimmerBox(height: 72),
            );
          }
          final user = state.users[index];
          return FadeInUp(
            delay: Duration(milliseconds: 40 * (index % 8)),
            child: DiscoveryUserTile(
              user: user,
              onTap: () => context.push(AppRoutes.profileFor(user.userId)),
            ),
          );
        },
      ),
    );
  }
}

