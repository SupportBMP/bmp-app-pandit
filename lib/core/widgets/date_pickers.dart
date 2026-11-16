import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../i18n/i18n.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../utils/format.dart';
import 'ui.dart';

/// Multi-date calendar sheet (CDateSelector with isMultiSelect). Returns
/// sorted `yyyy-MM-dd` strings.
Future<List<String>?> showMultiDatePicker(BuildContext context, {List<String> initial = const [], DateTime? firstDate}) => showAppSheet<List<String>>(
  context,
  title: t('select_dates', 'Select dates'),
  builder: (_) => _MultiDatePicker(initial: initial, firstDate: firstDate ?? DateTime.now()),
);

class _MultiDatePicker extends StatefulWidget {
  const _MultiDatePicker({required this.initial, required this.firstDate});
  final List<String> initial;
  final DateTime firstDate;

  @override
  State<_MultiDatePicker> createState() => _MultiDatePickerState();
}

class _MultiDatePickerState extends State<_MultiDatePicker> {
  late final Set<String> _sel = {...widget.initial};
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final first = DateTime(_month.year, _month.month);
    final daysIn = DateTime(_month.year, _month.month + 1, 0).day;
    final offset = first.weekday % 7;
    final minDay = DateTime(widget.firstDate.year, widget.firstDate.month, widget.firstDate.day);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)), icon: const Icon(LucideIcons.chevronLeft)),
              Expanded(
                child: Text(
                  DateFormat('MMMM yyyy').format(_month),
                  textAlign: TextAlign.center,
                  style: AppText.body(size: 16, weight: FontWeight.w700),
                ),
              ),
              IconButton(onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)), icon: const Icon(LucideIcons.chevronRight)),
            ],
          ),
          Row(
            children: [
              for (final d in ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: AppText.body(size: 12, weight: FontWeight.w700, color: AppColors.mutedForeground),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (var i = 0; i < offset; i++) const SizedBox(),
              for (var d = 1; d <= daysIn; d++)
                Builder(
                  builder: (_) {
                    final date = DateTime(_month.year, _month.month, d);
                    final key = ymd(date);
                    final on = _sel.contains(key);
                    final disabled = date.isBefore(minDay);
                    return Padding(
                      padding: const EdgeInsets.all(3),
                      child: Material(
                        color: on ? AppColors.bluntRed : Colors.transparent,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: disabled ? null : () => setState(() => on ? _sel.remove(key) : _sel.add(key)),
                          child: Center(
                            child: Text(
                              '$d',
                              style: AppText.body(
                                size: 14,
                                weight: on ? FontWeight.w700 : FontWeight.w500,
                                color: on
                                    ? Colors.white
                                    : disabled
                                    ? AppColors.gray300
                                    : AppColors.foreground,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          AppButton(
            label: _sel.isEmpty ? t('done', 'Done') : '${t('done', 'Done')} (${_sel.length})',
            onPressed: () => Navigator.pop(context, _sel.toList()..sort()),
          ),
        ],
      ),
    );
  }
}

/// Time picker returning "hh:mm AM/PM" (the RN forms' `dayjs().format('hh:mm A')`).
Future<String?> pickTime12(BuildContext context, {String? initial}) async {
  TimeOfDay init = TimeOfDay.now();
  final m = RegExp(r'^(\d{1,2}):(\d{2})\s*(AM|PM)$', caseSensitive: false).firstMatch(initial ?? '');
  if (m != null) {
    var h = int.parse(m[1]!) % 12;
    if (m[3]!.toUpperCase() == 'PM') h += 12;
    init = TimeOfDay(hour: h, minute: int.parse(m[2]!));
  }
  final r = await showTimePicker(context: context, initialTime: init);
  if (r == null) return null;
  return DateFormat('hh:mm a').format(DateTime(2000, 1, 1, r.hour, r.minute)).toUpperCase();
}
