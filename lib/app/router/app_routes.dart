abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const otp = '/otp';
  static const register = '/register';
  static const suspended = '/account/suspended';
  static const home = '/home';
  static const discover = '/discover';
  static const myProfile = '/profile/me';
  static const editProfile = '/profile/me/edit';
  static const profile = '/profile/:userId';
  static const call = '/call/:id';
  static const calls = '/calls';
  static const messages = '/messages';
  static const chat = '/messages/:conversationId';
  static const wallet = '/wallet';
  static const earnings = '/earnings';
  static const payouts = '/payouts';
  static const notifications = '/notifications';
  static const settings = '/settings';
  static const hostApply = '/host/apply';
  static const hostOnboarding = '/host/onboarding';
  static const hostPending = '/host/pending';
  static const hostDashboard = '/host/dashboard';
  static const hostCallSettings = '/host/call-settings';
  static const admin = '/admin';
  static const legal = '/legal';

  static String profileFor(String id) => '/profile/$id';
  static String callFor(String id) => '/call/$id';
  static String chatFor(String id) => '/messages/$id';
}
