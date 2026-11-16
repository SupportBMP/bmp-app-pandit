import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api.dart';
import '../../core/api/api_client.dart';
import '../../core/i18n/i18n.dart';
import '../../core/router/routes.dart';
import '../../core/state/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/json.dart';
import '../../core/widgets/places_field.dart';
import '../../core/widgets/toast.dart';
import '../../core/widgets/ui.dart';
import '../profile/certificates_section.dart';

/// KYC profile form for new and rejected Pandits (ProfileInformation.js):
/// personal details, location, languages, specializations, certificates and
/// the "I am a Pandit" confirmation. Submitting sends the profile for review.
class ProfileInfoPage extends ConsumerStatefulWidget {
  const ProfileInfoPage({super.key, this.isReapplication = false});
  final bool isReapplication;

  @override
  ConsumerState<ProfileInfoPage> createState() => _ProfileInfoPageState();
}

class _ProfileInfoPageState extends ConsumerState<ProfileInfoPage> {
  final _f = <String, TextEditingController>{
    for (final k in ['name', 'experience', 'email', 'address', 'city', 'state', 'pincode']) k: TextEditingController(),
  };
  List<String> _languages = [];
  List<String> _specs = [];
  List<Json> _langOptions = [];
  List<Json> _specOptions = [];
  bool _confirmed = false;
  bool _loadingProfile = true;
  bool _loadingOptions = true;
  bool _saving = false;

  bool get _rejected => widget.isReapplication || str(ref.read(sessionProvider)?['KYCStatus']) == 'rejected';

