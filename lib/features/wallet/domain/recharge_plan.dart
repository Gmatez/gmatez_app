import '../../../core/utils/money.dart';

class RechargePlan {
  const RechargePlan({
    required this.id,
    required this.name,
    required this.priceMinor,
    required this.walletCreditMinor,
    required this.bonusMinor,
    required this.coins,
    required this.bonusCoins,
    required this.description,
    required this.displayOrder,
  });

  final String id;
  final String name;
  final int priceMinor;
  final int walletCreditMinor;
  final int bonusMinor;
  final int coins;
  final int bonusCoins;
  final String description;
  final int displayOrder;

  int get credits => coins;
  int get bonusCredits => bonusCoins;
  String get priceLabel => formatCents(priceMinor);
  bool get recommended => displayOrder == 0;

  /// Badge text comes from the plan name or description published by the backend.
  String? get badgeLabel {
    final source = '$name $description'.toLowerCase();
    final percent = RegExp(r'(\d+)\s*%').firstMatch(source);
    if (source.contains('off') && percent != null) {
      return '${percent.group(1)}% OFF';
    }
    if (source.contains('popular')) {
      return 'MOST POPULAR';
    }
    if (source.contains('best value')) {
      return 'BEST VALUE';
    }
    return null;
  }

  factory RechargePlan.fromJson(Map<String, dynamic> json) {
    return RechargePlan(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      priceMinor: asInt(json['priceMinor']),
      walletCreditMinor: asInt(json['walletCreditMinor']),
      bonusMinor: asInt(json['bonusMinor']),
      coins: json['coins'] != null
          ? asInt(json['coins'])
          : creditsFromCents(asInt(json['walletCreditMinor'])),
      bonusCoins: json['bonusCoins'] != null
          ? asInt(json['bonusCoins'])
          : creditsFromCents(asInt(json['bonusMinor'])),
      description: json['description'] as String? ?? '',
      displayOrder: asInt(json['displayOrder']),
    );
  }
}
