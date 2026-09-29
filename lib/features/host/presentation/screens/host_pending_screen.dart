import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_layout.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/motion/app_motion.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../auth/presentation/state/auth_notifier.dart';

class HostPendingScreen extends ConsumerWidget {
  const HostPendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final host = ref.watch(authNotifierProvider).user?.host;
    final rejected = host?.status == 'REJECTED';
    final suspended = host?.status == 'SUSPENDED';
    final pending = host?.status == 'PENDING_REVIEW' || host == null;
    final title = suspended
        ? 'Host account suspended'
        : rejected
        ? 'Your application was not approved'
        : 'Application Submitted';
    final body = host?.reviewNote?.isNotEmpty == true
        ? host!.reviewNote!
        : suspended
        ? 'Hosting is paused on this account. You can still use Gmatez as a caller.'
        : rejected
        ? 'You can update your profile and apply again.'
        : 'Your application is under review. We’ll notify you once the verification process is complete.';

    return MistScaffold(
      appBar: AppBar(title: const Text('Host Application')),
      body: AppLayout.constrain(
        context,
        child: ListView(
        padding: AppLayout.pagePadding(context).copyWith(
          top: AppSpacing.lg,
          bottom: AppSpacing.xl,
        ),
        children: [
          FadeInUp(
            child: AppCard(
              child: Column(
                children: [
                  Icon(
                    suspended
                        ? Icons.pause_circle_outline
                        : rejected
                        ? Icons.cancel_outlined
                        : Icons.mark_email_read_outlined,
                    color: suspended || rejected
                        ? AppColors.danger
                        : AppColors.primary,
                    size: 42,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    body,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FadeInUp(
            delay: const Duration(milliseconds: 80),
            child: AppCard(
              child: Column(
                children: [
                  _StepRow('Personal Information', complete: true),
                  _StepRow('Languages & Interests', complete: true),
                  _StepRow(
                    'Verification',
                    complete: !pending || host != null,
                    inProgress: pending,
                  ),
                  _StepRow('Agreement', complete: true),
                  _StepRow(
                    'Review & Submit',
                    complete: true,
                    last: rejected || suspended,
                  ),
                  _StepRow(
                    suspended
                        ? 'Suspended'
                        : rejected
                        ? 'Rejected'
                        : 'Under Review',
                    complete: false,
                    inProgress: pending,
                    last: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Back to Profile',
            onPressed: () => context.go(AppRoutes.myProfile),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Continue as caller',
            variant: AppButtonVariant.ghost,
            onPressed: () => context.go(AppRoutes.discover),
          ),
          if (rejected) ...[
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Apply again',
              onPressed: () => context.push(AppRoutes.hostApply),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Refresh status',
            variant: AppButtonVariant.secondary,
            onPressed: () async {
              await ref.read(authNotifierProvider.notifier).refreshUser();
              final next = ref.read(authNotifierProvider).user;
              if (!context.mounted) {
                return;
              }
              if (next?.isActiveHost == true) {
                context.go(AppRoutes.home);
              }
            },
          ),
        ],
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow(
    this.label, {
    this.complete = false,
    this.inProgress = false,
    this.last = false,
  });

  final String label;
  final bool complete;
  final bool inProgress;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 12),
      child: Row(
        children: [
          Icon(
            complete
                ? Icons.check_circle
                : inProgress
                ? Icons.timelapse
                : Icons.radio_button_unchecked,
            color: complete
                ? AppColors.success
                : inProgress
                ? AppColors.primary
                : AppColors.textSecondary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: complete || inProgress
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
