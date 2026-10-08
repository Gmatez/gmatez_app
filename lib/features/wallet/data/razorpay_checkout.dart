import 'dart:async';

import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../domain/top_up_flow.dart';

class RazorpayCheckoutRequest {
  const RazorpayCheckoutRequest({
    required this.keyId,
    required this.orderId,
    required this.amountPaise,
    required this.currency,
  });

  final String keyId;
  final String orderId;
  final int amountPaise;
  final String currency;
}

class RazorpayCheckout {
  Future<({CheckoutKind kind, CheckoutSuccess? success, String? message})>
  open(RazorpayCheckoutRequest request) async {
    if (request.keyId.isEmpty || request.orderId.isEmpty) {
      return (
        kind: CheckoutKind.failed,
        success: null,
        message: 'Missing Razorpay checkout details',
      );
    }
    final razorpay = Razorpay();
    final completer =
        Completer<
          ({CheckoutKind kind, CheckoutSuccess? success, String? message})
        >();
    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (
      PaymentSuccessResponse response,
    ) {
      if (completer.isCompleted) {
        return;
      }
      final orderId = response.orderId ?? '';
      final paymentId = response.paymentId ?? '';
      final signature = response.signature ?? '';
      if (orderId.isEmpty || paymentId.isEmpty || signature.isEmpty) {
        completer.complete((
          kind: CheckoutKind.failed,
          success: null,
          message: 'Checkout response was incomplete',
        ));
        return;
      }
      completer.complete((
        kind: CheckoutKind.success,
        success: CheckoutSuccess(
          orderId: orderId,
          paymentId: paymentId,
          signature: signature,
        ),
        message: null,
      ));
    });
    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (
      PaymentFailureResponse response,
    ) {
      if (completer.isCompleted) {
        return;
      }
      final cancelled = response.code == 2 ||
          (response.message ?? '').toLowerCase().contains('cancel');
      completer.complete((
        kind: cancelled ? CheckoutKind.cancelled : CheckoutKind.failed,
        success: null,
        message: response.message,
      ));
    });
    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (
      ExternalWalletResponse response,
    ) {
      if (completer.isCompleted) {
        return;
      }
      completer.complete((
        kind: CheckoutKind.externalWallet,
        success: null,
        message: response.walletName,
      ));
    });
    try {
      razorpay.open({
        'key': request.keyId,
        'amount': request.amountPaise,
        'currency': request.currency,
        'order_id': request.orderId,
        'name': 'Gmatez',
        'description': 'Calling credits',
      });
      return await completer.future;
    } finally {
      razorpay.clear();
    }
  }
}
