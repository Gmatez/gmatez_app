import 'package:flutter_test/flutter_test.dart';
import 'package:gmatez_app/core/utils/money.dart';
import 'package:gmatez_app/features/wallet/domain/top_up_flow.dart';

void main() {
  test('formats INR paise without treating them as dollars', () {
    expect(formatCents(50000, currency: 'INR'), '₹500.00');
    expect(formatCents(50000), r'$500.00');
  });

  test('checkout success is not a wallet credit until the server says so', () {
    expect(
      interpretTopUp(
        provider: 'razorpay',
        allowMock: false,
        serverStatus: 'REQUIRES_ACTION',
        checkout: CheckoutKind.success,
      ),
      TopUpMessage.pendingConfirmation,
    );
    expect(
      interpretTopUp(
        provider: 'razorpay',
        allowMock: false,
        serverStatus: 'SUCCEEDED',
        checkout: CheckoutKind.success,
      ),
      TopUpMessage.confirmedByServer,
    );
  });

  test('cancelled and failed checkouts do not claim success', () {
    expect(
      interpretTopUp(
        provider: 'razorpay',
        allowMock: false,
        serverStatus: 'CANCELLED',
        checkout: CheckoutKind.cancelled,
      ),
      TopUpMessage.cancelled,
    );
    expect(
      interpretTopUp(
        provider: 'razorpay',
        allowMock: false,
        serverStatus: 'FAILED',
        checkout: CheckoutKind.failed,
      ),
      TopUpMessage.failed,
    );
  });

  test('a duplicate success callback still depends on the server status', () {
    final first = interpretTopUp(
      provider: 'razorpay',
      allowMock: false,
      serverStatus: 'SUCCEEDED',
      checkout: CheckoutKind.success,
    );
    final second = interpretTopUp(
      provider: 'razorpay',
      allowMock: false,
      serverStatus: 'SUCCEEDED',
      checkout: CheckoutKind.success,
    );
    expect(first, TopUpMessage.confirmedByServer);
    expect(second, first);
    expect(topUpMessageText(first), contains('server'));
  });
}
