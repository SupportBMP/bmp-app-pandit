import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Read-only access to what `@react-native-async-storage/async-storage` left
/// on the device, so the first launch after updating from the React Native
/// build can carry the session over.
///
/// * Android: SQLite database `RKStorage`, table `catalystLocalStorage`.
/// * iOS: `<Application Support>/<bundle id>/RCTAsyncLocalStorage_V1/manifest.json`
///   (older builds used `Documents/RCTAsyncLocalStorage_V1`). Values longer
///   than 1 KB are stored in a sibling file named by the MD5 of the key, with
///   `null` in the manifest.
class LegacyAsyncStorage {
  LegacyAsyncStorage._();

  static const _keys = ['ACCESS_TOKEN', 'USER', 'APPLANG', 'APP_OPEN_FIRST_TIME', 'SAVED_TEMPLATES'];
  static const _iosBundleId = 'com.BookMyPoojaPandit';

  static Future<Map<String, String>> readAll() async {
    try {
      if (Platform.isAndroid) return await _android();
      if (Platform.isIOS) return await _ios();
    } catch (e) {
      debugPrint('Legacy storage migration skipped: $e');
    }
    return {};
  }

  static Future<Map<String, String>> _android() async {
    final path = p.join(await getDatabasesPath(), 'RKStorage');
    if (!File(path).existsSync()) return {};
    final db = await openDatabase(path, readOnly: true, singleInstance: false);
    try {
      final rows = await db.query(
        'catalystLocalStorage',
        columns: ['key', 'value'],
        where: 'key IN (${List.filled(_keys.length, '?').join(',')})',
        whereArgs: _keys,
      );
      return {for (final r in rows) '${r['key']}': '${r['value']}'};
    } finally {
      await db.close();
    }
  }

  static Future<Map<String, String>> _ios() async {
    final support = await getApplicationSupportDirectory();
    final docs = await getApplicationDocumentsDirectory();
    final candidates = [
      p.join(support.path, _iosBundleId, 'RCTAsyncLocalStorage_V1'),
      p.join(support.path, 'RCTAsyncLocalStorage_V1'),
      p.join(docs.path, 'RCTAsyncLocalStorage_V1'),
    ];
    for (final dir in candidates) {
      final manifest = File(p.join(dir, 'manifest.json'));
      if (!manifest.existsSync()) continue;
      final m = jsonDecode(await manifest.readAsString());
      if (m is! Map) continue;
      final out = <String, String>{};
      for (final k in _keys) {
        if (!m.containsKey(k)) continue;
        final v = m[k];
        if (v is String) {
          out[k] = v;
        } else {
          final f = File(p.join(dir, md5.convert(utf8.encode(k)).toString()));
          if (f.existsSync()) out[k] = await f.readAsString();
        }
      }
      if (out.isNotEmpty) return out;
    }
    return {};
  }

  /// The RN app wrote values through `JSON.stringify`, sometimes twice
  /// (`setAsyncStorageData(USER, JSON.stringify(user))`). Decode until the
  /// value is no longer a JSON-encoded string.
  static dynamic decode(String? raw) {
    if (raw == null) return null;
    dynamic v = raw;
    for (var i = 0; i < 3 && v is String; i++) {
      try {
        v = jsonDecode(v);
      } catch (_) {
        break;
      }
    }
    return v;
  }
}
