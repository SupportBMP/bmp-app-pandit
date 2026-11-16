import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api.dart';
import '../../core/api/api_client.dart';
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

/// Create / edit a booking in three steps (AddPuja.js + MultiSheetModal):
/// essentials → dates & time → devotee & instructions. Pops `true` on save.
class AddPujaPage extends StatefulWidget {
  const AddPujaPage({super.key, this.args});
  final Object? args;

  @override
  State<AddPujaPage> createState() => _AddPujaPageState();
}

class _AddPujaPageState extends State<AddPujaPage> {
  late final Json? _editing = (widget.args as Map?)?['booking'] is Map ? obj((widget.args as Map)['booking']) : null;
  int _step = 0;
  bool _saving = false;
  List<Json> _families = [];

  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _duration = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();
  bool _online = false;
  List<String> _dates = [];
  String _time = '';
  String? _familyId;

  @override
  void initState() {
    super.initState();
    final e = _editing;
    if (e != null) {
      _title.text = str(e['poojaTitle']);
      _online = str(e['poojaType']) == 'online';
      final tz = objList(e['datesWithTimezone']);
      _dates = tz.isNotEmpty
          ? tz.map((d) => str(d['dateInUserTZ'])).where((s) => s.isNotEmpty).toList()
          : list(e['dates']).map((d) => parseDate(d)).whereType<DateTime>().map(ymd).toList();
      _time = str(e['startTimeLocal']).isNotEmpty ? str(e['startTimeLocal']) : to12Hour(str(e['startTime']));
      _duration.text = str(e['duration']);
      _address.text = str(e['address']);
      _amount.text = str(e['dakshinaAmount']);
      _notes.text = str(e['notes']);
      final ids = list(e['customerIds']);
      _familyId = ids.isEmpty ? null : str(ids.first);
    }
    _loadFamilies();
  }

