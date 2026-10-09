/// Time formatting for the session list, ported from Format.kt.
String formatRelativeTime(int millis) {
  if (millis <= 0) return '';
  final now = DateTime.now();
  final date = DateTime.fromMillisecondsSinceEpoch(millis);
  final diff = now.millisecondsSinceEpoch - millis;
  if (diff < 60_000) return '刚刚';
  if (diff < 3_600_000) return '${diff ~/ 60_000} 分钟前';
  if (diff < 86_400_000) return '${diff ~/ 3_600_000} 小时前';
  if (_sameDay(date, now)) {
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
  if (diff < 7 * 86_400_000) return '${diff ~/ 86_400_000} 天前';
  final yyyy = date.year.toString().padLeft(4, '0');
  final mm = date.month.toString().padLeft(2, '0');
  final dd = date.day.toString().padLeft(2, '0');
  return '$yyyy-$mm-$dd';
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
