import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api.dart';
import '../../core/api/api_client.dart';
import '../../core/i18n/i18n.dart';
import '../../core/router/routes.dart';
import '../../core/state/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/format.dart';
import '../../core/utils/json.dart';
import '../../core/widgets/toast.dart';
import '../../core/widgets/ui.dart';
import '../profile/subscription_gate.dart';
import 'booking_widgets.dart';

/// Booking management (BookingsTab.js): availability, date-range filter,
/// stats, status tabs, marketplace (web) bookings to claim, and the
/// Pandit's own bookings with their lifecycle actions.
class BookingsPage extends ConsumerStatefulWidget {
  const BookingsPage({super.key, this.args});
  final Object? args;

  @override
  ConsumerState<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends ConsumerState<BookingsPage> {
  String _range = 'today';
  String _tab = 'all';
  List<Json> _poojas = [];
  List<Json> _web = [];
  bool _loading = true;
  bool _error = false;
  bool _toggling = false;
  DateTime _now = DateTime.now();
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _load();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) => mounted ? setState(() => _now = DateTime.now()) : null);
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = false);
    try {
      final results = await Future.wait([Api.getPoojas(fromDate: fromDateFor(_range)), Api.fetchWebBookings().catchError((_) => <dynamic>[])]);
      final w = results[1];
      setState(() {
        _poojas = objList(results[0]);
        _web = (w is List ? objList(w) : objList(obj(w)['data'])).map(flattenWebBooking).toList();
      });
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleAvailability(bool available) async {
    setState(() => _toggling = true);
    try {
      final r = obj(await Api.toggleAvailability(available));
      final a = str(r['availability'], available ? 'available' : 'busy');
      ref.read(sessionProvider.notifier).patch({'availability': a});
      Toast.success('${t('status_updated_to', 'Status updated to')} ${available ? t('available', 'Available') : t('busy', 'Busy')}');
    } catch (e) {
      Toast.error(apiError(e, 'Failed to update availability'));
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  Future<void> _newBooking() async {
    if (!await ensureSubscription(context)) return;
    if (!mounted) return;
    final created = await context.push<bool>(R.addPuja);
    if (created == true) _load();
  }

  Future<void> _edit(Json p) async {
    final saved = await context.push<bool>(R.addPuja, extra: {'booking': p});
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider);
    final available = str(user?['availability']) == 'available';
    final filtered = _tab == 'all' ? _poojas : _poojas.where((p) => str(p['status']).toLowerCase() == _tab).toList();
    final pending = _poojas.where((p) => str(p['status']).toLowerCase() == 'pending').length;
    final todayKey = ymd(DateTime.now());
    final todays = _poojas.where((p) => list(p['dates']).any((d) => parseDate(d) != null && ymd(parseDate(d)!) == todayKey)).length;
    final revenue = _poojas.fold<num>(0, (s, p) => s + (str(p['status']).toLowerCase() == 'paid' ? numOf(p['dakshinaAmount']) : 0));

    return Scaffold(
      backgroundColor: pageBg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newBooking,
        backgroundColor: AppColors.bluntRed,
        foregroundColor: Colors.white,
        icon: const Icon(LucideIcons.plus),
        label: Text(
          t('new_booking'),
          style: AppText.body(size: 15, weight: FontWeight.w700, color: Colors.white),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.bluntRed,
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(t('booking_management'), style: AppText.heading(size: 24)),
                                  Text(t('all_puja_bookings'), style: AppText.body(size: 13, color: AppColors.mutedForeground)),
                                ],
                              ),
                            ),
                            _availability(available),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _stat('${_poojas.length}', t('total_bookings'), LucideIcons.calendarCheck, AppColors.bluntRed),
                            const SizedBox(width: 8),
                            _stat('$pending', t('pending'), LucideIcons.hourglass, AppColors.amber600),
                            const SizedBox(width: 8),
                            _stat('$todays', t('today'), LucideIcons.sun, AppColors.saffronDark),
                            const SizedBox(width: 8),
                            _stat(inr(revenue), t('total_revenue'), LucideIcons.indianRupee, AppColors.green600),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.only(bottom: 12),
                child: DateRangeChips(
                  selected: _range,
                  onChanged: (v) {
                    setState(() {
                      _range = v;
                      _loading = true;
                    });
                    _load();
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(child: Divider(height: 1)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: FilterTabs(
                  items: [('all', t('all')), ('confirmed', t('confirmed')), ('completed', t('completed')), ('paid', t('paid'))],
                  selected: _tab,
                  onChanged: (v) => setState(() => _tab = v),
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(hasScrollBody: false, child: AppLoader())
            else if (_error)
              SliverFillRemaining(hasScrollBody: false, child: ErrorState(onRetry: _load))
            else if (filtered.isEmpty && _web.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: LucideIcons.calendarX,
                  title: t('no_bookings', 'No bookings yet'),
                  message: t('no_data_available'),
                  action: t('new_booking'),
                  onAction: _newBooking,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                sliver: SliverList.list(
                  children: [
                    for (final w in _web) WebBookingCard(data: w, onChanged: _load),
                    for (final p in filtered) BookingCard(data: p, now: _now, onChanged: _load, onEdit: _edit),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _availability(bool available) => Container(
    padding: const EdgeInsets.only(left: 12, right: 4),
    decoration: BoxDecoration(
      color: available ? AppColors.green50 : AppColors.gray100,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: available ? AppColors.green100 : AppColors.gray200),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: available ? AppColors.green600 : AppColors.gray400, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          available ? t('available', 'Available') : t('busy', 'Busy'),
          style: AppText.body(size: 13, weight: FontWeight.w700, color: available ? AppColors.green700 : AppColors.gray600),
        ),
        Transform.scale(
          scale: .8,
          child: Switch(value: available, onChanged: _toggling ? null : _toggleAvailability, activeTrackColor: AppColors.green600),
        ),
      ],
    ),
  );

  Widget _stat(String v, String label, IconData icon, Color c) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(color: c.withValues(alpha: .06), borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Icon(icon, size: 16, color: c),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(v, style: AppText.body(size: 16, weight: FontWeight.w800)),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.body(size: 10.5, color: AppColors.mutedForeground),
          ),
        ],
      ),
    ),
  );
}
