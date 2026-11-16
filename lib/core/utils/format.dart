import 'package:intl/intl.dart';

/// "hh:mm" + "AM"/"PM" → "HH:mm" (helpers.js `convertTo24Hour`).
String to24Hour(String? time, String? zone) {
  if (time == null || time.isEmpty || zone == null || zone.isEmpty) return '';
  final parts = time.split(':');
  var h = int.tryParse(parts[0]) ?? 0;
  final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  if (zone == 'PM' && h < 12) h += 12;
  if (zone == 'AM' && h == 12) h = 0;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

/// "HH:mm" → "h:mm AM" (helpers.js `convertTo12Hour`).
String to12Hour(String? time24) {
  if (time24 == null || time24.isEmpty || time24 == 'TBD') return 'TBD';
  final parts = time24.split(':');
  final h = int.tryParse(parts[0]) ?? 0;
  final mm = parts.length > 1 ? parts[1].padLeft(2, '0').substring(0, 2) : '00';
  final ampm = h >= 12 ? 'PM' : 'AM';
  final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  return '$h12:$mm $ampm';
}

DateTime? parseDate(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse('$v')?.toLocal();
}

final _ymd = DateFormat('yyyy-MM-dd');
String ymd(DateTime d) => _ymd.format(d);

String fmtDate(dynamic v, [String pattern = 'd MMM yyyy']) {
  final d = parseDate(v);
  return d == null ? '' : DateFormat(pattern).format(d);
}

String fmtTime(dynamic v) {
  final d = parseDate(v);
  return d == null ? '' : DateFormat('h:mm a').format(d);
}

final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
String inr(num? v) => _inr.format(v ?? 0);

String initials(String? name) {
  final p = (name ?? '').trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (p.isEmpty) return '?';
  if (p.length == 1) return p.first.substring(0, 1).toUpperCase();
  return (p.first.substring(0, 1) + p.last.substring(0, 1)).toUpperCase();
}

String capitalize(String? s) => (s == null || s.isEmpty) ? '' : s[0].toUpperCase() + s.substring(1);
