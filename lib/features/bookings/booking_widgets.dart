import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api.dart';
import '../../core/api/api_client.dart';
import '../../core/config/env.dart';
import '../../core/i18n/i18n.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/json.dart';
import '../../core/widgets/toast.dart';
import '../../core/widgets/ui.dart';

// ── Time helpers (Card.js checkPoojaStatus + display rules) ───────────────

DateTime? _utc(dynamic v) => DateTime.tryParse(str(v))?.toLocal();

/// Start of the first slot in local time.
DateTime? bookingStart(Json d) {
  final tz = objList(d['datesWithTimezone']);
  if (tz.isNotEmpty && str(tz.first['startDateTime']).isNotEmpty) return _utc(tz.first['startDateTime']);
  if (d['startDateTime'] != null) return _utc(d['startDateTime']);
  final dates = list(d['dates']);
  final st = str(d['startTime']);
  if (dates.isNotEmpty && st.contains(':')) {
    final day = DateTime.tryParse(str(dates.first));
    if (day != null) return DateTime.tryParse('${DateFormat('yyyy-MM-dd').format(day.toUtc())}T$st:00Z')?.toLocal();
  }
  return dates.isNotEmpty ? DateTime.tryParse(str(dates.first))?.toLocal() : null;
}

String bookingDateLabel(Json d) {
  final tz = objList(d['datesWithTimezone']);
  if (tz.isNotEmpty && str(tz.first['dateInUserTZ']).isNotEmpty) {
    final x = DateTime.tryParse(str(tz.first['dateInUserTZ']));
    if (x != null) return DateFormat('dd/MM/yyyy').format(x);
  }
  final s = bookingStart(d);
  return s == null ? '—' : DateFormat('dd/MM/yyyy').format(s);
}

String bookingTimeLabel(Json d) {
  if (str(d['startTimeLocal']).isNotEmpty) return str(d['startTimeLocal']);
  if (d['startDateTime'] != null || list(d['dates']).isNotEmpty) {
    final s = bookingStart(d);
    if (s != null && str(d['startTime']).contains(':')) return DateFormat('h:mm a').format(s);
    if (s != null && d['startDateTime'] != null) return DateFormat('h:mm a').format(s);
  }
  return str(d['startTime'], '—');
}

/// (isNow, isOver) for a booking at [now].
(bool, bool) bookingTiming(Json d, DateTime now) {
  bool within(DateTime? s, DateTime? e) => s != null && e != null && !now.isBefore(s) && !now.isAfter(e);
  if (d['startDateTime'] != null && d['endDateTime'] != null) {
    final s = _utc(d['startDateTime']), e = _utc(d['endDateTime']);
    return (within(s, e), e != null && now.isAfter(e));
  }
  final tz = objList(d['datesWithTimezone']);
  if (tz.isNotEmpty) {
    final sorted = [...tz]..sort((a, b) => str(a['startDateTime']).compareTo(str(b['startDateTime'])));
    final today = sorted.where((x) {
      final s = _utc(x['startDateTime']);
      return s != null && s.year == now.year && s.month == now.month && s.day == now.day;
    }).firstOrNull;
    final isNow = today != null && within(_utc(today['startDateTime']), _utc(today['endDateTime']));
    final lastEnd = _utc(sorted.last['endDateTime']);
    return (isNow, lastEnd != null && now.isAfter(lastEnd));
  }
  final todayKey = DateFormat('yyyy-MM-dd').format(now);
  final days = list(d['dates']).map((e) => DateTime.tryParse(str(e))).whereType<DateTime>().map((e) => DateFormat('yyyy-MM-dd').format(e)).toList()..sort();
  DateTime? at(String day, dynamic hm) => str(hm).contains(':') ? DateTime.tryParse('$day ${str(hm)}') : null;
  var isNow = false, isOver = false;
  if (days.contains(todayKey)) isNow = within(at(todayKey, d['startTime']), at(todayKey, d['endTime']));
  if (days.isNotEmpty) {
    final last = days.last;
    if (todayKey.compareTo(last) > 0) {
      isOver = true;
    } else if (todayKey == last) {
      final e = at(last, d['endTime']);
      isOver = e != null && now.isAfter(e);
    }
  }
  return (isNow, isOver);
}

