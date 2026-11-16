import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../storage/prefs.dart';

class AppLanguage {
  const AppLanguage(this.code, this.native, this.english, this.letter);
  final String code;
  final String native;
  final String english;
  final String letter;
}

const appLanguages = [
  AppLanguage('en', 'English', 'English', 'A'),
  AppLanguage('hi', 'हिन्दी', 'Hindi', 'अ'),
  AppLanguage('kn', 'ಕನ್ನಡ', 'Kannada', 'ಅ'),
  AppLanguage('ta', 'தமிழ்', 'Tamil', 'அ'),
  AppLanguage('te', 'తెలుగు', 'Telugu', 'అ'),
  AppLanguage('mr', 'मराठी', 'Marathi', 'अ'),
];

/// i18next replacement over the same JSON files (`assets/i18n/*.json`).
/// Missing keys fall back to English, then to [fallback] / the key itself.
class I18n {
  I18n._();

  static final notifier = ValueNotifier<String>('en');
  static Map<String, String> _en = {};
  static Map<String, String> _cur = {};

  static String get code => notifier.value;

  static Future<void> init() async {
    _en = await _load('en');
    final stored = Prefs.lang;
    final device = PlatformDispatcher.instance.locale.languageCode;
    final pick = (stored == null || stored.isEmpty) ? device : stored;
    await _apply(appLanguages.any((l) => l.code == pick) ? pick : 'en');
  }

  static Future<Map<String, String>> _load(String code) async {
    try {
      final raw = jsonDecode(await rootBundle.loadString('assets/i18n/$code.json')) as Map;
      return raw.map((k, v) => MapEntry('$k', '$v'));
    } catch (_) {
      return {};
    }
  }

  static Future<void> _apply(String code) async {
    _cur = code == 'en' ? _en : await _load(code);
    notifier.value = code;
  }

  static Future<void> change(String code) async {
    await Prefs.setLang(code);
    await _apply(code);
  }

  static String tr(String key, {String? fallback, Map<String, Object?>? args}) {
    var s = _cur[key] ?? _en[key] ?? fallback ?? key;
    args?.forEach((k, v) => s = s.replaceAll('{{$k}}', '$v'));
    return s;
  }
}

/// Shorthand for [I18n.tr].
String t(String key, [String? fallback]) => I18n.tr(key, fallback: fallback);
