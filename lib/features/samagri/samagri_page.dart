import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
import '../../core/widgets/toast.dart';
import '../../core/widgets/ui.dart';

const samagriIconBase = 'https://mob-app-assets-p.s3.ap-south-1.amazonaws.com/icons/';

/// The item's name in the current language (`item.name[lang] || name.en`).
String samagriName(Json item) {
  final n = item['name'];
  if (n is Map) return str(n[I18n.code], str(n['en']));
  return str(n, str(item['name_en']));
}

Future<void> shareSamagriList(String listId, String panditId) {
  final url = '${Env.webBaseUrl}/list?listId=${Uri.encodeComponent(listId)}&panditId=${Uri.encodeComponent(panditId)}';
  return SharePlus.instance.share(ShareParams(title: 'Please go through the list', text: 'Please go through the list: $url'));
}

/// Samagri (puja items) lists (Samagri.js).
class SamagriPage extends StatefulWidget {
  const SamagriPage({super.key});

  @override
  State<SamagriPage> createState() => _SamagriPageState();
}

class _SamagriPageState extends State<SamagriPage> {
  List<Json> _lists = [];
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = false);
    try {
      _lists = objList(obj(await Api.getSamagriLists())['data']);
    } catch (_) {
      _error = true;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _create() async {
    final c = TextEditingController();
    var saving = false;
    await showAppSheet<void>(
      context,
      title: t('create_samagri_list'),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(controller: c, label: t('name_of_puja'), hint: t('puja_name'), required: true, autofocus: true),
              const SizedBox(height: 20),
              AppButton(
                label: t('create'),
                loading: saving,
                onPressed: () async {
                  final title = c.text.trim();
                  if (title.isEmpty) return;
                  set(() => saving = true);
                  try {
                    final d = obj(obj(await Api.createSamagriList({'title': title}))['data']);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (str(d['_id']).isNotEmpty && mounted) {
                      await context.push(R.samagriAddItems, extra: {'samagriId': str(d['_id']), 'title': title});
                      _load();
                    }
                  } catch (e) {
                    Toast.error(apiError(e));
                    set(() => saving = false);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _delete(Json l) async {
    final ok = await confirmDialog(
      context,
      title: t('delete_samagri_list'),
      message: '${t('confirm_delete')} ${str(l['title'])}? ${t('delete_warning')}.',
      confirm: t('delete'),
      destructive: true,
    );
    if (!ok) return;
    try {
      await Api.deleteSamagriList(str(l['_id']));
      Toast.success(t('list_deleted', 'List deleted'));
      _load();
    } catch (e) {
      Toast.error(apiError(e, t('delete_list_error')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: pageBg,
    appBar: appBar(context, t('create_samagri_list'), subtitle: t('start_a_new_list_or_use_a_saved_template')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _create,
      backgroundColor: AppColors.bluntRed,
      foregroundColor: Colors.white,
      icon: const Icon(LucideIcons.plus),
      label: Text(
        t('create_new_list'),
        style: AppText.body(size: 15, weight: FontWeight.w700, color: Colors.white),
      ),
    ),
    body: _loading
        ? const AppLoader()
        : _error
        ? ErrorState(onRetry: _load)
        : RefreshIndicator(
            onRefresh: _load,
            child: _lists.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 80),
                      EmptyState(
                        icon: LucideIcons.package,
                        title: t('no_samagri_lists', 'No samagri lists yet'),
                        message: t('samagri_empty_hint', 'Create a list of puja items and share it with devotees.'),
                        action: t('create_new_list'),
                        onAction: _create,
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    itemCount: _lists.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final l = _lists[i];
                      return AppCard(
                        onTap: () async {
                          await context.push(R.samagriList, extra: {'samagriId': str(l['_id']), 'panditId': str(l['panditId'])});
                          _load();
                        },
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: AppColors.cream, borderRadius: BorderRadius.circular(14)),
                              child: const Icon(LucideIcons.package, color: AppColors.bluntRed),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(str(l['title'], 'Untitled'), style: AppText.body(size: 16, weight: FontWeight.w700)),
                                  Text(
                                    '${list(l['items']).length} ${t('items', 'items')}${l['updatedAt'] != null ? ' · ${fmtDate(l['updatedAt'])}' : ''}',
                                    style: AppText.body(size: 13, color: AppColors.mutedForeground),
                                  ),
                                ],
                              ),
                            ),
                            IconPill(icon: LucideIcons.share2, size: 36, onTap: () => shareSamagriList(str(l['_id']), str(l['panditId']))),
                            const SizedBox(width: 6),
                            IconPill(icon: LucideIcons.trash2, size: 36, color: AppColors.red600, onTap: () => _delete(l)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
  );
}
