import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api.dart';
import '../../core/api/api_client.dart';
import '../../core/i18n/i18n.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/json.dart';
import '../../core/widgets/toast.dart';
import '../../core/widgets/ui.dart';

/// Saved Kundli profiles (KundliProfilesScreen.js). Tap regenerates the chart.
class KundliProfilesPage extends StatefulWidget {
  const KundliProfilesPage({super.key});

  @override
  State<KundliProfilesPage> createState() => _KundliProfilesPageState();
}

class _KundliProfilesPageState extends State<KundliProfilesPage> {
  List<Json> _profiles = [];
  bool _loading = true;
  String? _generating;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = obj(await Api.getKundliProfiles());
      if (boolOf(r['success'])) _profiles = objList(r['data']);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _open(Json p) async {
    setState(() => _generating = str(p['_id']));
    try {
      final r = obj(
        await Api.generateKundli({
          for (final k in ['name', 'gender', 'birth_date', 'birth_time', 'latitude', 'longitude', 'timezone', 'city']) k: p[k],
        }),
      );
      if (boolOf(r['success']) && r['data'] != null) {
        if (mounted) context.push(R.kundliResults, extra: {'kundliData': r['data'], 'canSave': false});
      } else {
        Toast.error(str(r['message'], 'Failed to generate Kundli'));
      }
    } catch (e) {
      Toast.error(apiError(e));
    } finally {
      if (mounted) setState(() => _generating = null);
    }
  }

  Future<void> _delete(Json p) async {
    final ok = await confirmDialog(
      context,
      title: t('delete_kundli', 'Delete Kundli'),
      message: 'Are you sure you want to delete ${str(p['name'], 'this')} Kundli profile? This action cannot be undone.',
      confirm: t('delete'),
      destructive: true,
    );
    if (!ok) return;
    try {
      await Api.deleteKundliProfile(str(p['_id']));
      setState(() => _profiles.removeWhere((e) => e['_id'] == p['_id']));
    } catch (_) {
      Toast.error('Failed to delete profile');
    }
  }

  String _date(String s) {
    final p = s.split('-');
    return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : s;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: pageBg,
    appBar: appBar(context, t('kundli', 'Kundli')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () async {
        await context.push(R.kundliInput);
        _load();
      },
      backgroundColor: AppColors.bluntRed,
      foregroundColor: Colors.white,
      icon: const Icon(LucideIcons.plus),
      label: Text(
        t('new_kundli', 'New Kundli'),
        style: AppText.body(size: 15, weight: FontWeight.w700, color: Colors.white),
      ),
    ),
    body: _loading
        ? const AppLoader()
        : RefreshIndicator(
            onRefresh: _load,
            child: _profiles.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 80),
                      EmptyState(
                        icon: LucideIcons.sparkles,
                        title: t('no_kundli', 'No saved Kundli yet'),
                        message: 'Create a new Kundli to see birth chart, Shadbala, predictions and more.',
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    itemCount: _profiles.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final p = _profiles[i];
                      final busy = _generating == str(p['_id']);
                      return AppCard(
                        onTap: _generating != null ? null : () => _open(p),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: AppColors.cream, borderRadius: BorderRadius.circular(14)),
                              child: const Icon(LucideIcons.sparkles, color: AppColors.saffronDark),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(str(p['name'], 'Unnamed'), style: AppText.body(size: 16, weight: FontWeight.w700)),
                                  Text(
                                    '${_date(str(p['birth_date']))}${str(p['city']).isEmpty ? '' : '  •  ${str(p['city'])}'}',
                                    style: AppText.body(size: 13, color: AppColors.mutedForeground),
                                  ),
                                  Text(
                                    '${str(p['birth_time'])}${str(p['gender']).isEmpty ? '' : '  •  ${str(p['gender'])}'}',
                                    style: AppText.body(size: 13, color: AppColors.mutedForeground),
                                  ),
                                ],
                              ),
                            ),
                            busy
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                                : IconButton(
                                    onPressed: () => _delete(p),
                                    icon: const Icon(LucideIcons.trash2, size: 18, color: AppColors.red600),
                                  ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
  );
}