// ── Actions ───────────────────────────────────────────────────────────────

Future<void> callPhone(String? phone) async {
  if (phone == null || phone.isEmpty) return Toast.error(t('no_phone_number', 'No phone number'));
  if (!await launchUrl(Uri.parse('tel:$phone'))) Toast.error(t('unable_to_open_dialer', 'Unable to open dialer'));
}

Future<void> openWhatsApp(String? phone) async {
  if (phone == null || phone.isEmpty) return Toast.error(t('no_phone_number', 'No phone number'));
  final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
  final ok = await launchUrl(Uri.parse('https://wa.me/$digits'), mode: LaunchMode.externalApplication);
  if (!ok) Toast.error(t('whatsapp_not_installed', 'WhatsApp not installed. Please install WhatsApp to send a message'));
}

Future<void> shareInvite(Json d) async {
  final url = '${Env.webBaseUrl}/interactive?channel=${Uri.encodeComponent(str(d['channelId']))}';
  final title = str(d['poojaTitle'], 'Puja');
  await SharePlus.instance.share(
    ShareParams(title: 'Invitation for $title', text: 'Namaste! You are invited for $title on ${bookingDateLabel(d)} at ${bookingTimeLabel(d)}\n\n$url'),
  );
}

void liveComingSoon() => Toast.show(t('live_coming_soon', 'Live streaming will be available in an upcoming update.'));

// ── Booking card (Card.js + BookingButton.js) ────────────────────────────

class BookingCard extends StatefulWidget {
  const BookingCard({super.key, required this.data, required this.now, required this.onChanged, required this.onEdit});
  final Json data;
  final DateTime now;
  final VoidCallback onChanged;
  final ValueChanged<Json> onEdit;

