import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api.dart';
import '../storage/prefs.dart';
import '../utils/json.dart';

/// The signed-in Pandit (Redux `state.user.user` in the RN app).
class SessionNotifier extends Notifier<Json?> {
  @override
  Json? build() => Prefs.user;

  Future<void> setUser(Json? user) async {
    state = user;
    await Prefs.setUser(user);
  }

  Future<void> signIn(String token, Json user) async {
    await Prefs.setToken(token);
    await setUser(user);
  }

  /// Fetches the latest profile (KYC status, availability, …). Falls back to
  /// the cached user when offline.
  Future<Json?> refresh() async {
    try {
      final r = obj(await Api.getProfile());
      final u = r['data'] ?? r['user'];
      if (u is Map) {
        await setUser(obj(u));
      }
    } catch (_) {}
    return state;
  }

  void patch(Json fields) {
    if (state == null) return;
    setUser({...state!, ...fields});
  }

  Future<void> signOut() async {
    await Prefs.clearSession();
    state = null;
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, Json?>(SessionNotifier.new);

/// Where a signed-in Pandit belongs, by KYC status — the routing shared by
/// Splash, Verify and WaitingForApproval in the RN app.
enum AuthDestination { home, intro, referral, profileInfo, waiting }

AuthDestination destinationFor(Json? user, {bool isNewAccount = false}) {
  final kyc = str(user?['KYCStatus'], 'pending');
  if (kyc == 'approved') {
    if (isNewAccount) return AuthDestination.referral;
    return boolOf(user?['hasSeenIntroduction']) ? AuthDestination.home : AuthDestination.intro;
  }
  if (kyc == 'rejected') return AuthDestination.waiting;
  final hasBasicInfo = ['name', 'address', 'city', 'state', 'pincode'].every((k) => str(user?[k]).trim().isNotEmpty);
  return hasBasicInfo ? AuthDestination.waiting : AuthDestination.profileInfo;
}

/// Language / specialization entries arrive as strings or `{code|key, name}`.
List<String> codesOf(dynamic v, String key) => list(v).map((e) => e is Map ? str(e[key] ?? e['code'] ?? e['key']) : str(e)).where((e) => e.isNotEmpty).toList();
