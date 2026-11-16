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
import 'samagri_page.dart';

/// First fill of a new list: tap catalogue items, set quantity and who
/// brings it (SamagriAddItems.js).
class SamagriAddItemsPage extends StatefulWidget {
  const SamagriAddItemsPage({super.key, this.args});
  final Object? args;

  @override
  State<SamagriAddItemsPage> createState() => _SamagriAddItemsPageState();
}

class _SamagriAddItemsPageState extends State<SamagriAddItemsPage> {
  late final Map _a = (widget.args as Map?) ?? {};
  List<Json> _catalogue = [];
  final List<Json> _added = [];
  String _q = '';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    Api.allSamagri(I18n.code).then((v) => _catalogue = objList(obj(v)['data'])).catchError((_) => _catalogue).whenComplete(() {
      if (mounted) setState(() => _loading = false);
    });
  }

  Future<void> _pick(Json item) async {
    final r = await showQuantitySheet(context, samagriName(item));
    if (r == null) return;
    setState(() {
      _added.add({
        'entryId': 'entry-temp-${DateTime.now().microsecondsSinceEpoch}',
        'samagriId': item['_id'],
        'from': r.$2,
        'quantityText': r.$1,
        'imageUrl': item['imageUrl'],
        'name_en': pick(item, ['name', 'en']),
        'name': samagriName(item),
      });
      _catalogue.removeWhere((c) => c['_id'] == item['_id']);
    });
  }

  Future<void> _save() async {
    if (_added.isEmpty) return Toast.error(t('add_at_least_one_item'));
    setState(() => _saving = true);
    try {
      final id = str(_a['samagriId']);
      await Api.addSamagriListItems(id, {'data': _added});
      Toast.success(t('list_updated_successfully'));
      if (mounted) context.pushReplacement(R.samagriList, extra: {'samagriId': id});
    } catch (e) {
      Toast.error(apiError(e, 'Error updating lists'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.toLowerCase();
    final items = _catalogue.where((c) => samagriName(c).toLowerCase().contains(q)).toList();
    return Scaffold(
      backgroundColor: pageBg,
      appBar: appBar(context, str(_a['title'], t('samagri', 'Samagri')), subtitle: '${_added.length} ${t('items_added')}'),
      body: Column(
        children: [
          if (_added.isNotEmpty)
            Container(
              color: Colors.white,
              height: 64,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                scrollDirection: Axis.horizontal,
                itemCount: _added.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => Chip(
                  backgroundColor: AppColors.cream,
                  side: const BorderSide(color: AppColors.creamDark),
                  label: Text('${str(_added[i]['name'])} · ${str(_added[i]['quantityText'])}', style: AppText.body(size: 13, weight: FontWeight.w600)),
                  onDeleted: () => setState(() => _added.removeAt(i)),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: appInputDecoration(hint: t('search_items'), prefix: const Icon(LucideIcons.search, size: 18), dense: true),
            ),
          ),
          Expanded(
            child: _loading
                ? const AppLoader()
                : items.isEmpty
                ? EmptyState(compact: true, icon: LucideIcons.package, title: t('no_items_found', 'No items found'))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => SamagriRow(item: items[i], onTap: () => _pick(items[i])),
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
              child: AppButton(label: t('continue'), loading: _saving, trailingIcon: LucideIcons.arrowRight, onPressed: _save),
            ),
          ),
        ],
      ),
    );
  }
}

class SamagriRow extends StatelessWidget {
  const SamagriRow({super.key, required this.item, this.onTap, this.trailing});
  final Json item;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(10),
    onTap: onTap,
    child: Row(
      children: [
        NetImage(str(item['imageUrl']).isEmpty ? null : '$samagriIconBase${str(item['imageUrl'])}', width: 44, height: 44, radius: 10),
        const SizedBox(width: 12),
        Expanded(
          child: Text(samagriName(item), style: AppText.body(size: 15, weight: FontWeight.w600)),
        ),
        trailing ?? const Icon(LucideIcons.circlePlus, color: AppColors.bluntRed),
      ],
    ),
  );
}

/// Quantity + "who brings it" (pandit / customer). Returns (quantity, from).
Future<(String, String)?> showQuantitySheet(BuildContext context, String name, {String initialFrom = 'pandit'}) {
  final c = TextEditingController();
  var from = initialFrom;
  return showAppSheet<(String, String)>(
    context,
    title: name,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t('who_brings', 'Who brings it?'),
              style: AppText.body(size: 14, weight: FontWeight.w700, color: AppColors.mutedForeground),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'pandit', label: Text(t('pandit'))),
                ButtonSegment(value: 'customer', label: Text(t('customer'))),
              ],
              selected: {from},
              showSelectedIcon: false,
              onSelectionChanged: (s) => set(() => from = s.first),
              style: SegmentedButton.styleFrom(selectedBackgroundColor: AppColors.bluntRed.withValues(alpha: .1), selectedForegroundColor: AppColors.bluntRed),
            ),
            const SizedBox(height: 16),
            AppTextField(controller: c, label: t('quantity'), hint: t('quantity_placeholder'), autofocus: true, maxLines: 2),
            const SizedBox(height: 20),
            AppButton(
              label: t('add'),
              onPressed: () {
                if (c.text.trim().isEmpty) return Toast.error(t('please_enter_quantity'));
                Navigator.pop(ctx, (c.text.trim(), from));
              },
            ),
          ],
        ),
      ),
    ),
  );
}
