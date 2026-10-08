import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_layout.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/constants/api_paths.dart';
import '../../../../core/di/core_providers.dart';
import '../../../../core/motion/app_motion.dart';
import '../../../../core/utils/result.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../calls/presentation/state/active_call_notifier.dart';
import '../../domain/entities/user_profile.dart';
import '../state/profile_notifier.dart';
import '../widgets/profile_header.dart';

class PublicProfileScreen extends ConsumerWidget {
  const PublicProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(publicProfileProvider(userId));

    return MistScaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.discover);
            }
          },
        ),
      ),
      body: async.when(
        loading: () => const ScreenSkeleton.profile(),
        error: (_, _) => AsyncBody(
          loading: false,
          error: 'Something went wrong. Please try again.',
          onRetry: () => ref.invalidate(publicProfileProvider(userId)),
          child: const SizedBox.shrink(),
        ),
        data: (result) {
          return switch (result) {
            Failure<UserProfile>(:final failure) => AsyncBody(
              loading: false,
              error: failure.userMessage,
              onRetry: () => ref.invalidate(publicProfileProvider(userId)),
              child: const SizedBox.shrink(),
            ),
            Success<UserProfile>(:final value) => SafeArea(
              child: AppLayout.constrain(
                context,
                child: ListView(
                  padding: AppLayout.pagePadding(context).copyWith(
                    top: AppSpacing.sm,
                    bottom: AppSpacing.xl,
                  ),
                  children: [
                    FadeInUp(
                      child: ProfileHeader(profile: value),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    FadeInUp(
                      delay: AppDurations.fast,
                      child: ProfileDetails(profile: value),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    StaggeredList(
                      children: [
                        AppButton(
                          label: 'Voice call',
                          icon: Icons.call_rounded,
                          onPressed: value.availableForCall && value.voiceEnabled
                              ? () => _startCall(context, ref, 'VOICE')
                              : () => _unavailable(context),
                        ),
                        AppButton(
                          label: 'Video call',
                          icon: Icons.videocam_rounded,
                          onPressed: value.availableForCall && value.videoEnabled
                              ? () => _startCall(context, ref, 'VIDEO')
                              : () => _unavailable(context),
                        ),
                        AppButton(
                          label: 'Block',
                          variant: AppButtonVariant.ghost,
                          onPressed: () => _block(context, ref),
                        ),
                        AppButton(
                          label: 'Report',
                          variant: AppButtonVariant.danger,
                          onPressed: () => _report(context, ref),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          };
        },
      ),
    );
  }

  void _unavailable(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This host is currently unavailable.')),
    );
  }

  Future<void> _startCall(
    BuildContext context,
    WidgetRef ref,
    String callType,
  ) async {
    final result = await ref
        .read(activeCallProvider.notifier)
        .startCall(calleeId: userId, callType: callType);
    if (!context.mounted) {
      return;
    }
    switch (result) {
      case Success(:final value):
        await context.push(AppRoutes.callFor(value.id));
      case Failure(:final failure):
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.userMessage)));
    }
  }

  Future<void> _block(BuildContext context, WidgetRef ref) async {
    final result = await ref
        .read(apiClientProvider)
        .post(ApiPaths.blocks, body: {'userId': userId}, parser: (_) {});
    if (!context.mounted) {
      return;
    }
    final message = switch (result) {
      Failure(:final failure) => failure.userMessage,
      Success() => 'User blocked',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _report(BuildContext context, WidgetRef ref) async {
    const reasons = <String, String>{
      'SPAM': 'Spam',
      'HARASSMENT': 'Harassment',
      'INAPPROPRIATE_CONTENT': 'Inappropriate content',
      'FRAUD': 'Scam / fraud',
      'OTHER': 'Other',
    };
    final reason = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(title: Text('Report user')),
              ...reasons.entries.map(
                (entry) => ListTile(
                  title: Text(entry.value),
                  onTap: () => Navigator.pop(context, entry.key),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (reason == null || !context.mounted) {
      return;
    }
    final result = await ref
        .read(apiClientProvider)
        .post(
          ApiPaths.reports,
          body: {
            'userId': userId,
            'reason': reason,
            'details': 'Reported from profile',
          },
          parser: (_) {},
        );
    if (!context.mounted) {
      return;
    }
    final message = switch (result) {
      Failure(:final failure) => failure.userMessage,
      Success() => 'Report submitted',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