  @override
  void initState() {
    super.initState();
    _fill(ref.read(sessionProvider));
    _loadProfile();
    _loadOptions();
    for (final c in _f.values) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in _f.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(Json? u) {
    if (u == null) return;
    for (final k in _f.keys) {
      _f[k]!.text = str(u[k]);
    }
    _languages = codesOf(u['languages'], 'code');
    _specs = codesOf(u['specializations'], 'key');
    _confirmed = boolOf(u['panditConfirmed']);
  }

  Future<void> _loadProfile() async {
    final u = await ref.read(sessionProvider.notifier).refresh();
    if (!mounted) return;
    setState(() {
      _fill(u);
      _loadingProfile = false;
    });
  }

  Future<void> _loadOptions() async {
    try {
      final r = obj(await Api.getOptions(I18n.code));
      final d = obj(r['data']);
      setState(() {
        _langOptions = objList(d['languages']);
        _specOptions = objList(d['specializations']);
      });
    } catch (_) {
      Toast.error(t('failed_to_load_options', 'Failed to load options. Please try again later.'));
    } finally {
      if (mounted) setState(() => _loadingOptions = false);
    }
  }

  String _v(String k) => _f[k]!.text.trim();

  bool get _valid =>
      _confirmed && ['name', 'experience', 'address', 'city', 'state', 'pincode'].every((k) => _v(k).isNotEmpty) && _languages.isNotEmpty && _specs.isNotEmpty;

  String? _firstError() {
    if (!_confirmed) return t('please_confirm_pandit', 'Please confirm that you are a pandit');
    if (_v('name').isEmpty) return t('please_enter_name', 'Please enter your name');
    if (_v('experience').isEmpty) return t('please_enter_experience', 'Please enter years of experience');
    if (_v('address').isEmpty) return t('please_enter_address', 'Please enter your address');
    if (_v('city').isEmpty) return t('please_enter_city', 'Please enter your city');
    if (_v('state').isEmpty) return t('please_enter_state', 'Please enter your state');
    if (_v('pincode').isEmpty) return t('please_enter_pincode', 'Please enter your PIN code');
    if (_languages.isEmpty) return t('select_one_language', 'Please select at least one language');
    if (_specs.isEmpty) return t('select_one_specialization', 'Please select at least one specialization');
    return null;
  }

  Future<void> _submit() async {
    final err = _firstError();
    if (err != null) {
      Toast.error(err);
      return;
    }
    setState(() => _saving = true);
    final session = ref.read(sessionProvider.notifier);
    try {
      final payload = <String, dynamic>{
        for (final k in _f.keys) k: _v(k),
        'phone': str(ref.read(sessionProvider)?['phone']),
        'languages': _languages,
        'specializations': _specs,
        'panditConfirmed': _confirmed,
        if (_rejected) 'KYCStatus': 'pending',
      };
      final r = obj(await Api.updateProfile(payload));
      final u = r['user'];
      if (u is Map) {
        await session.setUser(obj(u));
      } else {
        await session.refresh();
      }
      Toast.success(
        _rejected ? t('profile_resubmitted', 'Profile updated and resubmitted for approval') : t('profile_submitted', 'Profile information submitted'),
      );
      if (mounted) context.go(R.waiting);
    } catch (e) {
      Toast.error(apiError(e, t('error_submitting_profile', 'Error submitting profile')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rejected = _rejected;
    return Scaffold(
      backgroundColor: pageBg,
      appBar: appBar(
        context,
        rejected ? t('update_your_profile') : t('complete_your_profile'),
        subtitle: rejected ? t('update_your_details_to_reapply') : t('please_fill_in_your_details_to_continue'),
      ),
      body: _loadingProfile
          ? AppLoader(message: t('loading_profile', 'Loading profile…'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                _StepHeader(done: _valid),
                const SizedBox(height: 16),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SectionTitle(t('personal_information'), icon: LucideIcons.user),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _f['name'],
                        label: t('full_name'),
                        required: true,
                        hint: t('enter_full_name'),
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 12),
                      AppTextField(
                        controller: _f['experience'],
                        label: t('years_of_experience'),
                        required: true,
                        hint: t('enter_years_of_experience'),
                        digitsOnly: true,
                        keyboardType: TextInputType.number,
                        maxLength: 2,
                      ),
                      const SizedBox(height: 12),
                      AppTextField(controller: _f['email'], label: t('email_address'), hint: t('enter_email'), keyboardType: TextInputType.emailAddress),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SectionTitle(t('location_details'), icon: LucideIcons.mapPin),
                      const SizedBox(height: 16),
                      AppTextField(controller: _f['address'], label: t('address'), required: true, hint: t('enter_full_address'), maxLines: 3, minLines: 2),
                      const SizedBox(height: 12),
                      PlacesField(
                        label: t('city'),
                        required: true,
                        citiesOnly: true,
                        initialValue: _f['city']!.text,
                        onChanged: (v) => _f['city']!.text = v,
                        onSelected: (p) {
                          _f['city']!.text = p.city ?? '';
                          if ((p.state ?? '').isNotEmpty) _f['state']!.text = p.state!;
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(controller: _f['state'], label: t('state'), required: true),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppTextField(
                              controller: _f['pincode'],
                              label: t('pincode'),
                              required: true,
                              digitsOnly: true,
                              maxLength: 6,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _chipsCard(
                  title: t('languages'),
                  icon: LucideIcons.languages,
                  options: _langOptions.map((e) => (str(e['code']), str(e['name']))).toList(),
                  selected: _languages,
                  empty: t('no_languages_available', 'No languages available'),
                ),
                const SizedBox(height: 12),
                _chipsCard(
                  title: t('specializations'),
                  icon: LucideIcons.sparkles,
                  options: _specOptions.map((e) => (str(e['key']), str(e['lang'], str(e['name'])))).toList(),
                  selected: _specs,
                  empty: t('no_specializations_available', 'No specializations available'),
                ),
                const SizedBox(height: 12),
                const AppCard(child: CertificatesSection()),
                const SizedBox(height: 16),
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => setState(() => _confirmed = !_confirmed),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _confirmed ? AppColors.bluntRed.withValues(alpha: .05) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _confirmed ? AppColors.bluntRed : AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Checkbox(value: _confirmed, onChanged: (v) => setState(() => _confirmed = v ?? false)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(t('i_confirm_that_i_am_a_pandit'), style: AppText.body(size: 15, weight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                AppButton(
                  label: _saving ? '${t('submitting')}…' : (rejected ? t('resubmit_for_approval', 'Resubmit for approval') : t('submit', 'Submit')),
                  loading: _saving,
                  icon: LucideIcons.send,
                  onPressed: _valid ? _submit : null,
                ),
                if (!_valid) ...[
                  const SizedBox(height: 10),
                  Text(
                    t('fill_required_fields', 'Fill all fields marked * to continue'),
                    textAlign: TextAlign.center,
                    style: AppText.body(size: 12, color: AppColors.mutedForeground),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _chipsCard({
    required String title,
    required IconData icon,
    required List<(String, String)> options,
    required List<String> selected,
    required String empty,
  }) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle('$title *', icon: icon, subtitle: selected.isEmpty ? null : '${selected.length} ${t('selected', 'selected')}'),
        const SizedBox(height: 14),
        if (_loadingOptions)
          const Center(
            child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (options.isEmpty)
          Text(empty, style: AppText.body(size: 14, color: AppColors.mutedForeground))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (code, label) in options)
                SelectChip(
                  label: label,
                  selected: selected.contains(code),
                  onTap: () => setState(() => selected.contains(code) ? selected.remove(code) : selected.add(code)),
                ),
            ],
          ),
      ],
    ),
  );
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.done});
  final bool done;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [AppColors.heroFrom, AppColors.heroTo]),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.creamDark),
    ),
    child: Row(
      children: [
        Icon(done ? LucideIcons.badgeCheck : LucideIcons.shieldCheck, color: done ? AppColors.green600 : AppColors.bluntRed, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            t('kyc_intro', 'Share your details for verification. Once approved by our team, your Pandit dashboard unlocks.'),
            style: AppText.body(size: 13, color: AppColors.foreground, height: 1.4),
          ),
        ),
      ],
    ),
  );
}
