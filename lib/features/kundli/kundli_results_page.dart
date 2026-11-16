import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api.dart';
import '../../core/api/api_client.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/json.dart';
import '../../core/widgets/toast.dart';
import '../../core/widgets/ui.dart';
import 'kundli_chart.dart';

/// Kundli results (KundliResultsScreen.js): birth & basic details, Rasi
/// chart (South / North / East), planets, manglik, strength, shadbala,
/// dasha and predictions; new charts can be saved as profiles.
class KundliResultsPage extends StatefulWidget {
  const KundliResultsPage({super.key, this.args});
  final Object? args;

  @override
  State<KundliResultsPage> createState() => _KundliResultsPageState();
}

class _KundliResultsPageState extends State<KundliResultsPage> {
  late final Map _a = (widget.args as Map?) ?? {};
  late final Json _k = obj(_a['kundliData']);
  late final bool _canSave = _a['canSave'] != false;
  bool _saving = false;
  bool _saved = false;
  ChartStyle _style = ChartStyle.south;

  static const _signs = ['Aries', 'Taurus', 'Gemini', 'Cancer', 'Leo', 'Virgo', 'Libra', 'Scorpio', 'Sagittarius', 'Capricorn', 'Aquarius', 'Pisces'];

  Future<void> _save() async {
    final bd = obj(_k['birth_details']);
    final loc = obj(bd['location']);
    setState(() => _saving = true);
    try {
      final r = obj(
        await Api.saveKundliProfile({
          'name': str(bd['name']),
          'gender': bd['gender'],
          'birth_date': bd['date'],
          'birth_time': bd['time'],
          'latitude': loc['latitude'],
          'longitude': loc['longitude'],
          'timezone': bd['timezone'],
          'city': str(loc['city']),
        }),
      );
      if (boolOf(r['success'])) {
        setState(() => _saved = true);
        Toast.success('Kundli profile saved successfully');
        if (mounted) context.go(R.home);
        if (mounted) context.push(R.kundliProfiles);
      } else {
        Toast.error(str(r['message'], 'Failed to save'));
      }
    } catch (e) {
      Toast.error(apiError(e, 'Failed to save'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_k.isEmpty)
      return Scaffold(
        appBar: appBar(context, 'Kundli results'),
        body: const EmptyState(title: 'No Kundli data'),
      );
    final bd = obj(_k['birth_details']);
    final basic = obj(_k['basic_details']);
    final planets = objList(_k['planetary_positions']);
    final manglik = obj(_k['manglik_dosha']);
    final predictions = obj(_k['predictions']);
    final dasha = obj(_k['vimshottari_dasha']);
    final ca = obj(_k['chart_analysis']);
    final sb = obj(_k['shadbala']);
    final asc = _signs.indexOf(str(pick(basic, ['ascendant', 'sign']))).clamp(0, 11);

    return Scaffold(
      backgroundColor: pageBg,
      appBar: appBar(context, str(bd['name']).isNotEmpty ? "${str(bd['name'])}'s Kundli" : 'Kundli results'),
      bottomNavigationBar: _canSave && !_saved
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: AppButton(label: 'Save Kundli', icon: LucideIcons.bookmarkPlus, loading: _saving, onPressed: _save),
              ),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section(
            'Birth details',
            LucideIcons.user,
            open: true,
            rows: {
              'Name': bd['name'],
              'Gender': bd['gender'],
              'Date': bd['date'],
              'Time': bd['time'],
              'City': pick(bd, ['location', 'city']),
              'Timezone': bd['timezone'],
            },
          ),
          _section(
            'Basic details',
            LucideIcons.compass,
            open: true,
            rows: {
              'Ascendant (Lagna)': pick(basic, ['ascendant', 'sign']),
              'Asc nakshatra': pick(basic, ['ascendant', 'nakshatra']),
              'Moon sign (Rashi)': pick(basic, ['moon_sign', 'sign']),
              'Moon nakshatra': pick(basic, ['moon_sign', 'nakshatra']),
              'Nakshatra pada': pick(basic, ['moon_sign', 'nakshatra_pada']),
              'Nakshatra lord': pick(basic, ['moon_sign', 'nakshatra_lord']),
            },
          ),
          AppCard(
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: [
                SegmentedButton<ChartStyle>(
                  segments: const [
                    ButtonSegment(value: ChartStyle.south, label: Text('South')),
                    ButtonSegment(value: ChartStyle.north, label: Text('North')),
                    ButtonSegment(value: ChartStyle.east, label: Text('East')),
                  ],
                  selected: {_style},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _style = s.first),
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: AppColors.bluntRed.withValues(alpha: .1),
                    selectedForegroundColor: AppColors.bluntRed,
                  ),
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (_, c) => RasiChart(planets: planets, ascendant: asc, style: _style, size: c.maxWidth),
                ),
              ],
            ),
          ),
          _section(
            'Planetary positions',
            LucideIcons.globe,
            children: [
              for (final p in planets)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 84,
                        child: Text(str(p['name']), style: AppText.body(size: 14, weight: FontWeight.w700)),
                      ),
                      Expanded(child: Text('${str(p['sign'])} ${numOf(p['degrees_in_sign']).toStringAsFixed(2)}°', style: AppText.body(size: 13))),
                      Expanded(
                        child: Text(str(p['nakshatra']), style: AppText.body(size: 13, color: AppColors.mutedForeground)),
                      ),
                      if (boolOf(p['is_retrograde'])) const StatusBadge('pending', label: 'R'),
                    ],
                  ),
                ),
            ],
          ),
          _section(
            'Manglik dosha',
            LucideIcons.triangleAlert,
            rows: {
              'Is Manglik': boolOf(manglik['is_manglik']) ? 'Yes' : 'No',
              'Severity': manglik['severity'],
              'Mars house (from Asc)': manglik['mars_house_from_ascendant'],
              'Mars house (from Moon)': manglik['mars_house_from_moon'],
              if (list(manglik['cancellation_reasons']).isNotEmpty) 'Cancellations': list(manglik['cancellation_reasons']).join(', '),
              'Recommendation': manglik['recommendation'],
            },
          ),
          _section(
            'Chart strength',
            LucideIcons.chartColumn,
            rows: {
              'Score': pick(ca, ['strength', 'score']) == null ? null : '${str(pick(ca, ['strength', 'score']))}/100',
              'Rating': pick(ca, ['strength', 'rating']),
              'Exalted planets': _join(pick(ca, ['strength', 'exalted_planets'])),
              'Own sign planets': _join(pick(ca, ['strength', 'own_sign_planets'])),
              'Raja yogas': _join(pick(ca, ['strength', 'raja_yogas'])),
              'Dominant element': pick(ca, ['dominant_elements', 'dominant']),
              'Yogakaraka': pick(ca, ['key_planets', 'yogakaraka']),
              'Atmakaraka': pick(ca, ['key_planets', 'atmakaraka']),
            },
          ),
          if (obj(sb['planets']).isNotEmpty)
            _section(
              'Shadbala (planetary strength)',
              LucideIcons.zap,
              children: [
                Text(
                  '${str(pick(sb, ['summary', 'sufficient_count']))}/${str(pick(sb, ['summary', 'total_planets']))} planets have sufficient strength. '
                  'Strongest: ${str(sb['strongest_planet'])}, Weakest: ${str(sb['weakest_planet'])}.',
                  style: AppText.body(size: 13, color: AppColors.mutedForeground, height: 1.4),
                ),
                const SizedBox(height: 8),
                for (final e in obj(sb['planets']).entries) _ShadbalaRow(name: e.key, data: obj(e.value)),
              ],
            ),
          _section(
            'Vimshottari dasha',
            LucideIcons.clock,
            rows: {
              'Current mahadasha': pick(dasha, ['mahadasha', 'planet']),
              'Mahadasha duration': pick(dasha, ['mahadasha', 'total_years']) == null ? null : '${str(pick(dasha, ['mahadasha', 'total_years']))} years',
              'Balance': pick(dasha, ['mahadasha', 'balance_years']) == null
                  ? null
                  : '${numOf(pick(dasha, ['mahadasha', 'balance_years'])).toStringAsFixed(1)} years',
              'Current antardasha': pick(dasha, ['antardasha', 'planet']),
              'Antardasha balance': pick(dasha, ['antardasha', 'balance_years']) == null
                  ? null
                  : '${numOf(pick(dasha, ['antardasha', 'balance_years'])).toStringAsFixed(2)} years',
            },
          ),
          for (final e in predictions.entries)
            _section(
              e.key[0].toUpperCase() + e.key.substring(1),
              switch (e.key) {
                'personality' => LucideIcons.smile,
                'career' => LucideIcons.briefcase,
                'finance' => LucideIcons.wallet,
                'relationships' => LucideIcons.heart,
                'health' => LucideIcons.activity,
                'education' => LucideIcons.bookOpen,
                _ => LucideIcons.sun,
              },
              children: [
                if (str(obj(e.value)['summary']).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(str(obj(e.value)['summary']), style: AppText.body(size: 14, height: 1.5)),
                  ),
                for (final x in obj(e.value).entries.where((x) => x.key != 'summary'))
                  _row(
                    x.key.replaceAll('_', ' ').replaceAllMapped(RegExp(r'\b\w'), (m) => m[0]!.toUpperCase()),
                    x.value is List ? (list(x.value).isEmpty ? 'None' : list(x.value).join(', ')) : x.value,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  static String? _join(dynamic v) => v is List ? (v.isEmpty ? 'None' : v.join(', ')) : (v == null ? null : str(v));

  Widget _section(String title, IconData icon, {bool open = false, Map<String, dynamic>? rows, List<Widget>? children}) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: open,
        shape: const Border(),
        leading: Icon(icon, size: 20, color: AppColors.bluntRed),
        title: Text(title, style: AppText.body(size: 15, weight: FontWeight.w700)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (rows != null)
            for (final e in rows.entries)
              if (e.value != null && str(e.value).isNotEmpty) _row(e.key, e.value),
          ...?children,
        ],
      ),
    ),
  );

  Widget _row(String k, dynamic v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(k, style: AppText.body(size: 13, color: AppColors.mutedForeground)),
        ),
        Expanded(
          child: Text(v is String || v is num || v is bool ? str(v) : (v == null ? '' : v.toString()), style: AppText.body(size: 14, weight: FontWeight.w600)),
        ),
      ],
    ),
  );
}

