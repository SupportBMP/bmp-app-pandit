import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api.dart';
import '../../core/i18n/i18n.dart';
import '../../core/router/routes.dart';
import '../../core/storage/prefs.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/format.dart';
import '../../core/utils/json.dart';
import '../../core/widgets/ui.dart';
import 'template_utils.dart';

/// Status templates gallery: server templates (paged) and the Pandit's saved
/// edits (AllTemplatesScreen.js).
class TemplatesPage extends StatefulWidget {
  const TemplatesPage({super.key});

  @override
  State<TemplatesPage> createState() => _TemplatesPageState();
}

class _TemplatesPageState extends State<TemplatesPage> {
  static const _pageSize = 12;
  String _tab = 'all';
  final List<Json> _all = [];
  List<Json> _saved = [];
  int _page = 0;
  bool _hasMore = true;
  bool _loading = false;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _more();
    _loadSaved();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _more();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _loadSaved() => setState(() => _saved = Prefs.savedTemplates.map(obj).toList());

  Future<void> _more({bool reset = false}) async {
    if (_loading || (!_hasMore && !reset)) return;
    setState(() => _loading = true);
    try {
      final next = reset ? 1 : _page + 1;
      final r = obj(await Api.getActiveTemplates(page: next, limit: _pageSize));
      if (boolOf(r['success'])) {
        final items = objList(r['templates']);
        if (reset) _all.clear();
        _all.addAll(items);
        _page = next;
        _hasMore = items.length == _pageSize;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _open(Json tpl, bool saved) async {
    await context.push(R.templateEditor, extra: {'template': tpl, 'isSaved': saved});
    _loadSaved();
  }

  Future<void> _deleteSaved(Json s) async {
    final ok = await confirmDialog(context, title: t('delete_template', 'Delete saved template?'), confirm: t('delete'), destructive: true);
    if (!ok) return;
    final list = _saved.where((e) => e['savedId'] != s['savedId']).toList();
    await Prefs.setSavedTemplates(list);
    _loadSaved();
  }

  @override
  Widget build(BuildContext context) {
    final saved = _tab == 'saved';
    final data = saved ? _saved : _all;
    return Scaffold(
      backgroundColor: pageBg,
      appBar: appBar(context, t('status_templates', 'Status templates')),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.only(bottom: 12),
            child: FilterTabs(
              items: [('all', t('all')), ('saved', '${t('saved', 'Saved')} (${_saved.length})')],
              selected: _tab,
              onChanged: (v) => setState(() => _tab = v),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => saved ? _loadSaved() : _more(reset: true),
              child: data.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 60),
                        if (_loading && !saved)
                          const AppLoader()
                        else
                          EmptyState(
                            icon: LucideIcons.image,
                            title: saved ? t('no_saved_templates', 'No saved templates yet') : t('no_templates', 'No templates available'),
                            message: saved ? t('saved_templates_hint', 'Edit a template and tap Save to keep it here.') : null,
                          ),
                      ],
                    )
                  : GridView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 10,
                        childAspectRatio: .62,
                      ),
                      itemCount: data.length + (!saved && _loading ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i >= data.length) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                        final tpl = data[i];
                        final local = str(tpl['editedImageUri']).replaceFirst('file://', '');
                        return GestureDetector(
                          onTap: () => _open(tpl, saved),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: AppColors.border),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: saved && local.isNotEmpty && File(local).existsSync()
                                            ? Image.file(File(local), fit: BoxFit.cover)
                                            : NetImage(templateImageUrl(str(tpl['imageUrl']))),
                                      ),
                                    ),
                                    if (saved)
                                      Positioned(
                                        top: 4,
                                        right: 4,
                                        child: GestureDetector(
                                          onTap: () => _deleteSaved(tpl),
                                          child: Container(
                                            padding: const EdgeInsets.all(5),
                                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                            child: const Icon(LucideIcons.trash2, size: 14, color: AppColors.red600),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                str(tpl['name'], 'Untitled'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.body(size: 12, weight: FontWeight.w600),
                              ),
                              if (saved && tpl['savedAt'] != null)
                                Text(fmtDate(tpl['savedAt']), style: AppText.body(size: 10.5, color: AppColors.mutedForeground)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
