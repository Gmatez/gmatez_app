/// Backend routes under `/api/v1`. Authoritative source: NestJS controllers.
abstract final class ApiPaths {
  static const authRegister = '/auth/register';
  static const authLogin = '/auth/login';
  static const authRefresh = '/auth/refresh';
  static const authLogout = '/auth/logout';
  static const authOtpRequest = '/auth/otp/request';
  static const authOtpVerify = '/auth/otp/verify';
  static const authPhoneOtpRequest = '/auth/phone/otp/request';
  static const authPhoneOtpVerify = '/auth/phone/otp/verify';

  static const usersMe = '/users/me';
  static const usersHeartbeat = '/users/me/heartbeat';
  static String user(String id) => '/users/$id';
  static const usersMeDelete = '/users/me';

  static const profilesMe = '/profiles/me';

  static const discoveryFeed = '/discovery/feed';
  static const discoverySearch = '/discovery/search';

  static const calls = '/calls';
  static String call(String id) => '/calls/$id';
  static String callAccept(String id) => '/calls/$id/accept';
  static String callReject(String id) => '/calls/$id/reject';
  static String callCancel(String id) => '/calls/$id/cancel';
  static String callEnd(String id) => '/calls/$id/end';
  static String callHeartbeat(String id) => '/calls/$id/heartbeat';
  static String callRtcToken(String id) => '/calls/$id/rtc-token';
  static String callRtcJoined(String id) => '/calls/$id/rtc-joined';
  static String callRtcFailed(String id) => '/calls/$id/rtc-failed';

  static const rechargePlans = '/recharge-plans';
  static const callPricing = '/call-pricing';
  static const wallet = '/wallet';
  static const walletLedger = '/wallet/ledger';
  static const walletEarnings = '/wallet/earnings';

  static const paymentIntents = '/payments/intents';
  static String payment(String id) => '/payments/$id';
  static String paymentSandboxConfirm(String id) =>
      '/payments/$id/sandbox-confirm';
  static String paymentVerify(String id) => '/payments/$id/verify';
  static String paymentAbandon(String id) => '/payments/$id/abandon';

  static const conversations = '/conversations';
  static String conversationMessages(String id) =>
      '/conversations/$id/messages';
  static String conversationRead(String id) => '/conversations/$id/read';

  static const payouts = '/payouts';

  static const notifications = '/notifications';
  static const notificationsReadAll = '/notifications/read-all';
  static String notificationRead(String id) => '/notifications/$id/read';
  static const notificationDevices = '/notifications/devices';

  static const blocks = '/blocks';
  static String unblock(String userId) => '/blocks/$userId';

  static const reports = '/reports';

  static const hostsMe = '/hosts/me';
  static const hostsCompleteness = '/hosts/me/completeness';
  static const hostsDashboard = '/hosts/me/dashboard';
  static const hostsApply = '/hosts/applications';
  static const hostApplicationDocuments = '/hosts/application-documents';
  static const hostsAvailability = '/hosts/me/availability';

  static const adminOverview = '/admin/overview';
  static const adminUsers = '/admin/users';
  static String adminUser(String id) => '/admin/users/$id';
  static String adminUserStatus(String id) => '/admin/users/$id/status';
  static const adminHosts = '/admin/hosts';
  static String adminHostStatus(String id) => '/admin/hosts/$id/status';
  static const adminCalls = '/admin/calls';
  static String adminCall(String id) => '/admin/calls/$id';
  static const adminPayments = '/admin/payments';
  static const adminPayouts = '/admin/payouts';
  static String adminPayout(String id) => '/admin/payouts/$id';
  static const adminReports = '/admin/reports';
  static String adminReport(String id) => '/admin/reports/$id';
  static const adminWalletAdjustments = '/admin/wallet/adjustments';
  static const adminAuditLogs = '/admin/audit-logs';
  static String adminWalletReconcile(String userId) =>
      '/admin/users/$userId/wallet/reconcile';
  static String adminCallRefund(String id) => '/admin/calls/$id/refund';
  static const payoutDestinations = '/payouts/destinations';
  static const notificationPreferences = '/notifications/preferences';
  static const banners = '/banners';
  static const adminBanners = '/admin/banners';
  static String adminBanner(String id) => '/admin/banners/$id';
}
