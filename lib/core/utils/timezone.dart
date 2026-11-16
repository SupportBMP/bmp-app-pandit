import 'package:flutter_timezone/flutter_timezone.dart';

String? _cached;

/// The device's IANA timezone (e.g. "Asia/Kolkata"), sent with every pooja /
/// e-puja create and update. Falls back to IST like the RN app.
Future<String> deviceTimezone() async {
  if (_cached != null) return _cached!;
  try {
    _cached = (await FlutterTimezone.getLocalTimezone()).identifier;
  } catch (_) {
    _cached = 'Asia/Kolkata';
  }
  return _cached!;
}
