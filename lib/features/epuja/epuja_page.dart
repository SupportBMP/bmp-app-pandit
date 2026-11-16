import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api/api.dart';
import '../../core/api/api_client.dart';
import '../../core/config/env.dart';
import '../../core/i18n/i18n.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/format.dart';
import '../../core/utils/json.dart';
import '../../core/widgets/date_pickers.dart';
import '../../core/widgets/native.dart';
import '../../core/widgets/toast.dart';
import '../../core/widgets/ui.dart';
import '../bookings/booking_widgets.dart' show liveComingSoon, DateRangeChips, fromDateFor;
import '../profile/subscription_gate.dart';

/// E-Puja events (EPujaTab.js): schedule, edit, share and close out online
/// pujas, grouped into Active / Upcoming / Completed. Going live is not part
/// of this release.
class EPujaPage extends StatefulWidget {
  const EPujaPage({super.key});

  @override
  State<EPujaPage> createState() => _EPujaPageState();
}

class _EPujaPageState extends State<EPujaPage> {
  List<Json> _events = [];
  bool _loading = true;
  bool _error = false;
  int _tab = 1;
  String _range = 'today';
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
      _events = objList(await Api.getEPoojaEvents(fromDate: fromDateFor(_range)));
    } catch (_) {
      _error = true;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _add() async {
    if (!await ensureSubscription(context)) return;
    if (!mounted) return;
    if (await showEPujaForm(context) == true) _load();
  }

  Future<void> _setStatus(Json e, String status) async {
    try {
      await Api.updateEPoojaEventStatus(str(e['_id']), {'status': status});
      Toast.success('${t('event_marked_as', 'Event marked as')} ${status.toLowerCase()}');
      _load();
    } catch (err) {
      Toast.error(apiError(err, 'Error updating event status'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = <Json>[], upcoming = <Json>[], completed = <Json>[];
    for (final e in _events) {
      final s = str(e['status']);
      if (s == 'CANCELLED' || s == 'COMPLETED') {
        completed.add(e);
      } else if (s == 'CONFIRMED') {
        final (isNow, isOver) = epujaTiming(e, _now);
        (isOver
                ? completed
                : isNow
                ? active
                : upcoming)
            .add(e);
      }
    }
    final lists = [active, upcoming, completed];
    final viewers = _events.fold<int>(0, (s, e) => s + intOf(e['max_viewers']));

    return Scaffold(
      backgroundColor: pageBg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        backgroundColor: AppColors.bluntRed,
        foregroundColor: Colors.white,
        icon: const Icon(LucideIcons.plus),
        label: Text(
          t('add_epuja'),
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
                        Text(t('epuja_management'), style: AppText.heading(size: 24)),
                        Text(
                          t('epuja_subtitle', 'Schedule online pujas and manage sankalpa & offerings'),
                          style: AppText.body(size: 13, color: AppColors.mutedForeground),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _stat('${_events.length}', t('total_epuja'), LucideIcons.video),
                            const SizedBox(width: 8),
                            _stat('$viewers', t('total_viewers'), LucideIcons.eye),
                            const SizedBox(width: 8),
                            _stat('${active.length}', t('active'), LucideIcons.radio),
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
                  items: [
                    ('0', '${t('active')} (${active.length})'),
                    ('1', '${t('upcoming')} (${upcoming.length})'),
                    ('2', '${t('completed')} (${completed.length})'),
                  ],
                  selected: '$_tab',
                  onChanged: (v) => setState(() => _tab = int.parse(v)),
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(hasScrollBody: false, child: AppLoader())
            else if (_error)
              SliverFillRemaining(hasScrollBody: false, child: ErrorState(onRetry: _load))
            else if (lists[_tab].isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: LucideIcons.videoOff,
                  title: t('no_epuja_events', 'No e-puja events here'),
                  message: _tab == 1 ? t('schedule_epuja_hint', 'Schedule an online puja and share the link with devotees.') : null,
                  action: _tab == 1 ? t('add_epuja') : null,
                  onAction: _add,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                sliver: SliverList.list(
                  children: [
                    for (final e in lists[_tab])
                      _EPujaCard(
                        data: e,
                        now: _now,
                        onEdit: () async {
                          if (await showEPujaForm(context, editing: e) == true) _load();
                        },
                        onStatus: (s) => _setStatus(e, s),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String v, String label, IconData icon) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: AppColors.bluntRed.withValues(alpha: .06), borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Icon(icon, size: 16, color: AppColors.bluntRed),
          const SizedBox(height: 4),
          Text(v, style: AppText.body(size: 17, weight: FontWeight.w800)),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.body(size: 11, color: AppColors.mutedForeground),
          ),
        ],
      ),
    ),
  );
}

/// (isNow, isOver) for an e-puja event (checkEPujaStatus).
(bool, bool) epujaTiming(Json e, DateTime now) {
  DateTime? s, en;
  if (e['startDateTime'] != null && e['endDateTime'] != null) {
    s = DateTime.tryParse(str(e['startDateTime']))?.toLocal();
    en = DateTime.tryParse(str(e['endDateTime']))?.toLocal();
  } else {
    final day = parseDate(e['date']);
    if (day != null && str(e['startTime']).contains(':')) {
      s = DateTime.tryParse('${ymd(day)} ${str(e['startTime'])}');
      en = s?.add(Duration(minutes: intOf(e['duration'])));
    }
  }
  if (s == null || en == null) return (false, false);
  return (!now.isBefore(s) && !now.isAfter(en), now.isAfter(en));
}

DateTime? epujaLocalStart(Json e) {
  if (str(e['dateLocal']).isNotEmpty) return DateTime.tryParse(str(e['dateLocal']));
  if (e['startDateTime'] != null) return DateTime.tryParse(str(e['startDateTime']))?.toLocal();
  final day = parseDate(e['date']);
  if (day != null && str(e['startTime']).contains(':')) {
    return DateTime.tryParse('${DateFormat('yyyy-MM-dd').format(day.toUtc())}T${str(e['startTime'])}:00Z')?.toLocal();
  }
  return day;
}

class _EPujaCard extends StatelessWidget {
  const _EPujaCard({required this.data, required this.now, required this.onEdit, required this.onStatus});
  final Json data;
  final DateTime now;
  final VoidCallback onEdit;
  final ValueChanged<String> onStatus;

  Future<void> _share() async {
    final url = '${Env.webBaseUrl}/live?channel=${Uri.encodeComponent(str(data['channelId']))}';
    final start = epujaLocalStart(data);
    final title = str(data['poojaTitle'] ?? data['title'], 'Puja');
    final date = start == null ? 'TBD' : DateFormat('dd/MM/yyyy').format(start);
    final time = str(data['startTimeLocal']).isNotEmpty ? str(data['startTimeLocal']) : (start == null ? 'TBD' : DateFormat('h:mm a').format(start));
    await SharePlus.instance.share(ShareParams(title: 'Invitation for $title', text: 'Namaste! You are invited for $title on $date at $time\n\n$url'));
  }

  Future<void> _confirmComplete(BuildContext context) async {
    final r = await showActionSheet<String>(
      context,
      title: t('is_the_event_complete'),
      actions: [('COMPLETED', LucideIcons.circleCheck, t('completed')), ('CANCELLED', LucideIcons.circleX, t('no_cancelled', 'No, cancelled'))],
    );
    if (r != null) onStatus(r);
  }

  @override
  Widget build(BuildContext context) {
    final s = str(data['status']);
    final (isNow, isOver) = epujaTiming(data, now);
    final start = epujaLocalStart(data);
    final today = DateTime(now.year, now.month, now.day);
    final dayLabel = start == null
        ? '—'
        : DateTime(start.year, start.month, start.day) == today
        ? t('today')
        : DateTime(start.year, start.month, start.day) == today.add(const Duration(days: 1))
        ? t('tomorrow')
        : DateFormat('dd MMM').format(start);
    final time = str(data['startTimeLocal']).isNotEmpty
        ? str(data['startTimeLocal'])
        : (start == null ? str(data['startTime']) : DateFormat('h:mm a').format(start));

    final (label, color) = s == 'COMPLETED'
        ? ('Completed', AppColors.emerald600)
        : s == 'CANCELLED'
        ? ('Cancelled', AppColors.red600)
        : isOver
        ? ('Ended', AppColors.gray500)
        : isNow
        ? ('Live', AppColors.red600)
        : ('Scheduled', AppColors.amber600);
    final editable = s == 'CONFIRMED' && !isNow && !isOver;
    final showLink = s == 'CONFIRMED' && !isOver;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => context.push(R.epujaOfferings, extra: {'eventId': str(data['_id'])}),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  str(data['poojaTitle'] ?? data['title']),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(size: 17, weight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(999)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (label == 'Live') ...[
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      label,
                      style: AppText.body(size: 12, weight: FontWeight.w700, color: color),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${t('epuja_event')} • ${t('max_viewers')} ${str(data['max_viewers'])} ${t('viewers')}',
            style: AppText.body(size: 13, color: AppColors.mutedForeground),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [_meta(LucideIcons.calendar, dayLabel), _meta(LucideIcons.clock, time), _meta(LucideIcons.timer, '${str(data['duration'])} min')],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: isOver && s == 'CONFIRMED'
                    ? AppButton(label: t('is_the_event_complete'), compact: true, kind: BtnKind.secondary, onPressed: () => _confirmComplete(context))
                    : s == 'COMPLETED'
                    ? AppButton(label: t('complete'), compact: true, kind: BtnKind.success, icon: LucideIcons.check, onPressed: null)
                    : s == 'CANCELLED'
                    ? AppButton(label: t('cancelled'), compact: true, kind: BtnKind.outline, onPressed: null)
                    : AppButton(
                        label: isNow ? t('join_live') : t('start_stream'),
                        compact: true,
                        icon: isNow ? LucideIcons.video : LucideIcons.play,
                        onPressed: isNow ? liveComingSoon : null,
                      ),
              ),
              if (showLink) ...[const SizedBox(width: 8), IconPill(icon: LucideIcons.share2, onTap: _share, tooltip: t('share', 'Share'))],
              if (editable) ...[const SizedBox(width: 8), IconPill(icon: LucideIcons.pencil, onTap: onEdit, tooltip: t('edit', 'Edit'))],
            ],
          ),
        ],
      ),
    );
  }

  Widget _meta(IconData i, String v) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(i, size: 14, color: AppColors.mutedForeground),
      const SizedBox(width: 4),
      Text(v, style: AppText.body(size: 13, weight: FontWeight.w600)),
    ],
  );
}

