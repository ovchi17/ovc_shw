extension DurationFormat on Duration {
  String get mmss {
    final m = inMinutes.toString().padLeft(2, '0');
    final s = (inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get mss {
    final m = inMinutes;
    final s = (inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class DateFormat {
  static String dayMonthYear(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.'
      '${d.month.toString().padLeft(2, '0')}.'
      '${d.year}';

  static String dayMonthTime(DateTime dt) =>
      '${dt.day} ${_monthsShort[dt.month]}, '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';

  static String dayMonth(DateTime d) =>
      '${d.day}.${d.month.toString().padLeft(2, '0')}';

  static String shortFromIso(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    return '${dt.day} ${_monthsShort[dt.month]}';
  }

  static String fullFromIso(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    return dayMonthTime(dt);
  }

  static const _monthsShort = [
    '', 'янв', 'фев', 'мар', 'апр', 'май', 'июн',
    'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
  ];
}

String pluralizeDays(int n) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod100 >= 11 && mod100 <= 14) return 'дней';
  if (mod10 == 1) return 'день';
  if (mod10 >= 2 && mod10 <= 4) return 'дня';
  return 'дней';
}
String formatDurationSec(num? sec) {
  if (sec == null || sec == 0) return '';
  return Duration(seconds: sec.toInt()).mss;
}
