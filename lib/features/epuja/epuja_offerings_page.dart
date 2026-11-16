import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api.dart';
import '../../core/api/api_client.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/format.dart';
import '../../core/utils/json.dart';
import '../../core/widgets/toast.dart';
import '../../core/widgets/ui.dart';

/// Sankalpa settings + bookings and offerings for one e-puja
/// (EPujaOfferingsScreen.js).
class EPujaOfferingsPage extends StatefulWidget {
  const EPujaOfferingsPage({super.key, this.args});
  final Object? args;

  @override
  State<EPujaOfferingsPage> createState() => _EPujaOfferingsPageState();
}

class _EPujaOfferingsPageState extends State<EPujaOfferingsPage> {
  late final String _id = str((widget.args as Map?)?['eventId']);
  String _tab = 'sankalpa';
  Json? _offerings;
  Json? _event;
  List<Json> _bookings = [];
  num _bookingsTotal = 0;
  bool _loadingOff = true, _loadingSan = true, _errOff = false, _errSan = false, _saving = false;

  bool _enabled = false, _requireNotes = false;
  final _price = TextEditingController(), _max = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadOfferings();
    _loadSankalpa();
  }

  @override
  void dispose() {
    _price.dispose();
    _max.dispose();
    super.dispose();
  }

  Future<void> _loadOfferings() async {
    setState(() => _errOff = false);
    try {
      _offerings = obj(await Api.getEPoojaOfferings(_id));
    } catch (_) {
      _errOff = true;
    }
    if (mounted) setState(() => _loadingOff = false);
  }

  Future<void> _loadSankalpa() async {
    setState(() => _errSan = false);
    try {
      final r = await Future.wait([Api.getEPoojaEventById(_id), Api.getEPoojaSankalpaBookings(_id)]);
      _event = obj(r[0]);
      final s = obj(_event!['sankalpa']);
      _enabled = boolOf(s['enabled']);
      _requireNotes = boolOf(s['requireNotes']);
      _price.text = str(s['price'], '0');
      _max.text = str(s['maxCount'], '0');
      final b = obj(r[1]);
      _bookings = objList(b['bookings']);
      _bookingsTotal = numOf(b['totalAmount']);
    } catch (_) {
      _errSan = true;
    }
    if (mounted) setState(() => _loadingSan = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await Api.updateEPoojaSankalpa(_id, {
        'enabled': _enabled,
        'price': num.tryParse(_price.text) ?? 0,
        'requireNotes': _requireNotes,
        'maxCount': (int.tryParse(_max.text) ?? 0).clamp(0, 1 << 30),
      });
      Toast.success(t('sankalpa_saved', 'Sankalpa settings saved'));
      _loadSankalpa();
    } catch (e) {
      Toast.error(apiError(e, 'Failed to save sankalpa settings'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _refresh() => Future.wait([_loadOfferings(), _loadSankalpa()]);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: pageBg,
    appBar: appBar(context, t('epuja_offerings', 'ePuja offerings'), subtitle: _event == null ? null : str(_event!['poojaTitle'])),
    body: Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.only(bottom: 12),
          child: FilterTabs(
            items: [('sankalpa', 'Sankalpa'), ('offerings', t('offerings', 'Offerings'))],
            selected: _tab,
            onChanged: (v) => setState(() => _tab = v),
          ),
        ),
        Expanded(
          child: RefreshIndicator(color: AppColors.bluntRed, onRefresh: _refresh, child: _tab == 'sankalpa' ? _sankalpa() : _offeringsView()),
        ),
      ],
    ),
  );

  Widget _sankalpa() {
    if (_loadingSan) return const AppLoader();
    if (_errSan) return ErrorState(onRetry: _loadSankalpa);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionTitle('Sankalpa', icon: LucideIcons.scrollText),
              const SizedBox(height: 6),
              Text(
                t('sankalpa_note', 'Name and Gothra are always required for sankalpa. Only notes can be optional.'),
                style: AppText.body(size: 13, color: AppColors.mutedForeground, height: 1.4),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t('enable_sankalpa', 'Enable sankalpa'), style: AppText.body(size: 15, weight: FontWeight.w600)),
                value: _enabled,
                onChanged: (v) => setState(() => _enabled = v),
              ),
              if (_enabled) ...[
                AppTextField(
                  controller: _price,
                  label: t('price_per_sankalpa', 'Price per sankalpa (₹)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  prefix: const Icon(LucideIcons.indianRupee, size: 18),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t('require_notes', 'Require notes'), style: AppText.body(size: 15, weight: FontWeight.w600)),
                  value: _requireNotes,
                  onChanged: (v) => setState(() => _requireNotes = v),
                ),
                AppTextField(
                  controller: _max,
                  label: t('max_sankalpa', 'Maximum sankalpas (0 = no limit)'),
                  digitsOnly: true,
                  keyboardType: TextInputType.number,
                ),
                if (_bookings.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Min: ${_bookings.length} (current bookings). You can set max to this or more.',
                      style: AppText.body(size: 12, color: AppColors.mutedForeground),
                    ),
                  ),
              ],
              const SizedBox(height: 16),
              AppButton(label: t('save_sankalpa', 'Save sankalpa'), loading: _saving, icon: LucideIcons.save, onPressed: _save),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(children: [_stat('${_bookings.length}', t('bookings')), const SizedBox(width: 8), _stat(inr(_bookingsTotal), t('amount'))]),
        const SizedBox(height: 16),
        SectionTitle('${t('sankalpa_bookings', 'Sankalpa bookings')} (${_bookings.length})'),
        const SizedBox(height: 10),
        if (_bookings.isEmpty) EmptyState(compact: true, icon: LucideIcons.scrollText, title: t('no_sankalpa', 'No sankalpa bookings yet')),
        for (final b in _bookings)
          AppCard(
            margin: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(str(b['nameForSankalpa']), style: AppText.body(size: 15, weight: FontWeight.w700)),
                    ),
                    numOf(b['amount']) > 0 ? StatusBadge('paid', label: '₹${numOf(b['amount'])}') : const StatusBadge('free', label: 'Free'),
                  ],
                ),
                Text('Gothra: ${str(b['gothra'])}', style: AppText.body(size: 13, color: AppColors.mutedForeground)),
                Text('${t('booked_by', 'Booked by')}: ${str(b['name'])} · ${str(b['phone'])}', style: AppText.body(size: 12, color: AppColors.mutedForeground)),
                if (str(b['notes']).isNotEmpty) ...[const SizedBox(height: 6), Text(str(b['notes']), style: AppText.body(size: 13, height: 1.4))],
              ],
            ),
          ),
      ],
    );
  }

  Widget _stat(String v, String l) => Expanded(
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

  Widget _offeringsView() {
    if (_loadingOff) return const AppLoader();
    if (_errOff) return ErrorState(onRetry: _loadOfferings);
    final o = _offerings ?? {};
    final items = objList(o['offerings']);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            _stat(str(o['totalOfferings'], '0'), t('total', 'Total')),
            const SizedBox(width: 8),
            _stat(str(o['paidOfferings'], '0'), t('paid')),
            const SizedBox(width: 8),
            _stat('₹${str(o['totalAmount'], '0')}', t('amount')),
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
                      if (str(x['phone']).isNotEmpty)
                        GestureDetector(
                          onLongPress: () => Clipboard.setData(ClipboardData(text: str(x['phone']))),
                          child: Text(str(x['phone']), style: AppText.body(size: 13, color: AppColors.mutedForeground)),
                        ),
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
}