  @override
  void dispose() {
    for (final c in [_title, _amount, _duration, _address, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadFamilies() async {
    try {
      final r = obj(await Api.getFamilies());
      if (mounted) setState(() => _families = objList(r['families']));
    } catch (_) {}
  }

  String? _stepError() => switch (_step) {
    0 when _title.text.trim().isEmpty => t('enter_pooja_title', 'Please enter the pooja title'),
    0 when _amount.text.trim().isEmpty => t('enter_dakshina', 'Please enter the dakshina amount'),
    1 when _dates.isEmpty => t('select_at_least_one_date', 'Please select at least one date'),
    1 when _time.isEmpty => t('select_time', 'Please select a time'),
    2 when _familyId == null => t('select_devotee', 'Please select a devotee'),
    2 when !_online && _address.text.trim().isEmpty => t('enter_address', 'Please enter the address'),
    _ => null,
  };

  Future<void> _next() async {
    final err = _stepError();
    if (err != null) return Toast.error(err);
    if (_step < 2) return setState(() => _step++);
    final payload = <String, dynamic>{
      'poojaTitle': _title.text.trim(),
      'poojaType': _online ? 'online' : 'onsite',
      'dates': _dates,
      'startTime': _time,
      'duration': num.tryParse(_duration.text) ?? 0,
      'address': _online ? null : _address.text.trim(),
      'dakshinaAmount': num.tryParse(_amount.text) ?? 0,
      'notes': _notes.text.trim(),
      'customerIds': [_familyId],
      'status': 'CONFIRMED',
      if (_editing != null) 'poojaId': _editing['_id'],
    }..removeWhere((k, v) => v == null);
    setState(() => _saving = true);
    try {
      if (_editing != null) {
        await Api.updatePooja(payload);
        Toast.success(t('puja_updated', 'Successfully updated puja'));
      } else {
        await Api.createPooja(payload);
        Toast.success(t('puja_created', 'Successfully created puja'));
      }
      if (mounted) context.pop(true);
    } catch (e) {
      Toast.error(apiError(e, _editing != null ? 'Error updating puja' : 'Error creating puja'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = [t('essential_epuja_info'), t('set_date_time'), t('devotee_and_instructions')];
    return Scaffold(
      backgroundColor: pageBg,
      appBar: appBar(context, _editing != null ? t('edit_pooja') : t('add_puja')),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 5,
                          decoration: BoxDecoration(color: i <= _step ? AppColors.bluntRed : AppColors.gray200, borderRadius: BorderRadius.circular(3)),
                        ),
                      ),
                      if (i < 2) const SizedBox(width: 6),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Text('${t('step', 'Step')} ${_step + 1}/3 · ${steps[_step]}', style: AppText.body(size: 14, weight: FontWeight.w700)),
              ],
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: ListView(
                key: ValueKey(_step),
                padding: const EdgeInsets.all(16),
                children: [
                  AppCard(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [_stepBody()]),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  if (_step > 0) ...[
                    Expanded(
                      child: AppButton(label: t('back'), kind: BtnKind.outline, icon: LucideIcons.arrowLeft, onPressed: () => setState(() => _step--)),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    flex: 2,
                    child: AppButton(
                      label: _step < 2 ? t('next') : (_editing != null ? t('update') : t('create')),
                      trailingIcon: _step < 2 ? LucideIcons.arrowRight : LucideIcons.check,
                      loading: _saving,
                      onPressed: _next,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepBody() => switch (_step) {
    0 => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _onlineToggle(),
        const SizedBox(height: 16),
        AppTextField(controller: _title, label: t('pooja_title'), required: true, hint: t('title_of_pooja'), textCapitalization: TextCapitalization.sentences),
        const SizedBox(height: 12),
        AppTextField(
          controller: _amount,
          label: t('dakshina_amount'),
          required: true,
          hint: t('amount'),
          digitsOnly: true,
          keyboardType: TextInputType.number,
          prefix: const Icon(LucideIcons.indianRupee, size: 18),
        ),
      ],
    ),
    1 => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PickerField(
          label: t('dates'),
          required: true,
          icon: LucideIcons.calendarDays,
          value: _dates.isEmpty ? null : _dates.map((d) => DateFormat('d MMM').format(DateTime.parse(d))).join(', '),
          onTap: () async {
            final r = await showMultiDatePicker(context, initial: _dates);
            if (r != null) setState(() => _dates = r);
          },
        ),
        const SizedBox(height: 12),
        PickerField(
          label: t('time'),
          required: true,
          icon: LucideIcons.clock,
          value: _time,
          onTap: () async {
            final r = await pickTime12(context, initial: _time);
            if (r != null) setState(() => _time = r);
          },
        ),
        const SizedBox(height: 12),
        AppTextField(
          controller: _duration,
          label: t('duration_hours'),
          hint: t('duration'),
          digitsOnly: true,
          maxLength: 3,
          keyboardType: TextInputType.number,
        ),
      ],
    ),
    _ => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${t('devotees')} *', style: AppText.body(size: 15, weight: FontWeight.w700)),
        const SizedBox(height: 10),
        PickerField(
          label: t('customer'),
          required: true,
          icon: LucideIcons.users,
          value: str(_families.where((f) => str(f['familyId']) == _familyId).firstOrNull?['familyName']),
          onTap: () async {
            if (_families.isEmpty) {
              Toast.show(t('no_devotees_yet', 'Add a devotee family first'));
              return;
            }
            final f = await showNativePicker<Json>(
              context,
              title: t('customer'),
              options: _families,
              labelOf: (f) => str(f['familyName']),
              selected: _families.where((f) => str(f['familyId']) == _familyId).firstOrNull,
            );
            if (f != null) {
              setState(() {
                _familyId = str(f['familyId']);
                if (str(f['address']).isNotEmpty) _address.text = str(f['address']);
              });
            }
          },
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(onPressed: () => context.go(R.devotees), icon: const Icon(LucideIcons.userPlus, size: 16), label: Text(t('add_new_customer'))),
        ),
        if (!_online) ...[
          AppTextField(controller: _address, label: t('address'), required: true, hint: t('sample_address'), maxLines: 3, minLines: 2),
          const SizedBox(height: 12),
        ],
        AppTextField(controller: _notes, label: t('notes'), hint: t('special_requirements'), maxLines: 4, minLines: 2),
      ],
    ),
  };

  Widget _onlineToggle() => Container(
    padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
    decoration: BoxDecoration(
      color: AppColors.cream.withValues(alpha: .6),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.creamDark),
    ),
    child: Row(
      children: [
        Icon(_online ? LucideIcons.video : LucideIcons.house, color: AppColors.bluntRed),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_online ? t('online', 'Online') : t('onsite', 'Onsite'), style: AppText.body(size: 15, weight: FontWeight.w700)),
              Text(t('online_toggle'), style: AppText.body(size: 12, color: AppColors.mutedForeground)),
            ],
          ),
        ),
        Switch(value: _online, onChanged: (v) => setState(() => _online = v)),
      ],
    ),
  );
}
