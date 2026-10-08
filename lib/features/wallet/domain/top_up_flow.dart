/// Outcome of a checkout attempt. The Razorpay SDK adapter maps into this.
enum CheckoutKind { success, cancelled, failed, externalWallet }

class CheckoutSuccess {
  const CheckoutSuccess({
    required this.orderId,
    required this.paymentId,
    required this.signature,
  });

  final String orderId;
  final String paymentId;
  final String signature;
}

/// What the wallet screen is allowed to tell the user.
/// Success is only allowed after the backend reports SUCCEEDED.
enum TopUpMessage {
  confirmedByServer,
  pendingConfirmation,
  cancelled,
  failed,
  mockConfirmed,
}

TopUpMessage interpretTopUp({
  required String provider,
  required bool allowMock,
  required String? serverStatus,
  CheckoutKind? checkout,
}) {
  if (provider == 'mock' && allowMock && serverStatus == 'SUCCEEDED') {
    return TopUpMessage.mockConfirmed;
  }
  if (serverStatus == 'SUCCEEDED') {
    return TopUpMessage.confirmedByServer;
  }
  if (checkout == CheckoutKind.cancelled || serverStatus == 'CANCELLED') {
    return TopUpMessage.cancelled;
  }
  if (checkout == CheckoutKind.failed || serverStatus == 'FAILED') {
    return TopUpMessage.failed;
  }
  return TopUpMessage.pendingConfirmation;
}

String topUpMessageText(TopUpMessage message) {
  switch (message) {
    case TopUpMessage.confirmedByServer:
    case TopUpMessage.mockConfirmed:
      return 'Payment confirmed. Credits are added by the server.';
    case TopUpMessage.cancelled:
      return 'Payment cancelled. You have not been charged.';
    case TopUpMessage.failed:
      return 'Payment failed. Your balance was not changed.';
    case TopUpMessage.pendingConfirmation:
      return 'Payment is not confirmed yet. If you were charged, the balance updates after Razorpay confirms it.';
  }
}
