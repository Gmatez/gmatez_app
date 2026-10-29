import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/screens/admin_console_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/suspended_account_screen.dart';
import '../../features/auth/presentation/state/auth_notifier.dart';
import '../../features/auth/presentation/state/auth_state.dart';
import '../../features/calls/presentation/screens/call_history_screen.dart';
import '../../features/calls/presentation/screens/call_screen.dart';
import '../../features/chat/presentation/screens/chat_thread_screen.dart';
import '../../features/chat/presentation/screens/conversations_screen.dart';
import '../../features/discovery/presentation/screens/discovery_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/host/presentation/screens/host_apply_screen.dart';
import '../../features/host/presentation/screens/host_call_settings_screen.dart';
import '../../features/host/presentation/screens/host_dashboard_screen.dart';

import '../../features/host/presentation/screens/host_onboarding_screen.dart';
import '../../features/host/presentation/screens/host_pending_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/my_profile_screen.dart';
import '../../features/profile/presentation/screens/public_profile_screen.dart';
import '../../features/settings/presentation/screens/legal_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/splash/presentation/screens/splash_screen.dart';
import '../../features/wallet/presentation/screens/earnings_screen.dart';
import '../../features/wallet/presentation/screens/payouts_screen.dart';
import '../../features/wallet/presentation/screens/wallet_screen.dart';
import '../shell/app_shell.dart';
import 'app_routes.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen<AuthState>(authNotifierProvider, (_, _) {
    refresh.value++;
  });
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authNotifierProvider);
      final location = state.matchedLocation;
      final loggingIn =
          location == AppRoutes.login ||
          location == AppRoutes.otp ||
          location == AppRoutes.register;
      final onSuspended = location == AppRoutes.suspended;

      if (auth.isUnknown) {
        return location == AppRoutes.splash ? null : AppRoutes.splash;
      }
      if (auth.isSuspended) {
        return onSuspended ? null : AppRoutes.suspended;
      }
      if (!auth.isAuthenticated && !loggingIn) {
        return AppRoutes.login;
      }
      if (auth.isAuthenticated && (loggingIn || location == AppRoutes.splash || onSuspended)) {
        if (auth.user?.isAdmin == true) {
          return AppRoutes.admin;
        }
        return AppRoutes.home;
      }
      if (auth.isAuthenticated &&
          auth.user?.isSuspendedHost == true &&
          (location == AppRoutes.hostDashboard ||
              location == AppRoutes.hostCallSettings ||
              location == AppRoutes.hostApply ||
              location == AppRoutes.hostOnboarding)) {
        return AppRoutes.home;
      }
      if (auth.isAuthenticated &&
          location.startsWith(AppRoutes.admin) &&
          auth.user?.isAdmin != true) {
        return AppRoutes.home;
      }
      if (auth.user?.isActiveHost == true && location == AppRoutes.discover) {
        return AppRoutes.home;
      }
      if (auth.isAuthenticated) {
        final activeHost = auth.user?.isActiveHost == true;
        final hostOnly =
            location == AppRoutes.hostDashboard ||
            location == AppRoutes.hostCallSettings ||
            location == AppRoutes.earnings ||
            location == AppRoutes.payouts;
        if (hostOnly && !activeHost) {
          return AppRoutes.home;
        }
        final callerOnly =
            location == AppRoutes.hostApply ||
            location == AppRoutes.hostOnboarding;
        if (callerOnly && activeHost) {
          return AppRoutes.home;
        }
        if (location == AppRoutes.hostPending &&
            (activeHost || auth.user?.host == null)) {
          return AppRoutes.home;
        }
      }
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: AppRoutes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: AppRoutes.otp, builder: (_, _) => const OtpScreen()),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, _) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.suspended,
        builder: (_, _) => const SuspendedAccountScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (_, _) {
                  final user = ref.read(authNotifierProvider).user;
                  if (user?.isActiveHost == true) {
                    return const HostDashboardScreen();
                  }
                  if (user?.isRejectedHost == true ||
                      user?.isSuspendedHost == true) {
                    return const HostPendingScreen();
                  }
                  return const HomeScreen();
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.discover,
                builder: (_, state) => DiscoveryScreen(
                  callType: state.uri.queryParameters['callType'],
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.calls,
                builder: (_, _) => const CallHistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.wallet,
                builder: (_, _) {
                  final user = ref.read(authNotifierProvider).user;
                  if (user?.isActiveHost == true) {
                    return const EarningsScreen();
                  }
                  return const WalletScreen();
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.myProfile,
                builder: (_, _) => const MyProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      // Chat stays reachable by direct link, but it is not a bottom-nav tab.
      GoRoute(
        path: AppRoutes.messages,
        builder: (_, _) => const ConversationsScreen(),
        routes: [
          GoRoute(
            path: ':conversationId',
            builder: (context, state) {
              final id = state.pathParameters['conversationId'] ?? '';
              return ChatThreadScreen(conversationId: id);
            },
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.editProfile,
        builder: (_, _) => const EditProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.earnings,
        builder: (_, _) => const EarningsScreen(),
      ),
      GoRoute(
        path: AppRoutes.payouts,
        builder: (_, _) => const PayoutsScreen(),
      ),
      GoRoute(
        path: AppRoutes.hostCallSettings,
        builder: (_, _) => const HostCallSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.admin,
        builder: (_, _) => const AdminConsoleScreen(),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (_, _) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.legal,
        builder: (context, state) {
          final extra = state.extra;
          final map = extra is Map
              ? Map<Object?, Object?>.from(extra)
              : const <Object?, Object?>{};
          return LegalScreen(
            title: '${map['title'] ?? 'Info'}',
            body: '${map['body'] ?? ''}',
          );
        },
      ),
      GoRoute(
        path: AppRoutes.hostApply,
        builder: (_, _) => const HostApplyScreen(),
      ),
      GoRoute(
        path: AppRoutes.hostOnboarding,
        builder: (_, _) => const HostOnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.hostPending,
        builder: (_, _) => const HostPendingScreen(),
      ),
      GoRoute(
        path: AppRoutes.hostDashboard,
        builder: (_, _) => const HostDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) {
          final userId = state.pathParameters['userId'] ?? '';
          return PublicProfileScreen(userId: userId);
        },
      ),
      GoRoute(
        path: AppRoutes.call,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return CallScreen(callId: id);
        },
      ),
    ],
  );
});
