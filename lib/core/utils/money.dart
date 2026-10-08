int creditsFromCents(int? cents) => (cents ?? 0) ~/ 10;

String formatPhone(String? phone) {
  if (phone == null || phone.isEmpty) {
    return '';
  }
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 12 && digits.startsWith('91')) {
    return '+91 ${digits.substring(2)}';
  }
  return phone;
}

String formatCents(int? minor, {String currency = 'USD'}) {
  final value = (minor ?? 0) / 100;
  final amount = value.toStringAsFixed(2);
  switch (currency.toUpperCase()) {
    case 'INR':
      return '₹$amount';
    default:
      return '\$$amount';
  }
}

int asInt(dynamic value, [int fallback = 0]) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

Map<String, dynamic> asMap(dynamic value) {
  return value is Map<String, dynamic>
      ? value
      : value is Map
      ? Map<String, dynamic>.from(value)
      : <String, dynamic>{};
}

List<Map<String, dynamic>> asMapList(dynamic value) {
  if (value is List) {
    return value.map(asMap).toList();
  }
  if (value is Map<String, dynamic> && value['items'] is List) {
    return (value['items'] as List).map(asMap).toList();
  }
  return const [];
}
