import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/env.dart';
import '../storage/prefs.dart';

/// HTTP client for the Pandit backend (port of `src/services/http.js`):
/// bearer token on every request, and a 401 signs the Pandit out.
class ApiClient {
  ApiClient._() {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          final t = Prefs.token;
          if (t != null && t.isNotEmpty) o.headers['Authorization'] = 'Bearer $t';
          h.next(o);
        },
        onError: (e, h) async {
          if (e.response?.statusCode == 401 && Prefs.token != null) {
            await Prefs.clearSession();
            onUnauthorized?.call();
          }
          h.next(e);
        },
      ),
    );
    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: false, logPrint: (o) => debugPrint('$o')));
    }
  }

  static final ApiClient instance = ApiClient._();

  final Dio dio = Dio(BaseOptions(baseUrl: Env.apiBaseUrl, connectTimeout: const Duration(seconds: 20), receiveTimeout: const Duration(seconds: 40)));

  /// Set by the app shell: clears in-memory state and returns to login.
  static VoidCallback? onUnauthorized;
}

/// The server's error message, if any, else [fallback]
/// (`error.response?.data?.message || fallback`).
String apiError(Object e, [String fallback = 'Something went wrong']) {
  if (e is DioException) {
    final d = e.response?.data;
    if (d is Map) {
      final m = d['message'] ?? d['error'];
      if (m is String && m.isNotEmpty) return m;
      if (m is List && m.isNotEmpty) return m.join(', ');
    }
    if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
      return 'No internet connection. Please try again.';
    }
  }
  return fallback;
}
