import 'package:flutter_test/flutter_test.dart';
import 'package:gmatez_app/core/utils/activity_label.dart';
import 'package:gmatez_app/features/calls/presentation/state/call_rate_provider.dart';
import 'package:gmatez_app/features/wallet/domain/recharge_plan.dart';

void main() {
  test('maps an active recharge plan into credits and price', () {
    final plan = RechargePlan.fromJson({
      'id': 'plan-1',
      'name': 'Standard',
      'priceMinor': 25000,
      'walletCreditMinor': 27500,
      'bonusMinor': 2500,
      'description': 'Best value',
      'displayOrder': 0,
    });
    expect(plan.credits, 2750);
    expect(plan.bonusCredits, 250);
    expect(plan.priceLabel, r'$250.00');
    expect(plan.recommended, isTrue);
    expect(plan.badgeLabel, 'BEST VALUE');
    expect(plan.coins, 2750);
  });

  test('uses the admin coins field instead of the rupee price', () {
    final plan = RechargePlan.fromJson({
      'id': 'plan-299',
      'name': '299',
      'priceMinor': 29900,
      'walletCreditMinor': 29900,
      'bonusMinor': 0,
      'coins': 299,
      'bonusCoins': 0,
      'description': '',
      'displayOrder': 1,
    });
    expect(plan.coins, 299);
    expect(plan.credits, 299);
  });

  test('uses the admin call price when one is published', () {
    expect(displayRateCents(400, 700), 700);
    expect(displayRateCents(400, null), 400);
  });

  test('formats last active in the device timezone', () {
    final now = DateTime(2026, 9, 29, 18, 0);
    expect(
      activityLabel(now.subtract(const Duration(minutes: 5)), now: now),
      '5 minutes ago',
    );
    expect(
      activityLabel(now.subtract(const Duration(days: 1)), now: now),
      'Yesterday',
    );
    expect(
      activityLabel(DateTime.utc(2026, 9, 20, 12), now: now),
      'Sep 20, 2026',
    );
  });
}
