import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_layout.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/motion/app_motion.dart';
import '../../../../core/widgets/app_widgets.dart';

class HostApplyScreen extends StatelessWidget {
  const HostApplyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackdrop(
        child: SafeArea(
          child: AppLayout.constrain(
            context,
            child: Padding(
              padding: AppLayout.pagePadding(context).copyWith(
                top: 4,
                bottom: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.onDeep,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 12),
                          FadeInUp(
                            child: Center(
                              child: PulseGlow(
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        AppColors.accent.withValues(alpha: 0.9),
                                        AppColors.primary.withValues(
                                          alpha: 0.2,
                                        ),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.accent.withValues(
                                          alpha: 0.4,
                                        ),
                                        blurRadius: 40,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.mic_none_rounded,
                                    size: 56,
                                    color: AppColors.onDeep,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          FadeInUp(
                            delay: const Duration(milliseconds: 80),
                            child: Text(
                              'Become a Listener',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.onDeep,
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          FadeInUp(
                            delay: const Duration(milliseconds: 140),
                            child: Text(
                              'Earn on your schedule with secure voice and video calls.',
                              style: GoogleFonts.plusJakartaSans(
                                color: AppColors.onDeep.withValues(alpha: 0.85),
                                fontSize: 16,
                                height: 1.45,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          FadeInUp(
                            delay: const Duration(milliseconds: 200),
                            child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _Benefit(
                                  icon: Icons.call_rounded,
                                  label: 'Receive audio & video calls',
                                ),
                                _Benefit(
                                  icon: Icons.payments_outlined,
                                  label: 'Earn rewards for your time',
                                ),
                                _Benefit(
                                  icon: Icons.verified_user_outlined,
                                  label: 'Safe & verified community',
                                ),
                                _Benefit(
                                  icon: Icons.schedule_rounded,
                                  label: 'Flexible schedule',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxl),
                        ],
                      ),
                    ),
                  ),
                  FadeInUp(
                    delay: const Duration(milliseconds: 260),
                    child: AppButton(
                      label: 'Start Application',
                      onPressed: () =>
                          context.push(AppRoutes.hostOnboarding),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: Text(
                      'Maybe later',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppColors.onDeep.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.onDeep, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              softWrap: true,
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.onDeep,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
