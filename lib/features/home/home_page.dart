import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api.dart';
import '../../core/i18n/i18n.dart';
import '../../core/router/routes.dart';
import '../../core/state/session.dart';
import '../../core/storage/prefs.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/format.dart';
import '../../core/utils/json.dart';
import '../../core/utils/location.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/ui.dart';
import '../templates/template_utils.dart';
import 'panchang_calendar.dart';

/// Dashboard (HomeTab.js): today's stats, panchang calendar, blessing
/// points, quick actions, status templates and today's agenda.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  List<Json> _today = [];
  Json _rewards = {};
  int _devotees = 0;
  List<Json> _templates = [];
  bool _loading = true;
  AppLocation _loc = AppLocation.fallback;
  int _refreshTick = 0;

  @override
  void initState() {
    super.initState();
    _load();
    LocationService.current().then((l) {
      if (mounted) setState(() => _loc = l);
    });
  }

  Future<void> _load() async {
    final today = ymd(DateTime.now());
    await Future.wait<void>([
      Api.getPoojas(date: today).then((v) => _today = objList(v)).catchError((_) => _today),
      Api.getRewardsSummary().then((v) => _rewards = obj(v)).catchError((_) => _rewards),
      Api.getFamiliesCount().then((v) => _devotees = intOf(obj(v)['totalClients'])).catchError((_) => _devotees),
      Api.getActiveTemplates(page: 1, limit: 7)
          .then((v) {
            final r = obj(v);
            if (boolOf(r['success'])) _templates = objList(r['templates']).take(6).toList();
            return _templates;
          })
          .catchError((_) => _templates),
    ]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _refresh() async {
    setState(() => _refreshTick++);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(sessionProvider);
    final earnings = _today.fold<num>(0, (s, p) => s + (str(p['status']).toLowerCase() == 'paid' ? numOf(p['dakshinaAmount']) : 0));

    return Scaffold(
      backgroundColor: pageBg,
      body: RefreshIndicator(
        color: AppColors.bluntRed,
        onRefresh: _refresh,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _header(user, earnings)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              sliver: SliverList.list(
                children: [
                  PanchangCalendar(
                    latitude: _loc.latitude,
                    longitude: _loc.longitude,
                    refreshTick: _refreshTick,
                    onViewDetails: (date) => context.push(R.panchang, extra: {'date': date}),
                  ),
                  const SizedBox(height: 16),
                  _blessings(),
                  const SizedBox(height: 16),
                  _quickActions(),
                  if (_templates.isNotEmpty || Prefs.savedTemplates.isNotEmpty) ...[const SizedBox(height: 16), _statusTemplates()],
                  const SizedBox(height: 16),
                  _agenda(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(Json? user, num earnings) {
    final name = str(user?['name']);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF9A1F27), AppColors.maroonDark]),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                    child: const PanditEmblem(height: 30),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t('hello_pandit'), style: AppText.body(size: 13, color: Colors.white.withValues(alpha: .8))),
                        Text(
                          name.isEmpty ? 'Pandit Ji' : name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.heading(size: 22, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => context.go(R.profile),
                    icon: Avatar(url: str(user?['photoUrl'] ?? user?['profileImage']), name: name, size: 40),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withValues(alpha: .15)),
                ),
                child: Row(
                  children: [
                    _stat(inr(earnings), t('todays_earnings')),
                    _divider(),
                    _stat(_loading ? '–' : '${_today.length}', t('todays_pujas')),
                    _divider(),
                    _stat(_loading ? '–' : '$_devotees', t('total_devotees')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 34, color: Colors.white.withValues(alpha: .2));

  Widget _stat(String v, String label) => Expanded(
    child: Column(
      children: [
        Text(
          v,
          style: AppText.body(size: 20, weight: FontWeight.w700, color: Colors.white),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: AppText.body(size: 11.5, color: Colors.white.withValues(alpha: .8)),
        ),
      ],
    ),
  );

  Widget _blessings() {
    final next = obj(pick(_rewards, ['milestone', 'next']));
    final target = numOf(next['pointsRequired']);
    final needed = numOf(next['pointsNeeded']);
    final progress = target > 0 ? ((target - needed).clamp(0, target) / target).toDouble() : 0.0;
    final current = str(pick(_rewards, ['totals', 'current']), '0');
    final level = str(pick(_rewards, ['milestone', 'current', 'milestoneName']));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(t('blessing_points_status'), icon: LucideIcons.bell),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(current, style: AppText.heading(size: 34, color: AppColors.bluntRed)),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(t('points'), style: AppText.body(size: 14, color: AppColors.mutedForeground)),
              ),
              const Spacer(),
              if (level.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.amber50,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.amber100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.award, size: 14, color: AppColors.amber700),
                      const SizedBox(width: 4),
                      Text(
                        level,
                        style: AppText.body(size: 12, weight: FontWeight.w700, color: AppColors.amber700),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (next.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: progress, minHeight: 8, backgroundColor: AppColors.gray100, color: AppColors.saffron),
            ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '${t('next_level')}: ${str(next['milestoneName'])} · '),
                  TextSpan(
                    text: '${str(next['pointsNeeded'])} ${t('points_remaining')}',
                    style: const TextStyle(color: AppColors.saffronDark, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              style: AppText.body(size: 13, color: AppColors.mutedForeground),
            ),
          ],
          const SizedBox(height: 16),
          Text(t('earn_more_blessings'), style: AppText.body(size: 14, weight: FontWeight.w700)),
          const SizedBox(height: 10),
          _earnTile(LucideIcons.star, t('get_5_feedback'), AppColors.amber600, null),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _earnTile(LucideIcons.video, t('conduct_epuja'), AppColors.saffronDark, () => context.go(R.epuja))),
              const SizedBox(width: 8),
              Expanded(child: _earnTile(LucideIcons.userPlus, t('add_devotee'), AppColors.green600, () => context.go(R.devotees))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _earnTile(IconData icon, String label, Color color, VoidCallback? onTap) => Material(
    color: color.withValues(alpha: .07),
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label, maxLines: 2, style: AppText.body(size: 13, weight: FontWeight.w600)),
            ),
            if (onTap != null) Icon(LucideIcons.chevronRight, size: 14, color: color),
          ],
        ),
      ),
    ),
  );

  Widget _quickActions() {
    Widget action(IconData icon, String label, String sub, VoidCallback onTap) => Expanded(
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.bluntRed.withValues(alpha: .08), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 22, color: AppColors.bluntRed),
            ),
            const SizedBox(height: 12),
            Text(label, style: AppText.body(size: 15, weight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(sub, maxLines: 2, style: AppText.body(size: 12, color: AppColors.mutedForeground)),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(t('quick_actions')),
        const SizedBox(height: 10),
        Row(
          children: [
            action(LucideIcons.package, t('create_samagri'), t('samagri_hint', 'Puja item lists to share'), () => context.push(R.samagri)),
            const SizedBox(width: 12),
            action(LucideIcons.sparkles, t('kundli'), t('kundli_hint', 'Birth charts & matching'), () => context.push(R.kundliProfiles)),
          ],
        ),
      ],
    );
  }

  Widget _statusTemplates() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SectionTitle(t('status_templates', 'Status Templates'), action: t('show_all', 'Show all'), onAction: () => context.push(R.templates)),
      const SizedBox(height: 10),
      SizedBox(
        height: 150,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _templates.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (_, i) {
            final tpl = _templates[i];
            return GestureDetector(
              onTap: () => context.push(R.templateEditor, extra: {'template': tpl}),
              child: Container(
                width: 110,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: NetImage(templateImageUrl(str(tpl['imageUrl'])), radius: 13),
              ),
            );
          },
        ),
      ),
    ],
  );

  Widget _agenda() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(child: SectionTitle(t('todays_agenda'), icon: LucideIcons.clipboardList)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppColors.bluntRed.withValues(alpha: .08), borderRadius: BorderRadius.circular(999)),
            child: Text(
              '${_today.length} ${t('bookings')}',
              style: AppText.body(size: 12, weight: FontWeight.w700, color: AppColors.bluntRed),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      if (_loading)
        const Padding(padding: EdgeInsets.all(24), child: AppLoader(size: 32))
      else if (_today.isEmpty)
        AppCard(
          child: EmptyState(compact: true, icon: LucideIcons.calendarX, title: t('no_pujas_today', 'No pujas today'), message: t('no_data_available')),
        )
      else
        for (final p in _today)
          AppCard(
            margin: const EdgeInsets.only(bottom: 10),
            onTap: () => context.go(R.bookings),
            child: Row(
              children: [
                Container(
                  width: 60,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(color: AppColors.cream, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      const Icon(LucideIcons.clock, size: 16, color: AppColors.bluntRed),
                      const SizedBox(height: 4),
                      Text(
                        to12Hour(str(p['startTime'])),
                        textAlign: TextAlign.center,
                        style: AppText.body(size: 11, weight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        str(p['poojaTitle']),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body(size: 15, weight: FontWeight.w700),
                      ),
                      Text(
                        str(p['familyName']),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body(size: 13, color: AppColors.mutedForeground),
                      ),
                      const SizedBox(height: 2),
                      InfoRow(
                        icon: str(p['poojaType']) == 'online' ? LucideIcons.video : LucideIcons.mapPin,
                        text: str(p['poojaType']) == 'online' ? t('online', 'Online') : str(p['address']),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                StatusBadge(str(p['status'], 'pending')),
              ],
            ),
          ),
    ],
  );
}
