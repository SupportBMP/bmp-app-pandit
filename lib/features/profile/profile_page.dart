import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api.dart';
import '../../core/config/env.dart';
import '../../core/i18n/i18n.dart';
import '../../core/router/routes.dart';
import '../../core/state/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/json.dart';
import '../../core/widgets/toast.dart';
import '../../core/widgets/ui.dart';
import '../auth/language_page.dart';
import 'subscription_page.dart';

/// Pandit profile (ProfileTab.js): identity + KYC, stats, referral, QR for
/// devotees, completion nudge, subscription, specializations, languages and
/// settings.
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  Json _summary = {};
  Json _rewards = {};
  Json? _sub;
  Json? _trial;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await Future.wait<void>([
      Api.getProfile(I18n.code)
          .then((v) {
            final u = obj(v)['data'];
            if (u is Map) ref.read(sessionProvider.notifier).setUser(obj(u));
          })
          .catchError((_) {}),
      Api.getProfileSummary().then((v) => _summary = obj(obj(v)['data'])).catchError((_) => _summary),
      Api.getRewardsSummary().then((v) => _rewards = obj(v)).catchError((_) => _rewards),
      Api.getSubscription()
          .then((v) {
            final r = obj(v);
            final s = obj(r['subscription']);
            final st = str(s['status']);
            final show = s.isNotEmpty && (['ACTIVE', 'COMPLETED', 'PENDING'].contains(st) || (st == 'CANCELLED' && boolOf(s['cancelAtCycleEnd'])));
            _sub = show ? s : null;
            _trial = !show && boolOf(pick(r, ['trial', 'isActive'])) ? obj(r['trial']) : null;
          })
          .catchError((_) {}),
    ]);
    if (mounted) setState(() {});
  }

  Future<void> _shareReferral(String code) => SharePlus.instance.share(
    ShareParams(
      title: 'Referral: BookMyPooja',
      text:
          "Namaste Pandit Ji\nUse my referral code ${code.isEmpty ? '—' : code} and start using India's one and only app for pandits. "
          'Special rewards to be won.\n\nDownload: ${Env.appDownloadUrl}',
    ),
  );

  Future<void> _logout() async {
    final ok = await confirmDialog(context, title: t('logout'), message: t('logout_confirm', 'Do you want to log out?'), confirm: t('logout'));
    if (!ok) return;
    await ref.read(sessionProvider.notifier).signOut();
    if (mounted) context.go(R.login);
  }

  @override
  Widget build(BuildContext context) {
    final u = ref.watch(sessionProvider) ?? {};
    final kyc = str(u['KYCStatus'], 'pending');
    final completion = intOf(u['profileCompletion'], 100);
    final city = [str(u['city']), str(u['state'])].where((e) => e.isNotEmpty).join(', ');
    final specs = list(u['specializations']).map((s) => s is Map ? str(s['lang'] ?? s['name'] ?? s['key']) : str(s)).where((e) => e.isNotEmpty).toList();
    final langs = list(u['languages']).map((s) => s is Map ? str(s['name'] ?? s['code']) : str(s)).where((e) => e.isNotEmpty).toList();

    return Scaffold(
      backgroundColor: pageBg,
      body: RefreshIndicator(
        color: AppColors.bluntRed,
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Header
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF9A1F27), AppColors.maroonDark]),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: Avatar(url: str(u['photoUrl']), name: str(u['name']), size: 72),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${t('pandit')} ${str(u['name'])}', maxLines: 2, style: AppText.heading(size: 21, color: Colors.white)),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [_kycChip(kyc), _whiteChip(LucideIcons.star, str(_summary['averageRating'], '0.0'))],
                                ),
                                if (city.isNotEmpty || str(u['experience']).isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    [
                                      if (city.isNotEmpty) city,
                                      if (str(u['experience']).isNotEmpty) '${str(u['experience'])} ${t('years_experience')}',
                                    ].join(' · '),
                                    style: AppText.body(size: 13, color: Colors.white.withValues(alpha: .85)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: t('add_clients'),
                            onPressed: () => _showQr(context, str(u['userId'] ?? u['_id']), str(u['name'])),
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                              child: const Icon(LucideIcons.qrCode, color: AppColors.bluntRed, size: 22),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _stat(str(_summary['totalServices'], '0'), t('total_services')),
                          _stat(str(pick(_rewards, ['totals', 'awarded']), '0'), t('blessing_points')),
                          _stat('${str(_summary['satisfactionRate'], '0')}%', t('satisfaction_rate')),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.gift, color: Colors.white, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(t('referral_code'), style: AppText.body(size: 11, color: Colors.white70)),
                                  GestureDetector(
                                    onLongPress: () {
                                      Clipboard.setData(ClipboardData(text: str(u['referralCode'])));
                                      Toast.success(t('copied', 'Copied'));
                                    },
                                    child: Text(
                                      str(u['referralCode'], '—'),
                                      style: AppText.body(size: 16, weight: FontWeight.w800, color: Colors.white, letterSpacing: 1.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton.icon(
                              onPressed: () => _shareReferral(str(u['referralCode'])),
                              style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.bluntRed),
                              icon: const Icon(LucideIcons.share2, size: 16),
                              label: Text(t('share')),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppButton(
                        label: t('edit_profile'),
                        icon: LucideIcons.squarePen,
                        kind: BtnKind.outline,
                        onPressed: () async {
                          await context.push(R.editProfile);
                          _load();
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (completion < 100) ...[_incomplete(completion), const SizedBox(height: 12)],
                  if (_sub != null) SubscriptionSummary(sub: _sub!) else if (_trial != null) TrialSummary(trial: _trial!),
                  AppCard(
                    onTap: () async {
                      await context.push(R.subscription);
                      _load();
                    },
                    child: Row(
                      children: [
                        const IconPill(icon: LucideIcons.crown, color: AppColors.amber600),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _sub != null ? t('manage_subscription', 'Manage subscription') : t('view_plans', 'View plans'),
                                style: AppText.body(size: 15, weight: FontWeight.w700),
                              ),
                              Text(
                                _sub != null
                                    ? t('subscription_details', 'Plan details & billing')
                                    : t('unlock_premium', 'Unlock unlimited bookings, e-pujas and devotees'),
                                style: AppText.body(size: 12, color: AppColors.mutedForeground),
                              ),
                            ],
                          ),
                        ),
                        const Icon(LucideIcons.chevronRight, color: AppColors.gray400),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (specs.isNotEmpty) _chips(t('specializations'), LucideIcons.sparkles, specs),
                  if (langs.isNotEmpty) ...[const SizedBox(height: 12), _chips(t('languages'), LucideIcons.languages, langs)],
                  const SizedBox(height: 12),
                  AppCard(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: [
                        _setting(
                          LucideIcons.globe,
                          t('language', 'Language'),
                          trailing: appLanguages.firstWhere((l) => l.code == I18n.code, orElse: () => appLanguages.first).native,
                          onTap: () => showLanguageSheet(context),
                        ),
                        _setting(
                          LucideIcons.headset,
                          t('help_support', 'Help & support'),
                          onTap: () => launchUrl(Uri.parse('https://bookmypoojaonline.com/contact-us'), mode: LaunchMode.externalApplication),
                        ),
                        _setting(LucideIcons.shieldCheck, t('privacy_policy', 'Privacy policy'), onTap: () => context.push(R.legal)),
                        _setting(LucideIcons.logOut, t('logout'), danger: true, onTap: _logout),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text('BookMyPooja Partner · v2.0.0', style: AppText.body(size: 12, color: AppColors.gray400)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kycChip(String kyc) {
    final (label, bg) = switch (kyc) {
      'approved' => (t('kyc_approved'), AppColors.green600),
      'rejected' => (t('kyc_rejected'), AppColors.red600),
      _ => (t('kyc_pending'), AppColors.amber600),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.badgeCheck, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppText.body(size: 11.5, weight: FontWeight.w700, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _whiteChip(IconData i, String v) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .15), borderRadius: BorderRadius.circular(999)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(i, size: 13, color: AppColors.amber400),
        const SizedBox(width: 4),
        Text(
          v,
          style: AppText.body(size: 12, weight: FontWeight.w700, color: Colors.white),
        ),
      ],
    ),
  );

  Widget _stat(String v, String l) => Expanded(
    child: Column(
      children: [
        Text(
          v,
          style: AppText.body(size: 20, weight: FontWeight.w800, color: Colors.white),
        ),
        Text(
          l,
          textAlign: TextAlign.center,
          style: AppText.body(size: 11.5, color: Colors.white70),
        ),
      ],
    ),
  );

  Widget _incomplete(int pct) => AppCard(
    color: AppColors.amber50,
    borderColor: AppColors.amber100,
    onTap: () => context.push(R.editProfile),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.circleAlert, color: AppColors.amber700),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                t('profile_incomplete'),
                style: AppText.body(size: 15, weight: FontWeight.w700, color: AppColors.amber800),
              ),
            ),
            Text(
              '$pct%',
              style: AppText.body(size: 15, weight: FontWeight.w800, color: AppColors.amber800),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(t('please_upload_required_documents_to_activate_your_profile'), style: AppText.body(size: 13, color: AppColors.amber800)),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: pct / 100, minHeight: 8, backgroundColor: Colors.white, color: AppColors.amber500),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${t('complete_now')} →',
            style: AppText.body(size: 14, weight: FontWeight.w700, color: AppColors.bluntRed),
          ),
        ),
      ],
    ),
  );

  Widget _chips(String title, IconData icon, List<String> items) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(title, icon: icon),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in items)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.creamDark),
                ),
                child: Text(s, style: AppText.body(size: 13, weight: FontWeight.w600)),
              ),
          ],
        ),
      ],
    ),
  );

  Widget _setting(IconData icon, String label, {String? trailing, bool danger = false, required VoidCallback onTap}) => ListTile(
    onTap: onTap,
    leading: Icon(icon, size: 20, color: danger ? AppColors.red600 : AppColors.bluntRed),
    title: Text(
      label,
      style: AppText.body(size: 15, weight: FontWeight.w600, color: danger ? AppColors.red600 : AppColors.foreground),
    ),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (trailing != null) Text(trailing, style: AppText.body(size: 13, color: AppColors.mutedForeground)),
        if (!danger) const Icon(LucideIcons.chevronRight, size: 18, color: AppColors.gray400),
      ],
    ),
  );
}

