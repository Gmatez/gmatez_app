import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../features/auth/presentation/state/auth_notifier.dart';
import '../router/app_routes.dart';
import '../theme/app_colors.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isHost = ref.watch(authNotifierProvider).user?.isActiveHost == true;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated.withValues(alpha: 0.96),
          border: const Border(top: BorderSide(color: AppColors.border)),
          boxShadow: const [
            BoxShadow(
              color: AppColors.cardShadow,
              blurRadius: 18,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          height: 68 + (bottomInset > 0 ? 4 : 0),
          onDestinationSelected: (index) {
            navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
            );
          },
          destinations: [
            NavigationDestination(
              icon: Icon(
                isHost ? Icons.dashboard_outlined : Icons.home_outlined,
              ),
              selectedIcon: Icon(
                isHost ? Icons.dashboard_rounded : Icons.home_rounded,
              ),
              label: isHost ? 'Studio' : 'Home',
            ),
            const NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore_rounded),
              label: 'Discover',
            ),
            const NavigationDestination(
              icon: Icon(Icons.call_outlined),
              selectedIcon: Icon(Icons.call_rounded),
              label: 'Calls',
            ),
            const NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline_rounded),
              selectedIcon: Icon(Icons.chat_bubble_rounded),
              label: 'Chat',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class GmatezBrandMark extends StatelessWidget {
  const GmatezBrandMark({super.key, this.light = false, this.compact = false});

  final bool light;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = light ? AppColors.onDeep : AppColors.primaryDim;
    final wordmark = GoogleFonts.figtree(
      fontWeight: FontWeight.w800,
      color: color,
      height: 1,
      letterSpacing: -0.4,
    );

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.graphic_eq_rounded, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Text('Gmatez', style: wordmark.copyWith(fontSize: 20)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Gmatez', style: wordmark.copyWith(fontSize: 26)),
        const SizedBox(height: 4),
        Text(
          'Enterprise social calling',
          style: GoogleFonts.figtree(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: light
                ? AppColors.onDeep.withValues(alpha: 0.78)
                : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

void openLegal(BuildContext context, String title, String body) {
  context.push(AppRoutes.legal, extra: {'title': title, 'body': body});
}