/// Create / edit e-puja sheet (AddEPoojaEvent.js). Returns true when saved.
Future<bool?> showEPujaForm(BuildContext context, {Json? editing}) {
  final title = TextEditingController(text: str(editing?['poojaTitle']));
  final duration = TextEditingController(text: str(editing?['duration']));
  final viewers = TextEditingController(text: str(editing?['max_viewers'], '10'));
  String date = editing == null
      ? ''
      : (str(editing['dateLocal']).isNotEmpty
            ? str(editing['dateLocal']).substring(0, 10)
            : (parseDate(editing['date']) == null ? '' : ymd(parseDate(editing['date'])!)));
  String time = editing == null ? '' : (str(editing['startTimeLocal']).isNotEmpty ? str(editing['startTimeLocal']) : to12Hour(str(editing['startTime'])));
  var saving = false;

  return showAppSheet<bool>(
    context,
    title: editing != null ? t('edit_epuja', 'Edit e-puja') : t('add_epuja'),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            t('epuja_details'),
            style: AppText.body(size: 14, weight: FontWeight.w700, color: AppColors.mutedForeground),
          ),
          const SizedBox(height: 10),
          AppTextField(controller: title, label: t('pooja_title'), required: true, hint: t('title_of_pooja')),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: duration,
                  label: t('duration_minutes'),
                  required: true,
                  hint: t('duration_in_minutes'),
                  digitsOnly: true,
                  maxLength: 3,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppTextField(
                  controller: viewers,
                  label: t('max_viewers'),
                  hint: t('maximum_viewers_allowed'),
                  digitsOnly: true,
                  maxLength: 4,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            t('date_and_time'),
            style: AppText.body(size: 14, weight: FontWeight.w700, color: AppColors.mutedForeground),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: PickerField(
                  label: t('date'),
                  required: true,
                  icon: LucideIcons.calendar,
                  value: date.isEmpty ? null : fmtDate(date, 'd MMM yyyy'),
                  onTap: () async {
                    final d = await showNativeDatePicker(
                      ctx,
                      initialDate: DateTime.tryParse(date),
                      firstDate: DateTime.now().subtract(const Duration(days: 1)),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (d != null) set(() => date = ymd(d));
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PickerField(
                  label: t('time'),
                  required: true,
                  icon: LucideIcons.clock,
                  value: time,
                  onTap: () async {
                    final r = await pickTime12(ctx, initial: time);
                    if (r != null) set(() => time = r);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          AppButton(
            label: editing != null ? t('update') : t('create'),
            loading: saving,
            onPressed: () async {
              if (title.text.trim().isEmpty) return Toast.error(t('enter_pooja_title', 'Please enter the pooja title'));
              if (duration.text.trim().isEmpty) return Toast.error(t('enter_duration', 'Please enter the duration'));
              if (date.isEmpty || time.isEmpty) return Toast.error(t('select_date_time', 'Please select date and time'));
              set(() => saving = true);
              final payload = {
                'poojaTitle': title.text.trim(),
                'date': date,
                'startTime': time,
                'duration': int.tryParse(duration.text) ?? 0,
                'max_viewers': int.tryParse(viewers.text) ?? 10,
                if (editing != null) 'epoojaId': editing['_id'],
              };
              try {
                if (editing != null) {
                  await Api.updateEPoojaEvent(payload);
                  Toast.success(t('epuja_updated', 'Successfully updated ePuja event'));
                } else {
                  await Api.createEPoojaEvent(payload);
                  Toast.success(t('epuja_created', 'Successfully created ePuja event'));
                }
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                Toast.error(apiError(e, 'Error saving ePuja event'));
                set(() => saving = false);
              }
            },
          ),
        ],
      ),
    ),
  );
}
