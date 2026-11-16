import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'legacy_async_storage.dart';

/// Local persistence. Keys mirror the React Native app's AsyncStorage keys so
/// the meaning of each value is unchanged.
///
/// The access token lives in the platform keystore; everything else in
/// SharedPreferences.
class Prefs {
  Prefs._();

  static const kLang = 'APPLANG';
  static const kOnboarded = 'APP_OPEN_FIRST_TIME';
  static const kUser = 'USER';
  static const kSavedTemplates = 'SAVED_TEMPLATES';
  static const _kToken = 'ACCESS_TOKEN';
  static const _kMigrated = '__legacy_rn_migrated_v1';

  static late SharedPreferences _p;
  static const _secure = FlutterSecureStorage();
  static String? _token;

  static Future<void> init() async {
    _p = await SharedPreferences.getInstance();
    try {
      _token = await _secure.read(key: _kToken);
    } catch (_) {
      _token = null;
    }
    if (_p.getBool(_kMigrated) != true) {
      await _migrateFromReactNative();
      await _p.setBool(_kMigrated, true);
    }
  }

  /// One-time import of the React Native app's AsyncStorage so a Pandit who
  /// updates from the old app stays signed in with the same language.
  static Future<void> _migrateFromReactNative() async {
    final legacy = await LegacyAsyncStorage.readAll();
    if (legacy.isEmpty) return;

    final token = LegacyAsyncStorage.decode(legacy['ACCESS_TOKEN']);
    if (token is String && token.isNotEmpty) await setToken(token);

    final lang = LegacyAsyncStorage.decode(legacy['APPLANG']);
    if (lang is String && lang.isNotEmpty) await setLang(lang);

    if (LegacyAsyncStorage.decode(legacy['APP_OPEN_FIRST_TIME']) != null) {
      await setOnboarded();
    }

    final user = LegacyAsyncStorage.decode(legacy['USER']);
    if (user is Map) await setUser(Map<String, dynamic>.from(user));

    final templates = LegacyAsyncStorage.decode(legacy['SAVED_TEMPLATES']);
    if (templates is List) await _p.setString(kSavedTemplates, jsonEncode(templates));
  }

  // ── Session ────────────────────────────────────────────────────────────
  static String? get token => _token;

  static Future<void> setToken(String? token) async {
    _token = token;
    try {
      if (token == null) {
        await _secure.delete(key: _kToken);
      } else {
        await _secure.write(key: _kToken, value: token);
      }
    } catch (_) {
      // Keystore unavailable: keep the in-memory token for this run.
    }
  }

  static Map<String, dynamic>? get user {
    final raw = _p.getString(kUser);
    if (raw == null) return null;
    try {
      final v = jsonDecode(raw);
      return v is Map ? Map<String, dynamic>.from(v) : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> setUser(Map<String, dynamic>? user) async {
    if (user == null) {
      await _p.remove(kUser);
    } else {
      await _p.setString(kUser, jsonEncode(user));
    }
  }

  static Future<void> clearSession() async {
    await setToken(null);
    await setUser(null);
  }

  // ── App ────────────────────────────────────────────────────────────────
  /// `null` = never chosen; the first launch shows the language picker.
  static String? get lang => _p.getString(kLang);
  static Future<void> setLang(String code) => _p.setString(kLang, code);

  static bool get onboarded => _p.getString(kOnboarded) != null;
  static Future<void> setOnboarded() => _p.setString(kOnboarded, 'firstTimeOpen');

  static List<dynamic> get savedTemplates {
    final raw = _p.getString(kSavedTemplates);
    if (raw == null) return [];
    try {
      final v = jsonDecode(raw);
      return v is List ? v : [];
    } catch (_) {
      return [];
    }
  }

  static Future<void> setSavedTemplates(List<dynamic> v) => _p.setString(kSavedTemplates, jsonEncode(v));
}
