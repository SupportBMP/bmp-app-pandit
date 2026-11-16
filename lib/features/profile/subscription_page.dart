import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../core/api/api.dart';
import '../../core/api/api_client.dart';
import '../../core/config/env.dart';
import '../../core/i18n/i18n.dart';
import '../../core/state/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/json.dart';
import '../../core/widgets/toast.dart';
import '../../core/widgets/ui.dart';

/// Current subscription / trial and the plan catalogue with Razorpay
/// recurring checkout (Subscription-Status.js + SubscriptionActive /
/// TrialActive in ProfileTab.js).
class SubscriptionPage extends ConsumerStatefulWidget {
  const SubscriptionPage({super.key});

  @override
  ConsumerState<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends ConsumerState<SubscriptionPage> {
  final _rzp = Razorpay();
  Json? _sub;
  Json? _trial;
  List<Json> _plans = [];
  bool _eligible = false;
  int _trialDays = 15;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _rzp.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse _) {
      Toast.success(t('wait_for_activation', 'Payment received. Your plan activates within 5 minutes.'));
      _load();
    });
    _rzp.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
      if (r.code == Razorpay.PAYMENT_CANCELLED) return;
      Toast.error('${t('payment_failed', 'Payment failed')}: ${r.message ?? t('something_went_wrong', 'Something went wrong')}');
    });
    _load();
  }

  @override
  void dispose() {
    _rzp.clear();
    super.dispose();
  }

  Future<void> _load() async {
    await Future.wait<void>([
      Api.getSubscription()
          .then((v) {
            final r = obj(v);
            final s = obj(r['subscription']);
            final st = str(s['status']);
            final showSub = s.isNotEmpty && (['ACTIVE', 'COMPLETED', 'PENDING'].contains(st) || (st == 'CANCELLED' && boolOf(s['cancelAtCycleEnd'])));
            _sub = showSub ? s : null;
            _trial = !showSub && boolOf(pick(r, ['trial', 'isActive'])) ? obj(r['trial']) : null;
          })
          .catchError((_) {}),
      Api.fetchPlans().then((v) => _plans = v is List ? objList(v) : objList(obj(v)['plans'] ?? obj(v)['data'])).catchError((_) => _plans),
      Api.checkTrialEligibility().then((v) => _eligible = boolOf(obj(v)['eligible'])).catchError((_) => false),
      Api.getTrialSettings().then((v) => _trialDays = intOf(obj(v)['defaultTrialDays'], 15)).catchError((_) => 15),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _subscribe(Json plan) async {
    if (_trial != null) {
      final ok = await confirmDialog(
        context,
        title: t('trial_active_title', 'Trial is active'),
        message: t('trial_active_subscribe_warning', 'Subscribing now will end your free trial. Continue?'),
        confirm: t('subscribe_now', 'Subscribe now'),
      );
      if (!ok) return;
    }
    setState(() => _busy = true);
    try {
      final r = obj(await Api.createSubscription({'planId': plan['planId']}));
      final id = str(r['subscriptionId']);
      if (id.isEmpty) return;
      final user = ref.read(sessionProvider);
      _rzp.open({
        'key': Env.razorpayKeyId,
        'name': 'BookMyPooja',
        'description': str(plan['name']),
        'subscription_id': id,
        'recurring': true,
        'prefill': {'email': str(user?['email'], 'noemail@gmail.com'), 'contact': str(user?['phone'])},
        'theme': {'color': '#8A1C23'},
      });
    } catch (e) {
      Toast.error(apiError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _activateTrial() async {
    setState(() => _busy = true);
    try {
      await Api.activateTrial();
      Toast.success(t('trial_activated', 'Trial period activated successfully!'));
      await _load();
    } catch (e) {
      Toast.error(apiError(e, t('trial_activation_failed', 'Failed to activate trial')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final ok = await confirmDialog(
      context,
      title: t('cancel_subscription', 'Cancel subscription'),
      message: t(
        'cancel_subscription_message',
        'Your subscription will remain active until the end of the current billing cycle. After that, you will lose access to premium features.',
      ),
      confirm: t('confirm_cancel', 'Confirm cancel'),
      destructive: true,
    );
    if (!ok) return;
    try {
      await Api.cancelSubscription();
      Toast.success(t('subscription_cancelled', 'Subscription cancelled. You will not be billed next cycle.'));
    } catch (e) {
      final m = apiError(e, '');
      if (m.contains('already cancelled') || m.contains('already scheduled')) {
        Toast.show(t('already_cancelled_message', 'Your subscription is already scheduled for cancellation.'));
      } else {
        Toast.error(m.isEmpty ? t('cancel_failed', 'Failed to cancel subscription') : m);
      }
    }
    _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: pageBg,
    appBar: appBar(context, t('subscription_status', 'Subscription')),
    body: _loading
        ? const AppLoader()
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_sub != null) SubscriptionSummary(sub: _sub!, onCancel: _cancel, full: true),
                if (_trial != null) TrialSummary(trial: _trial!, full: true),
                if (_sub == null) ...[
                  if (_sub == null && _trial == null && _eligible) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.amber50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.amber100),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '🎁 ${t('free_trial', 'Free Trial')}',
                            style: AppText.body(size: 17, weight: FontWeight.w700, color: AppColors.amber800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${t('trial_description', 'Try all premium features free')} - $_trialDays ${t('days', 'days')}',
                            style: AppText.body(size: 14, color: AppColors.amber800),
                          ),
                          const SizedBox(height: 12),
                          AppButton(
                            label: '${t('activate_trial', 'Activate free trial')} ($_trialDays ${t('days', 'days')})',
                            kind: BtnKind.success,
                            loading: _busy,
                            onPressed: _activateTrial,
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SectionTitle(t('choose_your_plan', 'Choose your plan'), icon: LucideIcons.crown),
                  const SizedBox(height: 12),
                  if (_plans.isEmpty) EmptyState(compact: true, icon: LucideIcons.crown, title: t('no_plans_available', 'No plans available at the moment')),
                  for (final p in _plans) _planCard(p),
                ],
              ],
            ),
          ),
  );

  Widget _planCard(Json p) {
    final yearly = str(p['period']) == 'yearly';
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      borderColor: yearly ? AppColors.bluntRed : AppColors.border,
      onTap: _busy ? null : () => _subscribe(p),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(str(p['name'], capitalize(str(p['period']))), style: AppText.body(size: 17, weight: FontWeight.w700)),
                    if (yearly) ...[const SizedBox(width: 8), const StatusBadge('active', label: 'Best value')],
                  ],
                ),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '₹${NumberFormat.decimalPattern('en_IN').format(numOf(p['amount']))}',
                        style: AppText.heading(size: 26, color: AppColors.bluntRed),
                      ),
                      TextSpan(
                        text: ' / ${yearly ? t('year', 'year') : t('month', 'month')}',
                        style: AppText.body(size: 14, color: AppColors.mutedForeground),
                      ),
                    ],
                  ),
                ),
                if (yearly) Text(t('save_more_with_yearly', 'Save more with the yearly plan'), style: AppText.body(size: 12, color: AppColors.green700)),
              ],
            ),
          ),
          AppButton(label: t('subscribe', 'Subscribe'), compact: true, expand: false, loading: _busy, onPressed: () => _subscribe(p)),
        ],
      ),
    );
  }
}

String capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Active / cancelling subscription card.
class SubscriptionSummary extends StatelessWidget {
  const SubscriptionSummary({super.key, required this.sub, this.onCancel, this.full = false});
  final Json sub;
  final VoidCallback? onCancel;
  final bool full;

  @override
  Widget build(BuildContext context) {
    final st = str(sub['status']).toUpperCase();
    final scheduled = boolOf(sub['cancelAtCycleEnd']);
    final completed = st == 'COMPLETED';
    final plan = obj(sub['plan']);
    final (label, color) = scheduled && st == 'ACTIVE'
        ? (t('active_cancelling', 'Active (cancelling)'), AppColors.orange600)
        : st == 'PENDING'
        ? ('Pending', AppColors.amber600)
        : st == 'CANCELLED'
        ? (t('cancelled'), AppColors.orange600)
        : (t('active'), AppColors.green600);
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.crown, color: AppColors.amber600),
              const SizedBox(width: 10),
              Expanded(
                child: Text(str(plan['name'], 'Premium Plan'), style: AppText.body(size: 17, weight: FontWeight.w700)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(999)),
                child: Text(
                  label,
                  style: AppText.body(size: 12, weight: FontWeight.w700, color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          InfoRow(icon: LucideIcons.calendarCheck, text: '${t('valid_until', 'Valid until')}: ${_SubDates.d(sub['current_end'])}'),
          InfoRow(icon: LucideIcons.indianRupee, text: '${t('amount', 'Amount')}: ₹${str(plan['amount'], '99')} / ${str(plan['period'], 'monthly')}'),
          if (full) ...[
            InfoRow(icon: LucideIcons.play, text: '${t('started', 'Started')}: ${_SubDates.d(sub['current_start'])}'),
            if (!completed && !scheduled) InfoRow(icon: LucideIcons.repeat, text: '${t('next_payment', 'Next payment')}: ${_SubDates.d(sub['current_end'])}'),
          ],
          if (scheduled) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.orange50, borderRadius: BorderRadius.circular(10)),
              child: Text(
                'Cancellation scheduled — your plan remains active until ${_SubDates.d(sub['current_end'])}. No further billing will occur.',
                style: AppText.body(size: 12, color: AppColors.orange600),
              ),
            ),
          ],
          if (full && onCancel != null && st == 'ACTIVE' && !scheduled) ...[
            const SizedBox(height: 12),
            AppButton(label: t('cancel_subscription', 'Cancel subscription'), kind: BtnKind.outline, compact: true, onPressed: onCancel),
          ],
        ],
      ),
    );
  }
}

class TrialSummary extends StatelessWidget {
  const TrialSummary({super.key, required this.trial, this.full = false});
  final Json trial;
  final bool full;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.green50,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.green100),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.gift, color: AppColors.green700),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                t('trial_period_active', 'Trial period active'),
                style: AppText.body(size: 16, weight: FontWeight.w700, color: AppColors.green700),
              ),
            ),
            StatusBadge('active', label: '${str(trial['daysRemaining'], '0')} ${t('days', 'days')}'),
          ],
        ),
        const SizedBox(height: 8),
        Text('${t('trial_ends_on', 'Trial ends on')}: ${_SubDates.d(trial['endDate'])}', style: AppText.body(size: 13, color: AppColors.green700)),
        if (full) ...[
          Text(
            '${t('started', 'Started')}: ${_SubDates.d(trial['startDate'])} · ${t('trial_duration', 'Duration')}: ${str(trial['days'], '0')} ${t('days', 'days')}',
            style: AppText.body(size: 13, color: AppColors.green700),
          ),
          const SizedBox(height: 8),
          Text(
            t('subscribe_for_uninterrupted', 'Subscribe to continue uninterrupted after your trial.'),
            style: AppText.body(size: 13, color: AppColors.foreground),
          ),
        ],
      ],
    ),
  );
}

class _SubDates {
  static String d(dynamic v) {
    final x = DateTime.tryParse(str(v))?.toLocal();
    return x == null ? 'N/A' : DateFormat('d MMMM yyyy').format(x);
  }
}