  @override
  State<BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends State<BookingCard> {
  bool _generate = false; // "Payment received? No" → show Generate link
  String _paymentLink = '';
  bool _busy = false;

  Json get d => widget.data;
  String get status => str(d['status']).toUpperCase();
  Json get customer => objList(d['customerDetails']).firstOrNull ?? {};

  Future<void> _update(String action) async {
    setState(() => _busy = true);
    try {
      await Api.updatePoojaStatus(str(d['_id']), {'action': action});
      Toast.success(t('status_updated', 'Status updated'));
      widget.onChanged();
    } catch (e) {
      Toast.error(apiError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _generateLink() async {
    setState(() => _busy = true);
    try {
      final r = obj(await Api.getPaymentLink(str(d['_id']), 'this is payment'));
      setState(() => _paymentLink = str(r['paymentLink']));
      Toast.success(t('link_generated', 'Link generated!'));
    } catch (e) {
      Toast.error(apiError(e, 'Failed to generate payment link'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _webDetails() async {
    try {
      final r = obj(await Api.fetchWebBookingById(str(d['bookingId'])));
      if (mounted) showWebBookingDetails(context, obj(r['data']));
    } catch (_) {
      Toast.error(t('failed_fetch_booking', 'Failed to fetch booking details'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final (isNow, isOver) = bookingTiming(d, widget.now);
    final external = str(d['from']) == 'external';
    final online = str(d['poojaType']) == 'online';
    final editable = status == 'CONFIRMED' && !isNow && !isOver;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => context.push(R.poojaDetails, extra: {'poojaId': str(d['_id']), 'poojaType': str(d['poojaType'])}),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(str(d['poojaTitle']), style: AppText.body(size: 17, weight: FontWeight.w700)),
                    if (external) ...[
                      const SizedBox(height: 4),
                      _tag('BookMyPooja', Colors.white, boolOf(d['bookedDirectly']) ? AppColors.saffronDark : AppColors.bluntRed),
                    ],
                  ],
                ),
              ),
              StatusBadge(status.toLowerCase(), label: status),
              if (editable)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: IconPill(icon: LucideIcons.pencil, size: 34, onTap: () => widget.onEdit(d), tooltip: t('edit_pooja')),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (customer.isNotEmpty) ...[
            InfoRow(icon: LucideIcons.users, text: str(customer['familyName'])),
            if (str(customer['phone']).isNotEmpty) InfoRow(icon: LucideIcons.smartphone, text: str(customer['phone'])),
          ],
          Row(
            children: [
              Expanded(
                child: InfoRow(icon: LucideIcons.calendar, text: bookingDateLabel(d)),
              ),
              Expanded(
                child: InfoRow(icon: LucideIcons.clock, text: bookingTimeLabel(d)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _tag(
                online ? t('online', 'Online') : t('onsite', 'Onsite'),
                online ? AppColors.amber800 : AppColors.green700,
                online ? AppColors.amber50 : AppColors.green50,
              ),
              _tag(
                status == 'PAID' ? t('payment_complete') : t('payment_pending'),
                status == 'PAID' ? AppColors.green700 : AppColors.red700,
                status == 'PAID' ? AppColors.green50 : AppColors.red50,
              ),
            ],
          ),
          if (status == 'COMPLETED' && !_generate && !external) _question('${t('payment_received')}?'),
          if (isOver && status == 'CONFIRMED') _question('${t('pooja_completed')}?'),
          if (!(status == 'COMPLETED' && external)) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _actions(isNow, isOver, external, online)),
                const SizedBox(width: 8),
                IconPill(icon: LucideIcons.phone, onTap: () => callPhone(str(customer['phone']))),
                const SizedBox(width: 8),
                IconPill(icon: LucideIcons.messageCircle, color: AppColors.whatsapp, onTap: () => openWhatsApp(str(customer['phone']))),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _question(String q) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Text(
      q,
      style: AppText.body(size: 14, weight: FontWeight.w700, color: AppColors.bluntRed),
    ),
  );

  Widget _yesNo(VoidCallback no, VoidCallback yes, {String? noLabel, String? yesLabel}) => Row(
    children: [
      Expanded(
        child: AppButton(label: noLabel ?? t('no'), kind: BtnKind.outline, compact: true, icon: LucideIcons.x, onPressed: _busy ? null : no),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: AppButton(label: yesLabel ?? t('yes'), compact: true, icon: LucideIcons.check, loading: _busy, onPressed: yes),
      ),
    ],
  );

  Widget _actions(bool isNow, bool isOver, bool external, bool online) {
    if (_generate) {
      return _paymentLink.isEmpty
          ? AppButton(label: t('generate_payment'), compact: true, icon: LucideIcons.link, loading: _busy, onPressed: _generateLink)
          : AppButton(
              label: t('copy_link'),
              compact: true,
              kind: BtnKind.outline,
              icon: LucideIcons.copy,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _paymentLink));
                Toast.success(t('link_copied', 'Link copied to clipboard'));
              },
            );
    }
    if (status == 'PAID') return AppButton(label: t('payment_done'), compact: true, kind: BtnKind.success, icon: LucideIcons.check, onPressed: null);
    if (status == 'COMPLETED') return _yesNo(() => setState(() => _generate = true), () => _update('PAID'));
    if (status == 'CANCELLED') return AppButton(label: t('cancelled'), compact: true, kind: BtnKind.outline, onPressed: null);
    if (isNow && status == 'CONFIRMED' && online) {
      return Row(
        children: [
          Expanded(
            child: AppButton(label: t('join_puja'), compact: true, icon: LucideIcons.video, onPressed: liveComingSoon),
          ),
          const SizedBox(width: 8),
          IconPill(icon: LucideIcons.share2, onTap: () => shareInvite(d)),
        ],
      );
    }
    if (isOver && status == 'CONFIRMED') return _yesNo(() => _update('UNFINISHED'), () => _update('COMPLETE'));
    if (status == 'PENDING' && !isNow && !isOver) {
      return _yesNo(() => _update('CANCEL'), () => _update('ACCEPT'), noLabel: t('decline'), yesLabel: t('accept'));
    }
    if (status == 'CONFIRMED') {
      if (external) return AppButton(label: t('viewDetails', 'View details'), compact: true, onPressed: _webDetails);
      return Row(
        children: [
          Expanded(child: AppButton(label: t('start'), compact: true, onPressed: null)),
          if (online) ...[const SizedBox(width: 8), IconPill(icon: LucideIcons.share2, onTap: () => shareInvite(d))],
        ],
      );
    }
    return const SizedBox.shrink();
  }
}

Widget _tag(String label, Color fg, Color bg) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
  child: Text(
    label,
    style: AppText.body(size: 12, weight: FontWeight.w700, color: fg),
  ),
);

// ── Web (BookMyPooja marketplace) bookings: BCard.js ─────────────────────

/// Strips the `Customer: <name>` fragment that auto-generated booking notes
/// carry, so an unassigned booking's notes never reveal the customer.
String redactCustomerNotes(Object? notes) => str(notes).replaceAll(RegExp(r'\s*Customer\s*:[^\n]*', caseSensitive: false), '').trim();

/// Flattens a `/api/web-booking-management` row the way BookingsTab.js did.
///
/// These rows are bookings the pandit can still claim (not yet assigned), so
/// customer PII is dropped here, before any widget sees it: `userDetails` is
/// removed and the customer's name is stripped from `notes`.
Json flattenWebBooking(Json b) {
  final bd = Map<String, dynamic>.of(obj(b['bookingDetails']))..remove('userDetails');
  return {
    ...bd,
    'notes': redactCustomerNotes(bd['notes']),
    '_id': b['_id'],
    'dates': [bd['date']],
    'startTime': bd['time'],
    'poojaType': 'onsite',
    'action': b['action'],
    'bookingId': b['bookingId'],
    'managementId': b['managementId'],
  };
}

class WebBookingCard extends StatelessWidget {
  const WebBookingCard({super.key, required this.data, required this.onChanged});
  final Json data;
  final VoidCallback onChanged;

  Future<void> _act(bool interested) async {
    try {
      await Api.updateWebBookingAction({'managementId': data['managementId'], 'interest': interested});
      Toast.success(interested ? t('booking_claimed', 'Booking claimed successfully') : t('booking_not_available', 'Booking marked as not available'));
      onChanged();
    } catch (e) {
      Toast.error(apiError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final eligible = str(data['action']) == 'ELIGIBLE';
    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.cream.withValues(alpha: .5),
      borderColor: AppColors.creamDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(str(data['poojaTitle']), style: AppText.body(size: 17, weight: FontWeight.w700)),
              ),
              _tag(t('bookmyPooja', 'BookMyPooja'), Colors.white, AppColors.bluntRed),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InfoRow(icon: LucideIcons.calendar, text: bookingDateLabel(data)),
              ),
              Expanded(
                child: InfoRow(icon: LucideIcons.clock, text: data['startDateTime'] != null ? bookingTimeLabel(data) : str(data['startTime'])),
              ),
            ],
          ),
          if (str(data['location']).isNotEmpty) InfoRow(icon: LucideIcons.mapPin, text: str(data['location'])),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(LucideIcons.lock, size: 13, color: AppColors.mutedForeground),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  t('customerDetailsWillBeVisibleAfterConfirmation', 'Customer details will be visible after confirmation'),
                  style: AppText.body(size: 12, color: AppColors.mutedForeground),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: t('viewDetails', 'View details'),
                  compact: true,
                  kind: BtnKind.outline,
                  onPressed: () => showWebBookingDetails(context, data, onAction: _act),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: eligible ? t('claimBooking', 'Claim booking') : t('interested', 'Interested'),
                  compact: true,
                  onPressed: eligible ? () => _act(true) : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Booking details sheet (BookingDetailsModal / WebBookingDetailsModal).
/// With [onAction], shows Not available / Claim for eligible bookings.
Future<void> showWebBookingDetails(BuildContext context, Json b, {Future<void> Function(bool)? onAction}) {
  final start = b['startDateTime'] != null
      ? DateTime.tryParse(str(b['startDateTime']))?.toLocal()
      : DateTime.tryParse(str(b['date'] ?? list(b['dates']).firstOrNull));
  final end = b['endDateTime'] != null ? DateTime.tryParse(str(b['endDateTime']))?.toLocal() : null;
  final user = obj(b['userDetails']);
  final inclusions = list(b['inclusions']).map(str).toList();
  final eligible = str(b['action']) == 'ELIGIBLE';
  // Customer details (and notes, which embed the customer's name) stay hidden
  // until the booking is assigned to this pandit. A row still being claimed
  // either comes with [onAction] or carries a non-APPROVED management action.
  final action = str(b['action']).toUpperCase();
  final locked = onAction != null || (action.isNotEmpty && action != 'APPROVED');

  Widget section(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(top: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppText.body(size: 15, weight: FontWeight.w700)),
        const SizedBox(height: 8),
        ...children,
      ],
    ),
  );
  Widget inc(String label, bool on) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Icon(on ? LucideIcons.circleCheck : LucideIcons.circleX, size: 16, color: on ? AppColors.green600 : AppColors.gray400),
        const SizedBox(width: 8),
        Text(label, style: AppText.body(size: 14, color: on ? AppColors.foreground : AppColors.gray400)),
      ],
    ),
  );

