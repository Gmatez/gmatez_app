import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/motion/app_motion.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../app/theme/app_colors.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GradientBackdrop(
      child: SafeArea(
        child: Center(
          child: FadeInUp(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PulseGlow(
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withValues(alpha: 0.4),
                            blurRadius: 32,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/brand/gmatez_logo.png',
                        width: 72,
                        height: 72,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Gmatez',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.2,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Talk. Listen. Connect.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Voice & video calls with verified listeners',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 40),
                  const SizedBox(
                    width: 120,
                    child: ClipRRect(
                      borderRadius: BorderRadius.all(Radius.circular(99)),
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        backgroundColor: Color(0x33FFFFFF),
                        color: Colors.white,
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
