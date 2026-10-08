import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_paths.dart';
import '../../../../core/di/core_providers.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/result.dart';

/// User charge per minute from admin pricing. Null means the host rate still applies.
final userCallRateProvider = FutureProvider<int?>((ref) async {
  try {
    final result = await ref.read(apiClientProvider).get<int?>(
      ApiPaths.callPricing,
      parser: (data) {
        final cents = asMap(data)['userRatePerMinuteCents'];
        if (cents == null) {
          return null;
        }
        final parsed = asInt(cents);
        return parsed > 0 ? parsed : null;
      },
    );
    return switch (result) {
      Success(:final value) => value,
      Failure() => null,
    };
  } catch (_) {
    return null;
  }
});

int displayRateCents(int hostRate, int? globalRate) {
  if (globalRate != null && globalRate > 0) {
    return globalRate;
  }
  return hostRate;
}
