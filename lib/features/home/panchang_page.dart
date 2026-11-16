import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/format.dart';
import '../../core/utils/json.dart';
import '../../core/utils/location.dart';
import '../../core/utils/timezone.dart';
import '../../core/widgets/native.dart';
import '../../core/widgets/ui.dart';

/// Full-day panchang (PanchangScreen.js): the five limbs, sunrise/sunset,
/// auspicious & inauspicious periods, choghadiya and hora tables, for a
/// chosen date at the Pandit's location.
class PanchangPage extends StatefulWidget {
  const PanchangPage({super.key, this.args});
  final Object? args;

  @override
  State<PanchangPage> createState() => _PanchangPageState();
}

class _PanchangPageState extends State<PanchangPage> with SingleTickerProviderStateMixin {
  late String _date = str((widget.args as Map?)?['date'], ymd(DateTime.now()));
  AppLocation _loc = AppLocation.fallback;
  Json? _data;
  bool _loading = true;
  bool _error = false;
  late final _tabs = TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _loc = await LocationService.current();
    await _fetch();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final r = obj(
        await Api.getPanchanga({
          'date': _date,
          'latitude': '${_loc.latitude}',
          'longitude': '${_loc.longitude}',
          'city': _loc.city,
          'state': _loc.state,
          'timezone': await deviceTimezone(),
        }),
      );
      if (boolOf(r['success'])) {
        setState(() => _data = obj(pick(r, ['data', 'data'])));
      } else {
        setState(() => _error = true);
      }
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final d = await showNativeDatePicker(
      context,
      initialDate: DateTime.tryParse(_date),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      title: t('select_date', 'Select date'),
    );
    if (d == null) return;
    setState(() => _date = ymd(d));
    _fetch();
  }

  static String _hm(dynamic iso) {
    final d = DateTime.tryParse(str(iso))?.toLocal();
    return d == null ? '—' : DateFormat('HH:mm').format(d);
  }

  static bool _isNow(Json p) {
    final s = DateTime.tryParse(str(p['start'])), e = DateTime.tryParse(str(p['end']));
    final n = DateTime.now();
    return s != null && e != null && !n.isBefore(s) && !n.isAfter(e);
  }

  /// The running period, else the one starting nearest to now.
  static Json? _current(List<Json> ps) {
    if (ps.isEmpty) return null;
    for (final p in ps) {
      if (_isNow(p)) return p;
    }
    final n = DateTime.now();
    ps.sort(
      (a, b) => (DateTime.tryParse(str(a['start']))?.difference(n).abs() ?? Duration.zero).compareTo(
        DateTime.tryParse(str(b['start']))?.difference(n).abs() ?? Duration.zero,
      ),
    );
    return ps.first;
  }

  @override
  Widget build(BuildContext context) {
    final p = obj(pick(_data, ['panchang', 'data']));
    final tithi = _current(objList(p['tithi']));
    final cho = objList(pick(_data, ['choghadiya', 'data', 'muhurat']));
    final hora = objList(pick(_data, ['hora', 'data', 'hora_timing']));
    final curCho = cho.where(_isNow).firstOrNull;
    final curHora = hora.where(_isNow).firstOrNull;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: appBar(context, t('panchang', 'Panchang'), subtitle: '${_loc.city}${_loc.state.isEmpty ? '' : ', ${_loc.state}'}'),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: PickerField(
              label: t('select_date', 'Select date'),
              value: '${str(p['vaara'], '')}${str(p['vaara']).isEmpty ? '' : ' · '}${fmtDate(_date, 'MMM d, yyyy')}',
              icon: LucideIcons.calendar,
              onTap: _pickDate,
            ),
          ),
          if (curCho != null || curHora != null)
            Container(
              width: double.infinity,
              color: AppColors.cream,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Wrap(
                spacing: 14,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Icon(LucideIcons.clock, size: 16, color: AppColors.saffronDark),
                  if (curCho != null) Text('Choghadiya: ${str(curCho['name'])}', style: AppText.body(size: 13, weight: FontWeight.w600)),
                  if (curHora != null) Text('Hora: ${str(pick(curHora, ['hora', 'vedic_name']))}', style: AppText.body(size: 13, weight: FontWeight.w600)),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const AppLoader(message: 'Loading panchang…')
                : _error
                ? ErrorState(onRetry: _fetch)
                : RefreshIndicator(
                    onRefresh: _fetch,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [_limbs(p, tithi), const SizedBox(height: 16), _periods(p), const SizedBox(height: 16), _tables(cho, hora)],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _limbs(Json p, Json? tithi) {
    Widget tile(IconData i, String k, String v) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cream.withValues(alpha: .6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.creamDark),
      ),
      child: Row(
        children: [
          Icon(i, size: 18, color: AppColors.saffronDark),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(k, style: AppText.body(size: 11, color: AppColors.mutedForeground)),
                Text(
                  v,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(size: 14, weight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    String name(String key) => str(_current(objList(p[key]))?['name'], '—');
    final items = [
      (LucideIcons.moon, 'Tithi', str(tithi?['name'], '—')),
      (LucideIcons.star, 'Nakshatra', name('nakshatra')),
      (LucideIcons.sparkles, 'Yoga', name('yoga')),
      (LucideIcons.calendar, 'Karan', name('karana')),
      (LucideIcons.moonStar, 'Paksha', str(tithi?['paksha'], '—')),
      (LucideIcons.sun, 'Vaar', str(p['vaara'], '—')),
      (LucideIcons.sunrise, 'Sunrise', _hm(p['sunrise'])),
      (LucideIcons.sunset, 'Sunset', _hm(p['sunset'])),
    ];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(t('panchang_elements', 'Panchang elements'), icon: LucideIcons.moon),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (_, c) {
              final w = (c.maxWidth - 10) / 2;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [for (final (i, k, v) in items) SizedBox(width: w, child: tile(i, k, v))],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _periods(Json p) {
    List<(String, String)> extract(dynamic v) => objList(v)
        .map((e) {
          final per = objList(e['period']);
          final s = per.isNotEmpty ? per.first['start'] : e['start'];
          final en = per.isNotEmpty ? per.first['end'] : e['end'];
          if (s == null || en == null) return null;
          return (str(e['name']), '${_hm(s)} – ${_hm(en)}');
        })
        .whereType<(String, String)>()
        .toList();
    final good = extract(p['auspicious_period']);
    final bad = extract(p['inauspicious_period']);
    Widget block(String title, List<(String, String)> rows, Color fg, Color bg, IconData icon) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
              Text(
                title,
                style: AppText.body(size: 14, weight: FontWeight.w700, color: fg),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (rows.isEmpty) Text('—', style: AppText.body(size: 13, color: AppColors.mutedForeground)),
          for (final (n, tm) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(n, style: AppText.body(size: 13, weight: FontWeight.w600)),
                  ),
                  Text(tm, style: AppText.body(size: 13, color: AppColors.mutedForeground)),
                ],
              ),
            ),
        ],
      ),
    );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(t('auspicious_times', 'Auspicious & inauspicious times'), icon: LucideIcons.clock),
          const SizedBox(height: 12),
          block(t('auspicious', 'Auspicious'), good, AppColors.green700, AppColors.green50, LucideIcons.circleCheck),
          const SizedBox(height: 10),
          block(t('inauspicious', 'Inauspicious'), bad, AppColors.red700, AppColors.red50, LucideIcons.circleAlert),
        ],
      ),
    );
  }

  Widget _tables(List<Json> cho, List<Json> hora) => AppCard(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(t('time_table', 'Time table'), icon: LucideIcons.calendarClock),
        const SizedBox(height: 8),
        TabBar(
          controller: _tabs,
          labelColor: AppColors.bluntRed,
          indicatorColor: AppColors.bluntRed,
          unselectedLabelColor: AppColors.mutedForeground,
          labelStyle: AppText.body(size: 14, weight: FontWeight.w700),
          tabs: const [
            Tab(text: 'Choghadiya'),
            Tab(text: 'Hora'),
          ],
        ),
        AnimatedBuilder(
          animation: _tabs,
          builder: (_, _) {
            final rows = _tabs.index == 0
                ? cho.map((e) => (str(e['name']), str(e['vela'], ''), str(e['type']), _isNow(e), '${_hm(e['start'])} – ${_hm(e['end'])}')).toList()
                : hora
                      .map(
                        (e) => (
                          str(pick(e, ['hora', 'vedic_name'])),
                          str(pick(e, ['hora', 'name'])),
                          str(e['type']),
                          _isNow(e),
                          '${_hm(e['start'])} – ${_hm(e['end'])}',
                        ),
                      )
                      .toList();
            if (rows.isEmpty)
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Text('—', textAlign: TextAlign.center, style: AppText.body(size: 14)),
              );
            return Column(
              children: [
                for (final (name, sub, type, now, time) in rows)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: now ? AppColors.bluntRed.withValues(alpha: .06) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: now ? AppColors.bluntRed.withValues(alpha: .4) : AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(time, style: AppText.body(size: 13, weight: FontWeight.w600)),
                              if (sub.isNotEmpty) Text(sub, style: AppText.body(size: 11, color: AppColors.mutedForeground)),
                            ],
                          ),
                        ),
                        if (now)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              t('now', 'NOW'),
                              style: AppText.body(size: 10, weight: FontWeight.w800, color: AppColors.bluntRed, letterSpacing: 1),
                            ),
                          ),
                        _typeChip(name, type),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
      ],
    ),
  );

  Widget _typeChip(String name, String type) {
    final good = type == 'Most Auspicious' || type == 'Good';
    final bad = type == 'Bad' || type == 'Inauspicious';
    final (fg, bg) = good
        ? (AppColors.green700, AppColors.green50)
        : bad
        ? (AppColors.red700, AppColors.red50)
        : (AppColors.amber700, AppColors.amber50);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        name,
        style: AppText.body(size: 12, weight: FontWeight.w700, color: fg),
      ),
    );
  }
}
