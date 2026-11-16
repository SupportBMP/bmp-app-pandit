import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api.dart';
import '../../core/api/api_client.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/format.dart';
import '../../core/utils/json.dart';
import '../../core/widgets/date_pickers.dart';
import '../../core/widgets/native.dart';
import '../../core/widgets/places_field.dart';
import '../../core/widgets/toast.dart';
import '../../core/widgets/ui.dart';

const _zodiacs = ['aries', 'taurus', 'gemini', 'cancer', 'leo', 'virgo', 'libra', 'scorpio', 'sagittarius', 'capricorn', 'aquarius', 'pisces'];

/// Members of a devotee family with birth details (FamilyMembers.js).
class FamilyMembersPage extends StatefulWidget {
  const FamilyMembersPage({super.key, this.args});
  final Object? args;

  @override
  State<FamilyMembersPage> createState() => _FamilyMembersPageState();
}

class _FamilyMembersPageState extends State<FamilyMembersPage> {
  late final Map _a = (widget.args as Map?) ?? {};
  late final String _familyId = str(_a['familyId']);
  List<Json> _members = [];
  Json _summary = {};
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
      final r = obj(await Api.getFamilyMembers(_familyId));
      _members = objList(r['members']);
      _summary = obj(r['poojaSummary']);
    } catch (_) {
      _error = true;
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _form([Json? m]) async {
    if (await _showMemberForm(context, _familyId, m) == true) _load();
  }

  Future<void> _delete(Json m) async {
    final ok = await confirmDialog(
      context,
      title: t('delete_member', 'Delete member'),
      message: '${t('confirm_delete')} ${str(m['name'])}?',
      confirm: t('delete'),
      destructive: true,
    );
    if (!ok) return;
    try {
      await Api.deleteFamilyMember(_familyId, str(m['memberId']));
      Toast.success(t('member_deleted', 'Successfully deleted member details'));
      _load();
    } catch (e) {
      Toast.error(apiError(e, 'Error deleting member'));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: pageBg,
    appBar: appBar(context, str(_a['familyName'], t('family_members', 'Family members')), subtitle: t('family_members', 'Family members')),
    floatingActionButton: FloatingActionButton(
      onPressed: () => _form(),
      backgroundColor: AppColors.bluntRed,
      foregroundColor: Colors.white,
      child: const Icon(LucideIcons.userPlus),
    ),
    body: _loading
        ? const AppLoader()
        : _error
        ? ErrorState(onRetry: _load)
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                if (_summary.isNotEmpty)
                  AppCard(
                    child: Wrap(
                      spacing: 20,
                      runSpacing: 8,
                      children: [
                        for (final e in _summary.entries)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                str(e.value, '0'),
                                style: AppText.body(size: 18, weight: FontWeight.w800, color: AppColors.bluntRed),
                              ),
                              Text(
                                capitalize(e.key.replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m[1]}')),
                                style: AppText.body(size: 12, color: AppColors.mutedForeground),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                if (_summary.isNotEmpty) const SizedBox(height: 12),
                if (_members.isEmpty)
                  EmptyState(icon: LucideIcons.users, title: t('no_members', 'No family members yet'), action: t('add', 'Add'), onAction: () => _form()),
                for (final m in _members)
                  AppCard(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Avatar(name: str(m['name']), size: 44),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(str(m['name']), style: AppText.body(size: 16, weight: FontWeight.w700)),
                                  ),
                                  if (boolOf(m['isHead'])) ...[const SizedBox(width: 6), StatusBadge('active', label: t('head_of_family'))],
                                ],
                              ),
                              if (str(m['title']).isNotEmpty) Text(str(m['title']), style: AppText.body(size: 13, color: AppColors.mutedForeground)),
                              const SizedBox(height: 4),
                              if (str(m['dob']).isNotEmpty)
                                InfoRow(
                                  icon: LucideIcons.cake,
                                  text: '${fmtDate(m['dob'], 'd MMM yyyy')}${str(m['tob']).isEmpty ? '' : ' · ${str(m['tob'])}'}',
                                ),
                              if (str(m['zodiac']).isNotEmpty)
                                InfoRow(icon: LucideIcons.sparkles, text: t('zodiac_${str(m['zodiac'])}', capitalize(str(m['zodiac'])))),
                              if (str(m['birthPlace']).isNotEmpty) InfoRow(icon: LucideIcons.mapPin, text: str(m['birthPlace'])),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(LucideIcons.ellipsisVertical, size: 18),
                          onSelected: (v) => v == 'edit' ? _form(m) : _delete(m),
                          itemBuilder: (_) => [
                            PopupMenuItem(value: 'edit', child: Text(t('edit'))),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(t('delete'), style: const TextStyle(color: AppColors.red600)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
  );
}

Future<bool?> _showMemberForm(BuildContext context, String familyId, Json? m) {
  final name = TextEditingController(text: str(m?['name']));
  final title = TextEditingController(text: str(m?['title']));
  var isHead = boolOf(m?['isHead']);
  var zodiac = str(m?['zodiac']);
  var dob = str(m?['dob']);
  var tob = str(m?['tob']);
  var place = str(m?['birthPlace']);
  var saving = false;
  return showAppSheet<bool>(
    context,
    title: m != null ? t('update_family_members') : t('family_member_details'),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(20),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(t('head_of_family'), style: AppText.body(size: 15, weight: FontWeight.w600)),
            value: isHead,
            onChanged: (v) => set(() => isHead = v),
          ),
          AppTextField(controller: name, label: t('name'), required: true, hint: t('full_name'), textCapitalization: TextCapitalization.words),
          const SizedBox(height: 12),
          AppTextField(controller: title, label: t('title'), hint: t('relation_example')),
          const SizedBox(height: 18),
          Text(
            t('birth_details'),
            style: AppText.body(size: 14, weight: FontWeight.w700, color: AppColors.mutedForeground),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: PickerField(
                  label: t('dob'),
                  icon: LucideIcons.calendar,
                  value: dob.isEmpty ? null : fmtDate(dob, 'd MMM yyyy'),
                  onTap: () async {
                    final d = await showNativeDatePicker(
                      ctx,
                      initialDate: DateTime.tryParse(dob) ?? DateTime(1990),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) set(() => dob = ymd(d));
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PickerField(
                  label: t('time_of_birth'),
                  icon: LucideIcons.clock,
                  value: tob,
                  onTap: () async {
                    final r = await pickTime12(ctx, initial: tob);
                    if (r != null) set(() => tob = r);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          PickerField(
            label: t('zodiac'),
            icon: LucideIcons.sparkles,
            value: zodiac.isEmpty ? null : t('zodiac_$zodiac', capitalize(zodiac)),
            onTap: () async {
              final z = await showNativePicker<String>(
                ctx,
                title: t('zodiac'),
                options: _zodiacs,
                labelOf: (z) => t('zodiac_$z', capitalize(z)),
                selected: zodiac,
              );
              if (z != null) set(() => zodiac = z);
            },
          ),
          const SizedBox(height: 12),
          PlacesField(label: t('place_of_birth'), citiesOnly: true, initialValue: place, onChanged: (v) => place = v, onSelected: (p) => place = p.description),
          const SizedBox(height: 24),
          AppButton(
            label: m != null ? t('update') : t('create'),
            loading: saving,
            onPressed: () async {
              if (name.text.trim().isEmpty) return Toast.error(t('please_enter_name', 'Please enter the name'));
              set(() => saving = true);
              final payload = {
                'name': name.text.trim(),
                'title': title.text.trim(),
                'isHead': isHead,
                'zodiac': zodiac,
                'dob': dob,
                'tob': tob,
                'birthPlace': place,
              };
              try {
                if (m != null) {
                  await Api.updateFamilyMember(familyId, str(m['memberId']), payload);
                  Toast.success(t('member_updated', 'Successfully updated member details'));
                } else {
                  await Api.addFamilyMember(familyId, payload);
                  Toast.success(t('member_added', 'Member added successfully'));
                }
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                Toast.error(apiError(e, 'Error saving member'));
                set(() => saving = false);
              }
            },
          ),
        ],
      ),
    ),
  );
}
