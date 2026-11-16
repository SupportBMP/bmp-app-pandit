import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api.dart';
import '../../core/api/api_client.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/json.dart';
import '../../core/widgets/toast.dart';
import '../../core/widgets/ui.dart';
import 'samagri_add_items_page.dart';
import 'samagri_page.dart';

/// Edit a samagri list (SamagriList.js): rename, search & add items (pandit
/// or customer brings), edit quantity, switch side, remove, save, share.
class SamagriListPage extends StatefulWidget {
  const SamagriListPage({super.key, this.args});
  final Object? args;

  @override
  State<SamagriListPage> createState() => _SamagriListPageState();
}

class _SamagriListPageState extends State<SamagriListPage> {
  late final Map _a = (widget.args as Map?) ?? {};
  late final String _id = str(_a['samagriId']);
  late String _panditId = str(_a['panditId']);
  String _title = '';
  List<Json> _items = [];
  List<Json> _results = [];
  String _tab = 'pandit';
  bool _loading = true;
  bool _saving = false;
  bool _dirty = false;
  Timer? _debounce;
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = obj(obj(await Api.getSamagriListById(_id, I18n.code))['data']);
      var n = 0;
      _title = str(d['title'], 'Untitled');
      _items = objList(d['items']).map((e) => {...e, 'entryId': 'entry-${n++}-${DateTime.now().microsecondsSinceEpoch}'}).toList();
      if (_panditId.isEmpty) _panditId = str(d['panditId']);
      _dirty = false;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    if (v.trim().isEmpty) return setState(() => _results = []);
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final r = objList(obj(await Api.searchSamagri(text: v.trim(), lang: I18n.code))['data']);
        if (mounted) setState(() => _results = r);
      } catch (_) {}
    });
  }

  void _add(Json item, String from) => setState(() {
    _items.add({
      'entryId': 'entry-temp-${DateTime.now().microsecondsSinceEpoch}',
      'samagriId': item['_id'],
      'from': from,
      'quantityText': '',
      'imageUrl': item['imageUrl'],
      'name_en': pick(item, ['name', 'en']),
      'name': samagriName(item),
    });
    _tab = from;
    _results = [];
    _search.clear();
    _dirty = true;
  });

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await Api.addSamagriListItems(_id, {'data': _items});
      Toast.success(t('list_updated_successfully', 'List updated successfully'));
      await _load();
    } catch (e) {
      Toast.error(apiError(e, 'Error updating lists'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _rename() async {
    final c = TextEditingController(text: _title);
    final v = await showAppSheet<String>(
      context,
      title: t('title_of_list'),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(controller: c, label: t('title_of_list'), autofocus: true),
            const SizedBox(height: 16),
            AppButton(label: t('save'), onPressed: () => Navigator.pop(ctx, c.text.trim())),
          ],
        ),
      ),
    );
    if (v == null || v.isEmpty) return;
    try {
      final d = obj(obj(await Api.updateSamagriListTitle(_id, {'title': v}))['data']);
      setState(() => _title = str(d['title'], v));
      Toast.success(t('title_updated', 'Title updated successfully'));
    } catch (e) {
      Toast.error(apiError(e, 'Error updating title'));
    }
  }

  Future<void> _editQty(Json it) async {
    final c = TextEditingController(text: str(it['quantityText']));
    final v = await showAppSheet<String>(
      context,
      title: str(it['name']),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(controller: c, label: t('quantity'), hint: t('quantity_placeholder'), autofocus: true),
            const SizedBox(height: 16),
            AppButton(label: t('save'), onPressed: () => Navigator.pop(ctx, c.text.trim())),
          ],
        ),
      ),
    );
    if (v != null && v.isNotEmpty) {
      setState(() {
        it['quantityText'] = v;
        _dirty = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = _items.where((i) => str(i['from']) == _tab).toList();
    final pandit = _items.where((i) => str(i['from']) == 'pandit').length;
    return Scaffold(
      backgroundColor: pageBg,
      appBar: appBar(
        context,
        _title.isEmpty ? t('samagri', 'Samagri') : _title,
        actions: [
          IconButton(onPressed: _rename, icon: const Icon(LucideIcons.pencil, size: 20), tooltip: t('edit')),
          IconButton(onPressed: () => shareSamagriList(_id, _panditId), icon: const Icon(LucideIcons.share2, size: 20), tooltip: t('share')),
        ],
      ),
      body: _loading
          ? const AppLoader()
          : Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Column(
                    children: [
                      TextField(
                        controller: _search,
                        onChanged: _onSearch,
                        decoration: appInputDecoration(hint: t('search_items'), prefix: const Icon(LucideIcons.search, size: 18), dense: true),
                      ),
                      if (_results.isNotEmpty)
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 260),
                          child: ListView(
                            shrinkWrap: true,
                            padding: const EdgeInsets.only(top: 8),
                            children: [
                              for (final r in _results)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: SamagriRow(
                                    item: r,
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextButton(onPressed: () => _add(r, 'pandit'), child: Text('+ ${t('pandit')}')),
                                        TextButton(onPressed: () => _add(r, 'customer'), child: Text('+ ${t('customer')}')),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: FilterTabs(
                    items: [('pandit', '${t('pandit')} ($pandit)'), ('customer', '${t('customer')} (${_items.length - pandit})')],
                    selected: _tab,
                    onChanged: (v) => setState(() => _tab = v),
                  ),
                ),
                Expanded(
                  child: shown.isEmpty
                      ? EmptyState(
                          compact: true,
                          icon: LucideIcons.package,
                          title: t('no_items_yet', 'No items yet'),
                          message: t('search_to_add', 'Search above to add items.'),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: shown.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final it = shown[i];
                            return AppCard(
                              padding: const EdgeInsets.all(10),
                              child: Row(
                                children: [
                                  NetImage(str(it['imageUrl']).isEmpty ? null : '$samagriIconBase${str(it['imageUrl'])}', width: 44, height: 44, radius: 10),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          str(it['name'], str(it['name_en'])),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppText.body(size: 15, weight: FontWeight.w600),
                                        ),
                                        GestureDetector(
                                          onTap: () => _editQty(it),
                                          child: Text(
                                            str(it['quantityText']).isEmpty ? t('tap_to_add_quantity') : str(it['quantityText']),
                                            style: AppText.body(
                                              size: 13,
                                              color: str(it['quantityText']).isEmpty ? AppColors.bluntRed : AppColors.mutedForeground,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(onPressed: () => _editQty(it), icon: const Icon(LucideIcons.pencil, size: 18)),
                                  IconButton(
                                    tooltip: t('switch', 'Switch'),
                                    onPressed: () => setState(() {
                                      it['from'] = str(it['from']) == 'pandit' ? 'customer' : 'pandit';
                                      _dirty = true;
                                    }),
                                    icon: const Icon(LucideIcons.arrowLeftRight, size: 18),
                                  ),
                                  IconButton(
                                    onPressed: () => setState(() {
                                      _items.remove(it);
                                      _dirty = true;
                                    }),
                                    icon: const Icon(LucideIcons.trash2, size: 18, color: AppColors.red600),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: AppColors.border)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            label: t('save'),
                            kind: _dirty ? BtnKind.primary : BtnKind.outline,
                            icon: LucideIcons.save,
                            loading: _saving,
                            onPressed: _save,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AppButton(
                            label: t('share'),
                            kind: BtnKind.secondary,
                            icon: LucideIcons.share2,
                            onPressed: () => shareSamagriList(_id, _panditId),
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
}
