import 'package:dio/dio.dart';

import '../utils/timezone.dart';
import 'api_client.dart';

/// Every backend call the Pandit app makes — a 1:1 port of
/// `src/services/index.js`. Each method returns the decoded response body.
class Api {
  Api._();

  static Dio get _d => ApiClient.instance.dio;

  static Future<dynamic> _get(String path, [Map<String, dynamic>? q]) async => (await _d.get(path, queryParameters: _clean(q))).data;
  static Future<dynamic> _post(String path, [Object? body, Map<String, dynamic>? q]) async =>
      (await _d.post(path, data: body, queryParameters: _clean(q))).data;
  static Future<dynamic> _put(String path, [Object? body]) async => (await _d.put(path, data: body)).data;
  static Future<dynamic> _patch(String path, [Object? body]) async => (await _d.patch(path, data: body)).data;
  static Future<dynamic> _delete(String path) async => (await _d.delete(path)).data;

  /// Drops null / empty values, like the RN code's `if (x) params.append(...)`.
  static Map<String, dynamic>? _clean(Map<String, dynamic>? q) {
    if (q == null) return null;
    final m = <String, dynamic>{};
    q.forEach((k, v) {
      if (v != null && '$v'.isNotEmpty) m[k] = v;
    });
    return m;
  }

  static Future<Map<String, dynamic>> _withTimezone(Map<String, dynamic> payload) async => {...payload, 'timezone': await deviceTimezone()};

  // ── Auth ───────────────────────────────────────────────────────────────
  /// Returns the full response: the status code tells a new account (201)
  /// from a returning one.
  static Future<Response> sendPhoneOtp(String phoneNumber, String countryCode) =>
      _d.post('/api/auth/send-otp', data: {'phoneNumber': phoneNumber, 'countryCode': countryCode});
  static Future<Response> verifyPhoneOtp(String phoneNumber, String countryCode, String otp) =>
      _d.post('/api/auth/verify-otp', data: {'phoneNumber': phoneNumber, 'countryCode': countryCode, 'otpValue': otp});
  static Future<dynamic> resendPhoneOtp(String phoneNumber, String countryCode) =>
      _post('/api/auth/resend-otp', {'phoneNumber': phoneNumber, 'countryCode': countryCode});
  static Future<dynamic> addReferralCode(String code) => _post('/api/auth/referral', {'referralCode': code});
  static Future<dynamic> updateProfile(Map<String, dynamic> payload) => _post('/api/auth/update-profile', payload);
  static Future<dynamic> toggleAvailability(bool isAvailable) => _post('/api/auth/toggle-availability', {'isAvailable': isAvailable});
  static Future<dynamic> getProfile([String? lang]) => _get('/api/auth/get-profile', {'lang': lang});
  static Future<dynamic> getOptions([String? lang]) => _get('/api/auth/get-options', {'lang': lang});
  static Future<dynamic> getProfileSummary() => _get('/api/auth/profile-summary');

  // ── Certificates ───────────────────────────────────────────────────────
  static Future<dynamic> addCertificate(Map<String, dynamic> p) => _post('/api/auth/add-certificate', p);
  static Future<dynamic> getCertificates() => _get('/api/auth/get-certificate');
  static Future<dynamic> updateCertificate(String id, Map<String, dynamic> p) => _put('/api/auth/update-certificate/$id', p);
  static Future<dynamic> deleteCertificate(String id) => _delete('/api/auth/delete-certificate/$id');

  // ── Media ──────────────────────────────────────────────────────────────
  static Future<dynamic> presignedUrl(Map<String, dynamic> p) => _post('/api/media/upload', p);
  static Future<dynamic> uploadPortfolioMedia(Map<String, dynamic> p) => _post('/api/portfolio/upload', p);
  static Future<dynamic> fetchPortfolioMedia() => _get('/api/portfolio');

  // ── Push ───────────────────────────────────────────────────────────────
  static Future<dynamic> saveFcmToken(Map<String, dynamic> p) => _post('/api/fcm-token/save', p);

  // ── Poojas (bookings) ──────────────────────────────────────────────────
  static Future<dynamic> createPooja(Map<String, dynamic> p) async => _post('/api/pooja/create-pooja', await _withTimezone(p));
  static Future<dynamic> updatePooja(Map<String, dynamic> p) async => _post('/api/pooja/update-pooja', await _withTimezone(p));
  static Future<dynamic> getPoojas({String? date, String? fromDate, String? status, String? poojaTitle}) =>
      _get('/api/pooja/get-poojas', {'date': date, 'fromDate': fromDate, 'status': status, 'poojaTitle': poojaTitle});
  static Future<dynamic> updatePoojaStatus(String poojaId, Map<String, dynamic> action) =>
      _post('/api/pooja/update-pooja-status', action, {'poojaId': poojaId});
  static Future<dynamic> getPoojaById(String id) => _get('/api/pooja/$id');
  static Future<dynamic> getPoojaOfferings(String poojaId) => _get('/api/offering/$poojaId');
  static Future<dynamic> getPoojaReviews(String poojaId) => _get('/api/review/$poojaId');
  static Future<dynamic> getRecordingsByPooja(String poojaId) => _get('/api/recording/$poojaId');

