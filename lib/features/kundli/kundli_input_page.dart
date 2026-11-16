import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api.dart';
import '../../core/api/api_client.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/format.dart';
import '../../core/utils/json.dart';
import '../../core/utils/timezone.dart';
import '../../core/widgets/native.dart';
import '../../core/widgets/places_field.dart';
import '../../core/widgets/toast.dart';
import '../../core/widgets/ui.dart';

const _timezones = [
  'Asia/Kolkata',
  'Asia/Colombo',
  'Asia/Kathmandu',
  'Asia/Dhaka',
  'Asia/Karachi',
  'Asia/Dubai',
  'Asia/Singapore',
  'Asia/Kuala_Lumpur',
  'Asia/Hong_Kong',
  'Asia/Tokyo',
  'Asia/Shanghai',
  'Asia/Bangkok',
  'Asia/Jakarta',
  'Europe/London',
  'Europe/Berlin',
  'Europe/Paris',
  'Europe/Moscow',
  'America/New_York',
  'America/Chicago',
  'America/Denver',
  'America/Los_Angeles',
  'America/Toronto',
  'America/Vancouver',
  'Australia/Sydney',
  'Australia/Melbourne',
  'Pacific/Auckland',
  'Africa/Nairobi',
  'Africa/Johannesburg',
];

/// Birth details → generate Kundli (KundliInputScreen.js).
class KundliInputPage extends StatefulWidget {
  const KundliInputPage({super.key, this.args});
  final Object? args;

  @override
  State<KundliInputPage> createState() => _KundliInputPageState();
}

class _KundliInputPageState extends State<KundliInputPage> {
  final _name = TextEditingController();
  String _gender = 'male';
  DateTime? _date;
  TimeOfDay _time = const TimeOfDay(hour: 12, minute: 0);
  String _tz = 'Asia/Kolkata';
  String _city = '';
  double? _lat, _lng;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    deviceTimezone().then((v) => mounted ? setState(() => _tz = v) : null);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_date == null) return Toast.error('Please select a birth date.');
    if (_city.isEmpty || _lat == null || _lng == null) return Toast.error('Please select a birth city from the suggestions to get coordinates.');
    setState(() => _loading = true);
    try {
      final r = obj(
        await Api.generateKundli({
          if (_name.text.trim().isNotEmpty) 'name': _name.text.trim(),
          'gender': _gender,
          'birth_date': ymd(_date!),
          'birth_time': '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}:00',
          'latitude': _lat,
          'longitude': _lng,
          'timezone': _tz,
          'city': _city,
        }),
      );
      if (boolOf(r['success']) && r['data'] != null) {
        if (mounted) context.push(R.kundliResults, extra: {'kundliData': r['data'], 'canSave': true});
      } else {
        Toast.error(str(r['message'], 'Failed to generate Kundli'));
      }
    } catch (e) {
      Toast.error(apiError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: pageBg,
    appBar: appBar(context, 'Generate Kundli'),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionTitle('Birth details', icon: LucideIcons.baby),
              const SizedBox(height: 16),
              AppTextField(controller: _name, label: 'Name', hint: 'Enter name', textCapitalization: TextCapitalization.words),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'male', label: Text('Male')),
                  ButtonSegment(value: 'female', label: Text('Female')),
                ],
                selected: {_gender},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _gender = s.first),
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: AppColors.bluntRed.withValues(alpha: .1),
                  selectedForegroundColor: AppColors.bluntRed,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: PickerField(
                      label: 'Birth date',
                      required: true,
                      icon: LucideIcons.calendar,
                      value: _date == null ? null : fmtDate(_date, 'd MMM yyyy'),
                      onTap: () async {
                        final d = await showNativeDatePicker(
                          context,
                          initialDate: _date ?? DateTime(2000),
                          firstDate: DateTime(1940),
                          lastDate: DateTime.now(),
                          title: 'Birth date',
                        );
                        if (d != null) setState(() => _date = d);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PickerField(
                      label: 'Birth time',
                      required: true,
                      icon: LucideIcons.clock,
                      value: _time.format(context),
                      onTap: () async {
                        final r = await showTimePicker(context: context, initialTime: _time);
                        if (r != null) setState(() => _time = r);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              PickerField(
                label: 'Timezone',
                required: true,
                icon: LucideIcons.globe,
                value: _tz,
                onTap: () async {
                  final opts = {..._timezones, _tz}.toList();
                  final v = await showNativePicker<String>(context, title: 'Timezone', options: opts, labelOf: (e) => e, selected: _tz);
                  if (v != null) setState(() => _tz = v);
                },
              ),
              const SizedBox(height: 12),
              PlacesField(
                label: 'Birth city',
                required: true,
                citiesOnly: true,
                hint: 'Search your birth city',
                onChanged: (v) => setState(() {
                  _city = v;
                  _lat = null;
                  _lng = null;
                }),
                onSelected: (p) => setState(() {
                  _city = p.city ?? p.description;
                  _lat = p.lat;
                  _lng = p.lng;
                }),
              ),
              if (_lat != null && _lng != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: InfoRow(icon: LucideIcons.locateFixed, text: '${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)}', color: AppColors.green700),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        AppButton(label: 'Generate Kundli', icon: LucideIcons.sparkles, loading: _loading, onPressed: _generate),
        const SizedBox(height: 8),
        Text(
          'Your details are used only to compute the chart.',
          textAlign: TextAlign.center,
          style: AppText.body(size: 12, color: AppColors.mutedForeground),
        ),
      ],
    ),
  );
}
