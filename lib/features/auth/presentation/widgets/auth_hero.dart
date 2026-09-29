import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/motion/app_motion.dart';

class AuthHero extends StatelessWidget {
  const AuthHero({super.key});

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final heroHeight = (height * 0.30).clamp(200.0, 260.0);

    return SizedBox(
      height: heroHeight,
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
          Positioned(
            left: 20,
            bottom: 16,
            child: FadeInUp(
              delay: const Duration(milliseconds: 120),
              child: Text(
                'Gmatez',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
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
        width: 120,
        height: 168,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: const Color(0xFFEEE9FF),
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
              colors: [Color(0xFF8B6CFF), Color(0xFF5536E0)],
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
                backgroundColor: Color(0xFFF4F1FF),
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
  const _CallDot({required this.icon, this.color = const Color(0xFF2A1570)});

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
