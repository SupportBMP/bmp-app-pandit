import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';

import '../config/env.dart';
import 'json.dart';

class AppLocation {
  const AppLocation(this.latitude, this.longitude, this.city, this.state);
  final double latitude;
  final double longitude;
  final String city;
  final String state;

  /// Bengaluru — the RN app's fallback when location is unavailable.
  static const fallback = AppLocation(12.9716, 77.5946, 'Bengaluru', 'Karnataka');
}

/// Current position + city/state (Home / Panchang). Asks for permission once
/// per app run; falls back to Bengaluru.
class LocationService {
  LocationService._();

  static AppLocation? _cached;
  static bool _asked = false;

  static Future<AppLocation> current({bool ask = true}) async {
    if (_cached != null) return _cached!;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return AppLocation.fallback;
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied && ask && !_asked) {
        _asked = true;
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return AppLocation.fallback;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 15)),
      );
      final (city, state) = await _reverse(pos.latitude, pos.longitude);
      return _cached = AppLocation(pos.latitude, pos.longitude, city, state);
    } catch (_) {
      return AppLocation.fallback;
    }
  }

  static Future<(String, String)> _reverse(double lat, double lng) async {
    try {
      final r = await Dio().get(
        'https://maps.googleapis.com/maps/api/geocode/json',
        queryParameters: {'latlng': '$lat,$lng', 'key': Env.googlePlacesKey, 'language': 'en', 'result_type': 'locality|administrative_area_level_2'},
      );
      final results = objList(obj(r.data)['results']);
      if (results.isEmpty) return (AppLocation.fallback.city, AppLocation.fallback.state);
      final comps = objList(results.first['address_components']);
      String find(String type) => str(comps.firstWhere((c) => list(c['types']).contains(type), orElse: () => {})['long_name']);
      final city = [find('locality'), find('sublocality'), find('administrative_area_level_2')].firstWhere((e) => e.isNotEmpty, orElse: () => 'Unknown City');
      return (city, find('administrative_area_level_1'));
    } catch (_) {
      return (AppLocation.fallback.city, AppLocation.fallback.state);
    }
  }
}
