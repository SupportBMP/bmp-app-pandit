import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api.dart';
import '../../core/api/api_client.dart';
import '../../core/i18n/i18n.dart';
import '../../core/router/routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/json.dart';
import '../../core/utils/phone.dart';
import '../../core/widgets/toast.dart';
import '../../core/widgets/ui.dart';
import '../bookings/booking_widgets.dart' show callPhone, openWhatsApp;

/// Devotee (client family) management (ClientsTab.js): search, add from
/// contacts, edit, delete, call / WhatsApp, and open family members.
class DevoteesPage extends StatefulWidget {
  const DevoteesPage({super.key});

  @override
  State<DevoteesPage> createState() => _DevoteesPageState();
}

class _DevoteesPageState extends State<DevoteesPage> {
  List<Json> _families = [];
  int _services = 0;
  String _q = '';
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
      final r = obj(await Api.getFamilies());
      _families = objList(r['families']);
      _services = intOf(r['totalCompletedServices']);
    } catch (_) {
      _error = true;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _edit([Json? f]) async {
    if (await showDevoteeForm(context, family: f) == true) _load();
  }

  Future<void> _delete(Json f) async {
    final ok = await confirmDialog(
      context,
      title: t('delete_devotee'),
      message: '${t('confirm_delete')} ${str(f['familyName'])}? ${t('delete_warning')}.',
      confirm: t('delete'),
      destructive: true,
    );
    if (!ok) return;
    try {
      await Api.deleteFamily(str(f['familyId']));
      Toast.success(t('devotee_deleted', 'Successfully deleted devotee details'));
      _load();
    } catch (e) {
      Toast.error(apiError(e, 'Error deleting devotee details'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.toLowerCase();
    final list = _families.where((f) => str(f['familyName']).toLowerCase().contains(q) || str(f['phone']).contains(q)).toList();
    return Scaffold(
      backgroundColor: pageBg,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        backgroundColor: AppColors.bluntRed,
        foregroundColor: Colors.white,
        icon: const Icon(LucideIcons.userPlus),
        label: Text(
          t('add_devotee'),
          style: AppText.body(size: 15, weight: FontWeight.w700, color: Colors.white),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.bluntRed,
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(t('devotee_management'), style: AppText.heading(size: 24)),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _stat('${_families.length}', t('total_devotees'), LucideIcons.users),
                            const SizedBox(width: 8),
                            _stat('$_services', t('total_services'), LucideIcons.handHeart),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          onChanged: (v) => setState(() => _q = v),
                          style: AppText.body(size: 15),
                          decoration: appInputDecoration(hint: t('search_devotees'), prefix: const Icon(LucideIcons.search, size: 18), dense: true),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(hasScrollBody: false, child: AppLoader())
            else if (_error)
              SliverFillRemaining(hasScrollBody: false, child: ErrorState(onRetry: _load))
            else if (list.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: LucideIcons.users,
                  title: _q.isEmpty ? t('no_devotees', 'No devotees yet') : t('no_results', 'No matching devotees'),
                  message: _q.isEmpty ? t('add_devotee_hint', 'Add families you serve to book pujas for them quickly.') : null,
                  action: _q.isEmpty ? t('add_devotee') : null,
                  onAction: () => _edit(),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                sliver: SliverList.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _card(list[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String v, String label, IconData icon) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.bluntRed.withValues(alpha: .06), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.bluntRed),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(v, style: AppText.body(size: 18, weight: FontWeight.w800)),
              Text(label, style: AppText.body(size: 11.5, color: AppColors.mutedForeground)),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _card(Json f) {
    final phone = str(f['phone']);
    final full = phone.isEmpty ? '' : '+${str(f['countryCode'], '91')}$phone';
    return AppCard(
      onTap: () => context.push(R.familyMembers, extra: {'familyId': str(f['familyId']), 'familyName': str(f['familyName'])}),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Avatar(name: str(f['familyName']), size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(str(f['familyName']), style: AppText.body(size: 16, weight: FontWeight.w700)),
                    InfoRow(icon: LucideIcons.phone, text: phone.isEmpty ? t('no_phone', 'No phone') : '+${str(f['countryCode'], '91')} $phone'),
                    InfoRow(icon: LucideIcons.mapPin, text: str(f['address']).isEmpty ? t('no_address', 'No address') : str(f['address'])),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(LucideIcons.ellipsisVertical, size: 18),
                onSelected: (v) => switch (v) {
                  'edit' => _edit(f),
                  'members' => context.push(R.familyMembers, extra: {'familyId': str(f['familyId']), 'familyName': str(f['familyName'])}),
                  _ => _delete(f),
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'members', child: Text(t('family_members', 'Family members'))),
                  PopupMenuItem(value: 'edit', child: Text(t('edit'))),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(t('delete'), style: const TextStyle(color: AppColors.red600)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppButton(label: t('book_now'), compact: true, icon: LucideIcons.calendarPlus, onPressed: () => context.go(R.bookings)),
              ),
              const SizedBox(width: 8),
              IconPill(icon: LucideIcons.phone, onTap: () => callPhone(full)),
              const SizedBox(width: 8),
              IconPill(icon: LucideIcons.messageCircle, color: AppColors.whatsapp, onTap: () => openWhatsApp(full)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Add / edit devotee sheet (AddFamily.js). Returns true on save.
Future<bool?> showDevoteeForm(BuildContext context, {Json? family}) {
  final update = family != null;
  final phone = TextEditingController(text: str(family?['phone']));
  final name = TextEditingController(text: str(family?['familyName']));
  final address = TextEditingController(text: str(family?['address']));
  var code = str(family?['countryCode'], '91');
  var saving = false;

  Future<void> fromContacts(BuildContext ctx, void Function(VoidCallback) set) async {
    final status = await FlutterContacts.permissions.request(PermissionType.read);
    if (status != PermissionStatus.granted && status != PermissionStatus.limited) {
      Toast.error(t('contacts_permission', 'Allow contacts access to pick a devotee'));
      return;
    }
    final contacts = await FlutterContacts.getAll(properties: {ContactProperty.name, ContactProperty.phone, ContactProperty.address});
    final withPhone = contacts.where((c) => c.phones.isNotEmpty).toList()
      ..sort((a, b) => (a.displayName ?? '').toLowerCase().compareTo((b.displayName ?? '').toLowerCase()));
    if (!ctx.mounted) return;
    final picked = await showAppSheet<Contact>(
      ctx,
      title: t('select_from_contacts'),
      builder: (_) => _ContactList(contacts: withPhone),
    );
    if (picked == null) return;
    final p = parsePhone(picked.phones.first.number);
    set(() {
      phone.text = p.number;
      code = p.code;
      name.text = picked.displayName ?? '';
      final a = picked.addresses.firstOrNull?.formatted;
      if (a != null && a.isNotEmpty) address.text = a;
    });
  }

  return showAppSheet<bool>(
    context,
    title: update ? t('update_devotee') : t('create_devotee'),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        final valid = name.text.trim().isNotEmpty && phone.text.length >= 6 && phone.text.length <= 15;
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(20),
          children: [
            OutlinedButton.icon(
              onPressed: () => fromContacts(ctx, set),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(LucideIcons.contact, size: 18, color: AppColors.bluntRed),
              label: Text(t('select_from_contacts'), style: AppText.body(size: 14, weight: FontWeight.w600)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              maxLength: 15,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => set(() {}),
              style: AppText.body(size: 16),
              decoration: appInputDecoration(label: '${t('mobile_number')} *').copyWith(
                prefixIcon: InkWell(
                  onTap: () => showCountryPicker(
                    context: ctx,
                    showPhoneCode: true,
                    favorite: const ['IN', 'US', 'GB', 'AE'],
                    onSelect: (c) => set(() => code = c.phoneCode),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('+$code', style: AppText.body(size: 16, weight: FontWeight.w600)),
                        const Icon(LucideIcons.chevronDown, size: 14),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            AppTextField(
              controller: name,
              label: t('name'),
              required: true,
              hint: t('full_name'),
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => set(() {}),
            ),
            const SizedBox(height: 12),
            AppTextField(controller: address, label: t('address'), hint: t('sample_address'), maxLines: 3, minLines: 2),
            const SizedBox(height: 24),
            AppButton(
              label: update ? t('update') : t('create'),
              loading: saving,
              onPressed: !valid
                  ? null
                  : () async {
                      set(() => saving = true);
                      final payload = {
                        'phone': phone.text.trim(),
                        'countryCode': code,
                        'name': name.text.trim(),
                        'address': address.text.trim(),
                        'title': 'Head of the Family',
                        'isHead': true,
                        'familyName': update ? null : '',
                        'dob': '',
                        if (!update) ...{'zodiac': '', 'tob': '', 'birthPlace': ''},
                      }..removeWhere((k, v) => v == null);
                      try {
                        if (update) {
                          await Api.updateFamily(str(family['familyId']), payload);
                          Toast.success(t('devotee_updated', 'Successfully updated devotee details'));
                        } else {
                          await Api.createFamily(payload);
                          Toast.success(t('devotee_created', 'New devotee created successfully'));
                        }
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        Toast.error(apiError(e, update ? 'Error updating devotee' : 'Error creating devotee'));
                        set(() => saving = false);
                      }
                    },
            ),
          ],
        );
      },
    ),
  );
}

class _ContactList extends StatefulWidget {
  const _ContactList({required this.contacts});
  final List<Contact> contacts;

  @override
  State<_ContactList> createState() => _ContactListState();
}

class _ContactListState extends State<_ContactList> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.toLowerCase();
    final list = widget.contacts.where((c) => (c.displayName ?? '').toLowerCase().contains(q) || c.phones.first.number.contains(q)).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            autofocus: true,
            onChanged: (v) => setState(() => _q = v),
            decoration: appInputDecoration(hint: t('search', 'Search'), prefix: const Icon(LucideIcons.search, size: 18), dense: true),
          ),
        ),
        Flexible(
          child: list.isEmpty
              ? EmptyState(compact: true, title: t('no_contacts', 'No contacts found'))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: list.length,
                  itemBuilder: (_, i) => ListTile(
                    leading: Avatar(name: list[i].displayName, size: 38),
                    title: Text(list[i].displayName ?? '', style: AppText.body(size: 15, weight: FontWeight.w600)),
                    subtitle: Text(list[i].phones.first.number, style: AppText.body(size: 13, color: AppColors.mutedForeground)),
                    onTap: () => Navigator.pop(context, list[i]),
                  ),
                ),
        ),
      ],
    );
  }
}
