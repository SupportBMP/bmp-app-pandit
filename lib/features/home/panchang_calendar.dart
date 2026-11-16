import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/json.dart';
import '../../core/utils/timezone.dart';
import '../../core/widgets/ui.dart';

/// Monthly Hindu calendar with tithi + moon per day and a details panel for
/// the selected day (HinduCalendar.js → `/api/panchang/monthly`).
class PanchangCalendar extends StatefulWidget {
  const PanchangCalendar({super.key, required this.latitude, required this.longitude, required this.onViewDetails, this.refreshTick = 0});
  final double latitude;
  final double longitude;
  final ValueChanged<String> onViewDetails;
  final int refreshTick;

  @override
  State<PanchangCalendar> createState() => _PanchangCalendarState();
}

class _PanchangCalendarState extends State<PanchangCalendar> {
  static const _dayIndex = {'Sunday': 0, 'Monday': 1, 'Tuesday': 2, 'Wednesday': 3, 'Thursday': 4, 'Friday': 5, 'Saturday': 6};
  final _now = DateTime.now();
  late int _year = _now.year;
  late int _month = _now.month;
  late int _selected = _now.day;
  Json? _data;
  bool _loading = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void didUpdateWidget(covariant PanchangCalendar old) {
    super.didUpdateWidget(old);
    if (old.refreshTick != widget.refreshTick) {
      _year = _now.year;
      _month = _now.month;
      _fetch();
    } else if (old.latitude != widget.latitude || old.longitude != widget.longitude) {
      _fetch();
    }
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final r = obj(
        await Api.getMonthlyPanchang({
          'year': _year,
          'month': _month,
          'latitude': widget.latitude,
          'longitude': widget.longitude,
          'timezone': await deviceTimezone(),
        }),
      );
      if (boolOf(r['success']) && r['data'] != null) {
        final today = DateTime.now();
        setState(() {
          _data = obj(r['data']);
          _selected = (_year == today.year && _month == today.month) ? today.day : 1;
        });
      } else {
        setState(() => _error = true);
      }
    } catch (_) {
      if (mounted) setState(() => _error = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _shift(int delta) {
    var m = _month + delta, y = _year;
    if (m < 1) {
      m = 12;
      y--;
    } else if (m > 12) {
      m = 1;
      y++;
    }
    setState(() {
      _month = m;
      _year = y;
    });
    _fetch();
  }

  @override
  Widget build(BuildContext context) {
    final days = objList(_data?['days']);
    final sel = days.where((d) => intOf(d['day']) == _selected).firstOrNull;
    final monthName = DateFormat('MMMM yyyy').format(DateTime(_year, _month));

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('panchanga', 'Panchanga'), style: AppText.heading(size: 22)),
                    if (sel != null)
                      Text(
                        '${str(sel['vaara'])} · ${str(sel['tithi'])}, ${str(sel['paksha'])}',
                        style: AppText.body(size: 13, color: AppColors.mutedForeground),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (str(_data?['hindu_month']).isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.creamDark),
                  ),
                  child: Text(
                    str(_data?['hindu_month']),
                    style: AppText.body(size: 12, weight: FontWeight.w700, color: AppColors.saffronDark),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                onPressed: _loading ? null : () => _shift(-1),
                icon: const Icon(LucideIcons.chevronLeft, color: AppColors.bluntRed),
              ),
              Expanded(
                child: Text(
                  monthName,
                  textAlign: TextAlign.center,
                  style: AppText.body(size: 16, weight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: _loading ? null : () => _shift(1),
                icon: const Icon(LucideIcons.chevronRight, color: AppColors.bluntRed),
              ),
            ],
          ),
          if (_loading)
            const SizedBox(height: 280, child: AppLoader(size: 36, message: 'Loading panchanga…'))
          else if (_error)
            SizedBox(
              height: 200,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(t('unable_to_load_calendar', 'Unable to load calendar'), style: AppText.body(size: 14, color: AppColors.red600)),
                    TextButton(onPressed: _fetch, child: Text(t('retry', 'Retry'))),
                  ],
                ),
              ),
            )
          else ...[
            _grid(days),
            if (sel != null) ...[const SizedBox(height: 14), _details(sel)],
          ],
        ],
      ),
    );
  }

  Widget _grid(List<Json> days) {
    if (days.isEmpty) return const SizedBox.shrink();
    final offset = _dayIndex[str(days.first['vaara'])] ?? 0;
    final cells = <Json?>[...List.filled(offset, null), ...days];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    const names = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Center(
                  child: Text(
                    names[i],
                    style: AppText.body(size: 12, weight: FontWeight.w700, color: i == 0 ? AppColors.red600 : AppColors.mutedForeground),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var w = 0; w < cells.length / 7; w++) Row(children: [for (var i = 0; i < 7; i++) Expanded(child: _cell(cells[w * 7 + i], i == 0))]),
      ],
    );
  }

  Widget _cell(Json? d, bool sunday) {
    if (d == null) return const SizedBox(height: 62);
    final day = intOf(d['day']);
    final selected = day == _selected;
    final today = day == _now.day && _month == _now.month && _year == _now.year;
    final purnima = str(d['tithi']) == 'Purnima';
    final amavasya = intOf(d['tithi_number']) == 30;
    final bg = selected
        ? AppColors.bluntRed
        : purnima
        ? AppColors.orange50
        : amavasya
        ? const Color(0xFFE8EAF6)
        : Colors.transparent;
    return GestureDetector(
      onTap: () => setState(() => _selected = day),
      child: Container(
        height: 62,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: today && !selected ? Border.all(color: AppColors.bluntRed, width: 1.5) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$day',
              style: AppText.body(size: 14, weight: FontWeight.w700, color: selected ? Colors.white : (sunday ? AppColors.red600 : AppColors.foreground)),
            ),
            Text(str(d['moon_emoji']), style: const TextStyle(fontSize: 13)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                str(d['tithi']),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(
                  size: 8.5,
                  weight: FontWeight.w600,
                  color: selected
                      ? Colors.white
                      : purnima
                      ? AppColors.orange600
                      : amavasya
                      ? const Color(0xFF283593)
                      : AppColors.mutedForeground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _details(Json d) {
    final date = DateTime(_year, _month, intOf(d['day']));
    Widget row(IconData i, String k, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(i, size: 16, color: AppColors.saffronDark),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: Text(k, style: AppText.body(size: 13, color: AppColors.mutedForeground)),
          ),
          Expanded(
            child: Text(v.isEmpty ? '—' : v, style: AppText.body(size: 14, weight: FontWeight.w600)),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cream.withValues(alpha: .6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.creamDark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(str(d['moon_emoji']), style: const TextStyle(fontSize: 30)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${str(d['vaara'])}, ${DateFormat('d MMM yyyy').format(date)}', style: AppText.body(size: 16, weight: FontWeight.w700)),
                    Text(
                      '${str(d['tithi'])}, ${str(d['paksha'])}',
                      style: AppText.body(size: 13, weight: FontWeight.w600, color: AppColors.bluntRed),
                    ),
                    if (str(_data?['hindu_month']).isNotEmpty)
                      Text('${str(_data?['hindu_month'])} · ${str(_data?['hindu_year'])}', style: AppText.body(size: 12, color: AppColors.mutedForeground)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          row(LucideIcons.moon, 'Tithi', str(d['tithi'])),
          row(LucideIcons.star, 'Nakshatra', str(d['nakshatra'])),
          row(LucideIcons.circle, 'Yoga', str(d['yoga'])),
          row(LucideIcons.square, 'Karan', str(d['karana'])),
          row(LucideIcons.calendar, 'Vaar', str(d['vaara'])),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _pill(LucideIcons.sunrise, 'Sunrise', str(d['sunrise']))),
              const SizedBox(width: 8),
              Expanded(child: _pill(LucideIcons.sunset, 'Sunset', str(d['sunset']))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _pill(null, 'Moon sign', str(d['moon_zodiac']), emoji: str(d['moon_zodiac_emoji']))),
              const SizedBox(width: 8),
              Expanded(child: _pill(null, 'Sun sign', str(d['sun_zodiac']), emoji: str(d['sun_zodiac_emoji']))),
            ],
          ),
          const SizedBox(height: 14),
          AppButton(
            label: t('view_details', 'View details'),
            trailingIcon: LucideIcons.arrowRight,
            compact: true,
            onPressed: () => widget.onViewDetails(DateFormat('yyyy-MM-dd').format(date)),
          ),
        ],
      ),
    );
  }

  Widget _pill(IconData? icon, String label, String value, {String? emoji}) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        if (icon != null) Icon(icon, size: 18, color: AppColors.saffronDark) else Text(emoji ?? '', style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppText.body(size: 11, color: AppColors.mutedForeground)),
              Text(
                value.isEmpty ? '—' : value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(size: 13, weight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
