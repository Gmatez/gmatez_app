import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/motion/app_motion.dart';

class AuthHero extends StatelessWidget {
  const AuthHero({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final heroHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : (MediaQuery.sizeOf(context).height * 0.46).clamp(240.0, 420.0);
        return SizedBox(
          height: heroHeight,
          width: double.infinity,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 20,
            top: heroHeight * 0.12,
            child: const FadeInUp(
              delay: Duration(milliseconds: 80),
              child: _SoftIcon(Icons.videocam_rounded),
            ),
          ),
          Positioned(
            right: 24,
            top: heroHeight * 0.18,
            child: const FadeInUp(
              delay: Duration(milliseconds: 140),
              child: _SoftIcon(Icons.call_rounded),
            ),
          ),
          Positioned(
            right: 40,
            bottom: 48,
            child: const FadeInUp(
              delay: Duration(milliseconds: 200),
              child: _SoftIcon(Icons.favorite_rounded, size: 36),
            ),
          ),
          const FadeInUp(child: _PhoneCard()),
        ],
      ),
        );
      },
    );
  }
}

class _SoftIcon extends StatelessWidget {
  const _SoftIcon(this.icon, {this.size = 44});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.42),
    );
  }
}

class _PhoneCard extends StatelessWidget {
  const _PhoneCard();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.07,
      child: Container(
        width: (MediaQuery.sizeOf(context).width * 0.42).clamp(150.0, 210.0),
        height: (MediaQuery.sizeOf(context).height * 0.32).clamp(210.0, 280.0),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: AppColors.mist,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.primarySoft, AppColors.primaryDim],
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  width: 28,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.person, color: Colors.white, size: 16),
                ),
              ),
              const Spacer(),
              const CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.background,
                child: Icon(Icons.person, color: AppColors.primary, size: 22),
              ),
              const SizedBox(height: 10),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _CallDot(icon: Icons.mic_rounded),
                  SizedBox(width: 6),
                  _CallDot(
                    icon: Icons.call_end_rounded,
                    color: Color(0xFFEF4444),
                  ),
                  SizedBox(width: 6),
                  _CallDot(icon: Icons.videocam_rounded),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallDot extends StatelessWidget {
  const _CallDot({required this.icon, this.color = AppColors.backgroundDeep});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 10,
      backgroundColor: color,
      child: Icon(icon, size: 11, color: Colors.white),
    );
  }
}