/// "Add clients" QR (QRCodeModal.js): devotees scan to join this Pandit's list.
Future<void> _showQr(BuildContext context, String userId, String name) {
  final url = '${Env.webBaseUrl}/register-devotee?userId=$userId';
  return showAppSheet<void>(
    context,
    title: t('add_clients'),
    builder: (_) => ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          t('share_qr_with_clients'),
          textAlign: TextAlign.center,
          style: AppText.body(size: 14, color: AppColors.mutedForeground),
        ),
        const SizedBox(height: 16),
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: QrImageView(
              data: url,
              size: 220,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.maroonDark),
              dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: AppColors.maroonDark),
              embeddedImage: const AssetImage('assets/brand/emblem.png'),
              embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(44, 44)),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('${t('how_it_works')}:', style: AppText.body(size: 15, weight: FontWeight.w700)),
        for (final (i, k) in [(1, 'qr_step_1'), (2, 'qr_step_2'), (3, 'qr_step_3')])
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AppColors.bluntRed,
                  child: Text(
                    '$i',
                    style: AppText.body(size: 12, weight: FontWeight.w700, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(t(k), style: AppText.body(size: 14, height: 1.4))),
              ],
            ),
          ),
        const SizedBox(height: 20),
        AppButton(
          label: t('share'),
          icon: LucideIcons.share2,
          onPressed: () => SharePlus.instance.share(
            ShareParams(
              title: t('join_as_client'),
              text: "${t('add_yourself_to')} $name's ${t('devotee_list')}!\n\n${t('scan_qr_or_visit')}:\n$url\n\n${t('powered_by_bookmypooja')}",
            ),
          ),
        ),
      ],
    ),
  );
}