class _ShadbalaRow extends StatefulWidget {
  const _ShadbalaRow({required this.name, required this.data});
  final String name;
  final Json data;

  @override
  State<_ShadbalaRow> createState() => _ShadbalaRowState();
}

class _ShadbalaRowState extends State<_ShadbalaRow> {
  bool _open = false;

  static const _ratingColors = {
    'Very Strong': Color(0xFF27AE60),
    'Strong': Color(0xFF2ECC71),
    'Moderate': Color(0xFFF39C12),
    'Weak': Color(0xFFE67E22),
    'Very Weak': Color(0xFFE74C3C),
  };

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final req = numOf(d['required_virupas'], 1);
    final pct = (numOf(d['total_virupas']) / (req == 0 ? 1 : req)).clamp(0, 1).toDouble();
    final ok = boolOf(d['is_sufficient']);
    Widget bar(String l, num v, num max) {
      final p = (v / max).clamp(0, 1).toDouble();
      final c = p >= .7
          ? const Color(0xFF27AE60)
          : p >= .5
          ? const Color(0xFF2ECC71)
          : p >= .3
          ? const Color(0xFFF39C12)
          : const Color(0xFFE74C3C);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              child: Text(l, style: AppText.body(size: 12, color: AppColors.mutedForeground)),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: p, minHeight: 6, color: c, backgroundColor: AppColors.gray100),
              ),
            ),
            SizedBox(
              width: 44,
              child: Text(v.toStringAsFixed(1), textAlign: TextAlign.right, style: AppText.body(size: 12)),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: () => setState(() => _open = !_open),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(widget.name, style: AppText.body(size: 14, weight: FontWeight.w700)),
                ),
                Text(
                  str(d['rating']),
                  style: AppText.body(size: 12, weight: FontWeight.w700, color: _ratingColors[str(d['rating'])] ?? AppColors.gray500),
                ),
                Icon(_open ? LucideIcons.chevronUp : LucideIcons.chevronDown, size: 16),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                color: ok ? const Color(0xFF27AE60) : const Color(0xFFE74C3C),
                backgroundColor: AppColors.gray100,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${str(d['total_rupas'])} Rupas (${str(d['total_virupas'])} / ${str(d['required_virupas'])} Virupas)',
              style: AppText.body(size: 12, color: AppColors.mutedForeground),
            ),
            if (_open) ...[
              const SizedBox(height: 6),
              bar('Sthana', numOf(d['sthana_bala']), 180),
              bar('Dig', numOf(d['dig_bala']), 60),
              bar('Kala', numOf(d['kala_bala']), 180),
              bar('Chesta', numOf(d['chesta_bala']), 60),
              bar('Naisargika', numOf(d['naisargika_bala']), 60),
              bar('Drik', numOf(d['drik_bala']), 60),
            ],
          ],
        ),
      ),
    );
  }
}
