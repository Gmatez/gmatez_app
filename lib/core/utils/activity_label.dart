const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Relative activity time. Stored timestamps stay UTC; this uses the device zone.
String activityLabel(DateTime? value, {DateTime? now}) {
  if (value == null) {
    return '';
  }
  final local = value.toLocal();
  final clock = (now ?? DateTime.now()).toLocal();
  final age = clock.difference(local);
  if (age.isNegative || age.inSeconds < 45) {
    return 'Just now';
  }
  if (age.inMinutes < 60) {
    final minutes = age.inMinutes;
    return minutes == 1 ? '1 minute ago' : '$minutes minutes ago';
  }
  if (age.inHours < 24) {
    final hours = age.inHours;
    return hours == 1 ? '1 hour ago' : '$hours hours ago';
  }
  final yesterday = DateTime(clock.year, clock.month, clock.day - 1);
  final day = DateTime(local.year, local.month, local.day);
  if (day == yesterday) {
    return 'Yesterday';
  }
  return '${_months[local.month - 1]} ${local.day}, ${local.year}';
}
