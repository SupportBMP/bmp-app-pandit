import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api.dart';
import '../../core/api/api_client.dart';
import '../../core/i18n/i18n.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/json.dart';
import '../../core/widgets/toast.dart';
import '../../core/widgets/ui.dart';

/// True when the Pandit has an active subscription or trial; otherwise shows
/// the "Subscription required" sheet with trial / subscribe options
/// (checkSubscriptionAndShowModal + SubscriptionRequiredModal.js).
Future<bool> ensureSubscription(BuildContext context) async {
  try {
    final r = obj(await Api.getSubscription());
    final sub = obj(r['subscription']);
    final trial = obj(r['trial']);
    final active = ['ACTIVE', 'COMPLETED'].contains(str(sub['status']));
    if (active || boolOf(trial['isActive'])) return true;
  } catch (_) {}
  if (context.mounted) await _showRequired(context);
  return false;
}

Future<void> _showRequired(BuildContext context) =>
    showAppSheet<void>(context, title: t('subscription_required', 'Subscription required'), builder: (ctx) => const _SubscriptionRequired());

class _SubscriptionRequired extends StatefulWidget {
  const _SubscriptionRequired();

  @override
  State<_SubscriptionRequired> createState() => _SubscriptionRequiredState();
}

class _SubscriptionRequiredState extends State<_SubscriptionRequired> {
  bool _eligible = false;
  int _days = 15;
  bool _activating = false;

  @override
  void initState() {
    super.initState();
    Api.checkTrialEligibility().then((v) => mounted ? setState(() => _eligible = boolOf(obj(v)['eligible'])) : null).catchError((_) => null);
    Api.getTrialSettings().then((v) => mounted ? setState(() => _days = intOf(obj(v)['defaultTrialDays'], 15)) : null).catchError((_) => null);
  }

  Future<void> _activate() async {
    setState(() => _activating = true);
    try {
      await Api.activateTrial();
      Toast.success(t('trial_activated', 'Trial period activated successfully!'));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      Toast.error(apiError(e, t('trial_activation_failed', 'Failed to activate trial')));
    } finally {
      if (mounted) setState(() => _activating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final features = [
      (LucideIcons.calendar, t('unlimited_pooja_bookings', 'Unlimited Pooja Bookings')),
      (LucideIcons.video, t('unlimited_epooja_events', 'Unlimited ePooja Events')),
      (LucideIcons.users, t('unlimited_clients', 'Unlimited Clients')),
      (LucideIcons.headphones, t('priority_support', 'Priority Support')),
    ];
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          t('subscription_required_message', 'Subscribe to unlock all features and grow your practice.'),
          style: AppText.body(size: 15, color: AppColors.mutedForeground, height: 1.4),
        ),
        const SizedBox(height: 16),
        Text(t('premium_features', 'Premium features:'), style: AppText.body(size: 14, weight: FontWeight.w700)),
        const SizedBox(height: 8),
        for (final (i, l) in features)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.bluntRed.withValues(alpha: .08), borderRadius: BorderRadius.circular(10)),
                  child: Icon(i, size: 16, color: AppColors.bluntRed),
                ),
                const SizedBox(width: 12),
                Text(l, style: AppText.body(size: 15, weight: FontWeight.w500)),
              ],
            ),
          ),
        if (_eligible) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.amber50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.amber100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🎁 ${t('free_trial', 'Free Trial')}',
                  style: AppText.body(size: 15, weight: FontWeight.w700, color: AppColors.amber800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${t('trial_description', 'Try all premium features free')} - $_days ${t('days', 'days')}',
                  style: AppText.body(size: 13, color: AppColors.amber800),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: '${t('activate_trial', 'Activate Free Trial')} ($_days ${t('days', 'days')})',
            loading: _activating,
            kind: BtnKind.success,
            onPressed: _activate,
          ),
        ],
        const SizedBox(height: 12),
        AppButton(
          label: t('subscribe_now', 'Subscribe Now'),
          icon: LucideIcons.crown,
          onPressed: () {
            Navigator.pop(context);
            context.push(R.subscription);
          },
        ),
      ],
    );
  }
}
