import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api.dart';
import '../../core/api/api_client.dart';
import '../../core/i18n/i18n.dart';
import '../../core/state/session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/json.dart';
import '../../core/utils/pickers.dart';
import '../../core/utils/upload.dart';
import '../../core/widgets/places_field.dart';
import '../../core/widgets/toast.dart';
import '../../core/widgets/ui.dart';
import 'certificates_section.dart';
import 'portfolio_section.dart';

/// Edit profile in two steps (EditProfile.js): basic info (photo,
/// personal, contact, temple, location, languages, specializations) and
/// credentials (certificates + media portfolio).
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  static const _keys = [
    'phone',
    'address',
    'bio',
    'city',
    'name',
    'email',
    'pincode',
    'state',
    'experience',
    'title',
    'whatsappNumber',
    'templeName',
    'templeCity',
    'templeAddress',
  ];
  late final Map<String, TextEditingController> _f = {for (final k in _keys) k: TextEditingController()};
  String _photo = '';
  List<String> _langs = [];
  List<String> _specs = [];
  List<Json> _langOptions = [];
  List<Json> _specOptions = [];
  int _tab = 0;
  bool _uploadingPhoto = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final u = ref.read(sessionProvider) ?? {};
    for (final k in _keys) {
      _f[k]!.text = str(u[k]);
    }
    _photo = str(u['photoUrl']);
    _langs = codesOf(u['languages'], 'code');
    _specs = codesOf(u['specializations'], 'key');
    Api.getOptions(I18n.code)
        .then((v) {
          final d = obj(obj(v)['data']);
          if (mounted) {
            setState(() {
              _langOptions = objList(d['languages']);
              _specOptions = objList(d['specializations']);
            });
          }
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    for (final c in _f.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _changePhoto() async {
    final f = await pickImage(context, crop: true, square: true, title: t('profile_photo', 'Profile photo'));
    if (f == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      final url = await uploadFile(f);
      setState(() => _photo = url);
    } catch (_) {
      Toast.error(t('photo_upload_failed', 'Could not upload photo. Please try again.'));
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await Api.updateProfile({for (final k in _keys) k: _f[k]!.text.trim(), 'photoUrl': _photo, 'languages': _langs, 'specializations': _specs});
      await ref.read(sessionProvider.notifier).refresh();
      Toast.success(t('profile_updated', 'Profile updated'));
      if (mounted) context.pop();
    } catch (e) {
      Toast.error(apiError(e, 'Error updating profile'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: pageBg,
    appBar: appBar(
      context,
      t('edit_profile'),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: FilterTabs(
            items: [('0', '1. ${t('basic_info')}'), ('1', '2. ${t('credentials')}')],
            selected: '$_tab',
            onChanged: (v) => setState(() => _tab = int.parse(v)),
          ),
        ),
      ),
    ),
    body: _tab == 0 ? _basic() : _credentials(),
    bottomNavigationBar: _tab == 0
        ? SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: AppButton(label: t('publish_profile'), icon: LucideIcons.check, loading: _saving, onPressed: _save),
            ),
          )
        : null,
  );

  Widget _section(String title, IconData icon, List<Widget> children) => AppCard(
    margin: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(title, icon: icon),
        const SizedBox(height: 14),
        for (var i = 0; i < children.length; i++) ...[children[i], if (i < children.length - 1) const SizedBox(height: 12)],
      ],
    ),
  );

  Widget _basic() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Center(
        child: GestureDetector(
          onTap: _uploadingPhoto ? null : _changePhoto,
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.bluntRed, width: 2),
                ),
                child: Avatar(url: _photo, name: _f['name']!.text, size: 96),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: AppColors.bluntRed, shape: BoxShape.circle),
                  child: _uploadingPhoto
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(LucideIcons.camera, size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      _section(t('personal_information'), LucideIcons.user, [
        AppTextField(controller: _f['name'], label: t('full_name'), textCapitalization: TextCapitalization.words),
        AppTextField(controller: _f['title'], label: t('professional_title')),
        AppTextField(controller: _f['experience'], label: t('years_of_experience'), digitsOnly: true, keyboardType: TextInputType.number, maxLength: 2),
        AppTextField(controller: _f['bio'], label: t('bio_introduction'), maxLines: 4, minLines: 3),
      ]),
      _section(t('contact_information', 'Contact information'), LucideIcons.phone, [
        AppTextField(controller: _f['phone'], label: t('phone_number'), enabled: false),
        AppTextField(controller: _f['whatsappNumber'], label: t('whatsapp_number'), keyboardType: TextInputType.phone, digitsOnly: true, maxLength: 15),
        AppTextField(controller: _f['email'], label: t('email_address'), keyboardType: TextInputType.emailAddress),
      ]),
      _section(t('temple_information', 'Temple information'), LucideIcons.landmark, [
        AppTextField(controller: _f['templeName'], label: t('temple_name')),
        AppTextField(controller: _f['templeCity'], label: t('city')),
        AppTextField(controller: _f['templeAddress'], label: t('address'), maxLines: 2),
      ]),
      _section(t('location_details'), LucideIcons.mapPin, [
        AppTextField(controller: _f['address'], label: t('address'), maxLines: 3, minLines: 2),
        PlacesField(
          label: t('city'),
          citiesOnly: true,
          initialValue: _f['city']!.text,
          onChanged: (v) => _f['city']!.text = v,
          onSelected: (p) {
            _f['city']!.text = p.city ?? '';
            if ((p.state ?? '').isNotEmpty) _f['state']!.text = p.state!;
          },
        ),
        Row(
          children: [
            Expanded(
              child: AppTextField(controller: _f['state'], label: t('state')),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(controller: _f['pincode'], label: t('pincode'), digitsOnly: true, maxLength: 6, keyboardType: TextInputType.number),
            ),
          ],
        ),
      ]),
      _section(t('languages'), LucideIcons.languages, [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in _langOptions)
              SelectChip(
                label: str(o['name']),
                selected: _langs.contains(str(o['code'])),
                onTap: () => setState(() => _langs.contains(str(o['code'])) ? _langs.remove(str(o['code'])) : _langs.add(str(o['code']))),
              ),
          ],
        ),
      ]),
      _section(t('specializations'), LucideIcons.sparkles, [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in _specOptions)
              SelectChip(
                label: str(o['lang'], str(o['name'])),
                selected: _specs.contains(str(o['key'])),
                onTap: () => setState(() => _specs.contains(str(o['key'])) ? _specs.remove(str(o['key'])) : _specs.add(str(o['key']))),
              ),
          ],
        ),
      ]),
    ],
  );

  Widget _credentials() => ListView(
    padding: const EdgeInsets.all(16),
    children: const [
      AppCard(child: CertificatesSection()),
      SizedBox(height: 12),
      AppCard(child: PortfolioSection()),
    ],
  );
}
