import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api/api.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/format.dart';
import '../../core/utils/json.dart';
import '../../core/widgets/media.dart';
import '../../core/widgets/ui.dart';

/// Booking details (PoojaDetailsScreen.js): reviews for onsite pujas;
/// recordings, offerings and reviews for online ones.
class PoojaDetailsPage extends StatefulWidget {
  const PoojaDetailsPage({super.key, this.args});
  final Object? args;

  @override
  State<PoojaDetailsPage> createState() => _PoojaDetailsPageState();
}

class _PoojaDetailsPageState extends State<PoojaDetailsPage> {
  late final Map _a = (widget.args as Map?) ?? {};
  late final String _id = str(_a['poojaId']);
  late final bool _online = str(_a['poojaType']) != 'onsite';
  late String _tab = _online ? 'recordings' : 'reviews';
  List<Json>? _recordings;
  Json? _offerings;
  List<Json>? _reviews;
  bool _loading = false;
  bool _error = false;
  String? _playing;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      if (_tab == 'recordings' && _recordings == null) {
        _recordings = objList(obj(await Api.getRecordingsByPooja(_id))['recordings']);
      } else if (_tab == 'offerings' && _offerings == null) {
        _offerings = obj(await Api.getPoojaOfferings(_id));
      } else if (_tab == 'reviews' && _reviews == null) {
        _reviews = objList(obj(await Api.getPoojaReviews(_id))['reviews']);
      }
    } catch (_) {
      _error = true;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = _online
        ? [('recordings', t('recordings', 'Recordings')), ('offerings', t('offerings', 'Offerings')), ('reviews', t('reviews', 'Reviews'))]
        : [('reviews', t('reviews', 'Reviews'))];
    return Scaffold(
      backgroundColor: pageBg,
      appBar: appBar(context, t('pooja_details', 'Pooja details')),
      body: Column(
        children: [
          if (tabs.length > 1)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.only(bottom: 12),
              child: FilterTabs(
                items: tabs,
                selected: _tab,
                onChanged: (v) {
                  setState(() => _tab = v);
                  _load();
                },
              ),
            ),
          Expanded(
            child: _loading
                ? const AppLoader()
                : _error
                ? ErrorState(
                    onRetry: () {
                      if (_tab == 'recordings') _recordings = null;
                      if (_tab == 'offerings') _offerings = null;
                      if (_tab == 'reviews') _reviews = null;
                      _load();
                    },
                  )
                : switch (_tab) {
                    'recordings' => _recordingsView(),
                    'offerings' => _offeringsView(),
                    _ => _reviewsView(),
                  },
          ),
        ],
      ),
    );
  }

  Widget _recordingsView() {
    final r = _recordings ?? [];
    if (r.isEmpty) return EmptyState(icon: LucideIcons.video, title: t('no_recordings', 'No recordings available'));
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: r.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final x = r[i];
        final id = str(x['_id']);
        final url = str(x['s3Url']);
        return AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                child: _playing == id
                    ? NetVideo(url)
                    : GestureDetector(
                        onTap: () => setState(() => _playing = id),
                        child: Container(
                          height: 180,
                          color: AppColors.maroonDark,
                          child: const Center(child: Icon(LucideIcons.circlePlay, size: 54, color: Colors.white)),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(fmtDate(x['startTime'], 'dd/MM/yyyy'), style: AppText.body(size: 15, weight: FontWeight.w700)),
                          Text('${t('started_at', 'Started at')} ${fmtTime(x['startTime'])}', style: AppText.body(size: 13, color: AppColors.mutedForeground)),
                        ],
                      ),
                    ),
                    IconPill(
                      icon: LucideIcons.share2,
                      onTap: () => SharePlus.instance.share(ShareParams(text: 'Check out this pooja recording: $url', title: 'Pooja Recording')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _offeringsView() {
    final o = _offerings ?? {};
    final items = objList(o['offerings']);
    Widget stat(String v, String l) => Expanded(
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Text(
              v,
              style: AppText.body(size: 18, weight: FontWeight.w800, color: AppColors.bluntRed),
            ),
            Text(l, style: AppText.body(size: 12, color: AppColors.mutedForeground)),
          ],
        ),
      ),
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            stat(str(o['totalOfferings'], '0'), t('total', 'Total')),
            const SizedBox(width: 8),
            stat(str(o['paidOfferings'], '0'), t('paid')),
            const SizedBox(width: 8),
            stat('₹${str(o['totalAmount'], '0')}', t('amount')),
          ],
        ),
        const SizedBox(height: 16),
        if (items.isEmpty) EmptyState(compact: true, icon: LucideIcons.gift, title: t('no_offerings', 'No offerings available')),
        for (final x in items)
          AppCard(
            margin: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Avatar(name: str(x['name']), size: 42),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(str(x['name'], 'Devotee'), style: AppText.body(size: 15, weight: FontWeight.w700)),
                      if (str(x['phone']).isNotEmpty) Text(str(x['phone']), style: AppText.body(size: 13, color: AppColors.mutedForeground)),
                      Text(fmtDate(x['createdAt'], 'dd/MM/yyyy HH:mm'), style: AppText.body(size: 12, color: AppColors.mutedForeground)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${str(x['currency'], 'INR')} ${str(x['amount'])}', style: AppText.body(size: 15, weight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    StatusBadge(str(x['status'], 'pending')),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _reviewsView() {
    final r = _reviews ?? [];
    if (r.isEmpty) return EmptyState(icon: LucideIcons.star, title: t('no_reviews', 'No reviews yet'));
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: r.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final x = r[i];
        final rating = intOf(x['rating']);
        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  for (var s = 1; s <= 5; s++) Icon(Icons.star_rounded, size: 20, color: s <= rating ? AppColors.amber500 : AppColors.gray200),
                  const Spacer(),
                  Text(fmtDate(x['createdAt'], 'dd/MM/yyyy'), style: AppText.body(size: 12, color: AppColors.mutedForeground)),
                ],
              ),
              if (str(x['reviewText']).isNotEmpty) ...[const SizedBox(height: 8), Text(str(x['reviewText']), style: AppText.body(size: 14, height: 1.4))],
            ],
          ),
        );
      },
    );
  }
}