  // ── E-Puja events ──────────────────────────────────────────────────────
  static Future<dynamic> getEPoojaEvents({String? fromDate}) => _get('/api/epooja-event/all', {'fromDate': fromDate});
  static Future<dynamic> createEPoojaEvent(Map<String, dynamic> p) async => _post('/api/epooja-event/create', await _withTimezone(p));
  static Future<dynamic> updateEPoojaEvent(Map<String, dynamic> p) async => _post('/api/epooja-event/update', await _withTimezone(p));
  static Future<dynamic> updateEPoojaEventStatus(String id, Map<String, dynamic> p) => _post('/api/epooja-event/status-update', p, {'epoojaId': id});
  static Future<dynamic> getEPoojaEventById(String id) => _get('/api/epooja-event/$id');
  static Future<dynamic> updateEPoojaSankalpa(String id, Object sankalpa) => _patch('/api/epooja-event/$id/sankalpa', sankalpa);
  static Future<dynamic> getEPoojaSankalpaBookings(String id) => _get('/api/epooja-event/$id/sankalpa-bookings');
  static Future<dynamic> getEPoojaOfferings(String eventId) => _get('/api/offering/epooja-event/$eventId');
  static Future<dynamic> getTotalOfferings(String channelId, [String? eventType]) =>
      _get('/api/offering/total-offerings', {'channelId': channelId, 'eventType': eventType});

  // ── Families (devotees) ────────────────────────────────────────────────
  static Future<dynamic> getFamilies() => _get('/api/family/get-families');
  static Future<dynamic> getFamiliesCount() => _get('/api/family/get-families-count');
  static Future<dynamic> createFamily(Map<String, dynamic> p) => _post('/api/family/create-family', p);
  static Future<dynamic> updateFamily(String id, Map<String, dynamic> p) => _post('/api/family/$id/update', p);
  static Future<dynamic> deleteFamily(String id) => _delete('/api/family/$id');
  static Future<dynamic> getFamilyMembers(String id) => _get('/api/family/$id/get-members');
  static Future<dynamic> addFamilyMember(String id, Map<String, dynamic> p) => _post('/api/family/$id/add-member', p);
  static Future<dynamic> updateFamilyMember(String id, String memberId, Map<String, dynamic> p) => _post('/api/family/$id/members/$memberId/update', p);
  static Future<dynamic> deleteFamilyMember(String id, String memberId) => _delete('/api/family/$id/members/$memberId');

  // ── Payments & subscription ────────────────────────────────────────────
  static Future<dynamic> getPaymentLink(String poojaId, Object? notes) => _post('/api/payment/intent', {'poojaId': poojaId, 'notes': notes});
  static Future<dynamic> fetchPlans() => _get('/api/plan/fetch-plans');
  static Future<dynamic> createSubscription(Map<String, dynamic> p) => _post('/api/subscription/intent', p);
  static Future<dynamic> getSubscription() => _get('/api/subscription/current');
  static Future<dynamic> cancelSubscription() => _post('/api/subscription/cancel');
  static Future<dynamic> activateTrial() => _post('/api/subscription/trial/activate');
  static Future<dynamic> checkTrialEligibility() => _get('/api/subscription/trial/eligibility');
  static Future<dynamic> getTrialSettings() => _get('/api/subscription/trial/settings');

  // ── Blessing points ────────────────────────────────────────────────────
  static Future<dynamic> getRewardsSummary() => _get('/api/rewards/summary');
  static Future<dynamic> getRewardsHistory() => _get('/api/rewards/history');

  // ── Samagri ────────────────────────────────────────────────────────────
  static Future<dynamic> searchSamagri({String? text, String? lang}) => _get('/api/samagri/search', {'text': text, 'lang': lang});
  static Future<dynamic> allSamagri([String? lang]) => _get('/api/samagri/all', {'lang': lang});
  static Future<dynamic> getSamagriLists() => _get('/api/samagri-list');
  static Future<dynamic> getSamagriListById(String id, [String? lang]) => _get('/api/samagri-list/$id', {'lang': lang});
  static Future<dynamic> createSamagriList(Map<String, dynamic> p) => _post('/api/samagri-list/add', p);
  static Future<dynamic> updateSamagriListTitle(String id, Map<String, dynamic> p) => _post('/api/samagri-list/$id/update-title', p);
  static Future<dynamic> addSamagriListItems(String id, Object p) => _post('/api/samagri-list/$id/items', p);
  static Future<dynamic> deleteSamagriList(String id) => _delete('/api/samagri-list/$id');

  // ── Panchang ───────────────────────────────────────────────────────────
  static Future<dynamic> getPanchanga(Map<String, dynamic> p) => _post('/api/panchang/comprehensive-local', p);
  static Future<dynamic> getMonthlyPanchang(Map<String, dynamic> p) => _post('/api/panchang/monthly', p);

  // ── Web bookings ───────────────────────────────────────────────────────
  static Future<dynamic> fetchWebBookings() => _get('/api/web-booking-management');
  static Future<dynamic> updateWebBookingAction(Map<String, dynamic> p) => _post('/api/web-booking-management/update-action', p);
  static Future<dynamic> fetchWebBookingById(String id) => _get('/api/web-booking/$id');

  // ── Kundli ─────────────────────────────────────────────────────────────
  static Future<dynamic> generateKundli(Map<String, dynamic> p) => _post('/api/kundli/generate', p);
  static Future<dynamic> checkKundliCompatibility(Map<String, dynamic> p) => _post('/api/kundli/compatibility', p);
  static Future<dynamic> saveKundliProfile(Map<String, dynamic> p) => _post('/api/kundli/profiles', p);
  static Future<dynamic> getKundliProfiles() => _get('/api/kundli/profiles');
  static Future<dynamic> deleteKundliProfile(String id) => _delete('/api/kundli/profiles/$id');

  // ── Image templates ────────────────────────────────────────────────────
  static Future<dynamic> getActiveTemplates({int page = 1, int limit = 10}) => _get('/api/admin/image-templates/active', {'page': page, 'limit': limit});
  static Future<dynamic> getTemplateById(String id) => _get('/api/admin/image-templates/active/$id');
}