  return showAppSheet<void>(
    context,
    title: t('bookingDetails', 'Booking details'),
    builder: (ctx) => ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text(str(b['poojaTitle']), style: AppText.heading(size: 24, color: AppColors.bluntRed)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: [
            _tag(t('bookmyPooja', 'BookMyPooja'), Colors.white, AppColors.bluntRed),
            if (str(b['packageType']).isNotEmpty) _tag(str(b['packageType']), Colors.white, AppColors.saffronDark),
            if (str(b['status']).isNotEmpty) StatusBadge(str(b['status'])),
          ],
        ),
        const SizedBox(height: 12),
        if (start != null) InfoRow(icon: LucideIcons.calendar, text: DateFormat('EEEE dd MMMM, yyyy').format(start)),
        InfoRow(
          icon: LucideIcons.clock,
          text:
              '${b['startDateTime'] != null && start != null ? DateFormat('h:mm a').format(start) : str(b['time'] ?? b['startTime'])}'
              '${end != null ? ' - ${DateFormat('h:mm a').format(end)}' : ''}'
              '${str(b['duration']).isNotEmpty ? ' (${str(b['duration'])} hours)' : ''}',
        ),
        if (str(b['location']).isNotEmpty) InfoRow(icon: LucideIcons.mapPin, text: str(b['location']), maxLines: 4),
        if (locked)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Row(
              children: [
                const Icon(LucideIcons.lock, size: 14, color: AppColors.mutedForeground),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    t('customerDetailsWillBeVisibleAfterConfirmation', 'Customer details will be visible after confirmation'),
                    style: AppText.body(size: 13, color: AppColors.mutedForeground),
                  ),
                ),
              ],
            ),
          )
        else if (user.isNotEmpty)
          section(t('customer_details', 'Customer details'), [
            InfoRow(icon: LucideIcons.user, text: str(user['name'])),
            if (str(user['phone']).isNotEmpty) InfoRow(icon: LucideIcons.phone, text: '+${str(user['countryCode'], '91')}-${str(user['phone'])}'),
            if (str(user['email']).isNotEmpty) InfoRow(icon: LucideIcons.mail, text: str(user['email'])),
            if (str(user['address']).isNotEmpty) InfoRow(icon: LucideIcons.house, text: str(user['address']), maxLines: 4),
          ]),
        section(t('pujainclusions', 'Puja inclusions'), [
          if (inclusions.isNotEmpty)
            for (final i in inclusions) inc(i, true)
          else ...[
            InfoRow(icon: LucideIcons.users, text: '${str(b['numberOfPandits'], '1')} ${t('panditsRequired', 'Pandits required')}', color: AppColors.bluntRed),
            inc(t('samagri', 'Samagri'), boolOf(b['samagri'])),
            inc(t('fruitsFlowers', 'Fruits & flowers'), boolOf(b['fruits']) || boolOf(b['flowers'])),
            inc(t('homa', 'Homa'), boolOf(b['homa'])),
            inc(t('prasad', 'Prasad'), boolOf(b['prasada'])),
          ],
        ]),
        section(t('paymentInformation', 'Payment information'), [
          Row(
            children: [
              Expanded(
                child: Text(t('totalAmount', 'Total amount'), style: AppText.body(size: 14, color: AppColors.mutedForeground)),
              ),
              Text('₹${str(b['amount'], '0')}', style: AppText.body(size: 16, weight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(t('bookingId', 'Booking ID'), style: AppText.body(size: 14, color: AppColors.mutedForeground)),
              ),
              Text(str(b['bookingId']), style: AppText.body(size: 13, weight: FontWeight.w600)),
            ],
          ),
        ]),
        if (!locked && str(b['notes']).isNotEmpty) section(t('notes'), [Text(str(b['notes']), style: AppText.body(size: 14, height: 1.4))]),
        if (onAction != null) ...[
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: t('notAvailable', 'Not available'),
                  kind: BtnKind.outline,
                  onPressed: eligible
                      ? () async {
                          await onAction(false);
                          if (ctx.mounted) Navigator.pop(ctx);
                        }
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(
                  label: eligible ? t('claimBooking', 'Claim booking') : t('interested', 'Interested'),
                  onPressed: eligible
                      ? () async {
                          await onAction(true);
                          if (ctx.mounted) Navigator.pop(ctx);
                        }
                      : null,
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

// ── "From" date range chips (CustomDropdownFromDate.js) ──────────────────

const dateRanges = ['today', 'yesterday', 'last3days', 'week', 'month', 'last3months', 'last6months'];

String dateRangeLabel(String v) => switch (v) {
  'today' => t('today'),
  'yesterday' => t('yesterday'),
  'last3days' => t('three_days'),
  'week' => t('one_week'),
  'month' => t('one_month'),
  'last3months' => t('three_months'),
  _ => t('six_months'),
};

/// Local start of the range, sent as a UTC `yyyy-MM-dd` (getFromDate).
String fromDateFor(String range) {
  final n = DateTime.now();
  final d = switch (range) {
    'yesterday' => DateTime(n.year, n.month, n.day - 1),
    'last3days' => DateTime(n.year, n.month, n.day - 3),
    'week' => DateTime(n.year, n.month, n.day - 7),
    'month' => DateTime(n.year, n.month - 1, n.day),
    'last3months' => DateTime(n.year, n.month - 3, n.day),
    'last6months' => DateTime(n.year, n.month - 6, n.day),
    _ => DateTime(n.year, n.month, n.day),
  };
  return DateFormat('yyyy-MM-dd').format(d.toUtc());
}

class DateRangeChips extends StatelessWidget {
  const DateRangeChips({super.key, required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Text(
          '${t('from')}:',
          style: AppText.body(size: 12, weight: FontWeight.w700, color: AppColors.mutedForeground),
        ),
      ),
      SizedBox(
        height: 38,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          scrollDirection: Axis.horizontal,
          itemCount: dateRanges.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) => SelectChip(
            label: dateRangeLabel(dateRanges[i]),
            selected: selected == dateRanges[i],
            onTap: () => selected == dateRanges[i] ? null : onChanged(dateRanges[i]),
          ),
        ),
      ),
    ],
  );
}
