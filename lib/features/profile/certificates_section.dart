import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api.dart';
import '../../core/api/api_client.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/json.dart';
import '../../core/utils/pickers.dart';
import '../../core/utils/upload.dart';
import '../../core/widgets/native.dart';
import '../../core/widgets/toast.dart';
import '../../core/widgets/ui.dart';

/// Certifications & credentials: list with status, add / edit / delete, and
/// document upload (CertificateCard.js and the same block in
/// ProfileInformation.js). Approved certificates are locked.
class CertificatesSection extends StatefulWidget {
  const CertificatesSection({super.key});

  @override
  State<CertificatesSection> createState() => _CertificatesSectionState();
}

class _CertificatesSectionState extends State<CertificatesSection> {
  List<Json> _certs = [];
  bool _loading = true;
  Json? _draft; // the open add / edit form
  String? _editingId;
  bool _uploading = false;
  bool _saving = false;

  List<(String, String)> get _types => [('education', t('education')), ('specialization', t('specialization')), ('award', t('award'))];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = obj(await Api.getCertificates());
      if (mounted) setState(() => _certs = objList(d['certificates']));
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _add() => setState(() {
    _editingId = null;
    _draft = {'title': '', 'institution': '', 'year': '', 'type': 'education', 'description': '', 'documentUrl': ''};
  });

  void _edit(Json c) {
    if (str(c['status']) == 'APPROVED') {
      Toast.error(t('approved_cert_locked', 'Approved certificates cannot be edited'));
      return;
    }
    setState(() {
      _editingId = str(c['_id']);
      _draft = {
        'title': str(c['title']),
        'institution': str(c['institution']),
        'year': str(c['year']),
        'type': str(c['type'], 'education'),
        'description': str(c['description']),
        'documentUrl': str(c['documentUrl']),
      };
    });
  }

  Future<void> _delete(Json c) async {
    if (str(c['status']) == 'APPROVED') {
      Toast.error(t('approved_cert_locked_delete', 'Approved certificates cannot be deleted'));
      return;
    }
    final ok = await confirmDialog(
      context,
      title: t('delete_certificate', 'Delete certificate'),
      message: t('delete_certificate_confirm', 'Are you sure you want to delete this certificate?'),
      confirm: t('delete', 'Delete'),
      destructive: true,
    );
    if (!ok) return;
    try {
      await Api.deleteCertificate(str(c['_id']));
      setState(() => _certs.removeWhere((e) => e['_id'] == c['_id']));
      Toast.success(t('certificate_deleted', 'Certificate deleted successfully'));
    } catch (e) {
      Toast.error(apiError(e, 'Failed to delete certificate'));
    }
  }

  Future<void> _upload() async {
    final f = await pickDocument(context);
    if (f == null) return;
    setState(() => _uploading = true);
    try {
      final url = await uploadFile(
        f,
        folder: 'credentials',
        fileName: 'credential_${newId()}${f.path.contains('.') ? f.path.substring(f.path.lastIndexOf('.')) : ''}',
      );
      setState(() => _draft!['documentUrl'] = url);
      Toast.success(t('document_uploaded', 'Document uploaded successfully'));
    } catch (_) {
      Toast.error(t('document_upload_failed', 'Failed to upload document'));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    final d = _draft!;
    if (str(d['title']).trim().isEmpty) return Toast.error(t('please_enter_certification_title'));
    if (str(d['institution']).trim().isEmpty) return Toast.error(t('please_enter_institution', 'Please enter institution name'));
    if (str(d['year']).trim().isEmpty) return Toast.error(t('please_enter_year', 'Please enter year'));
    final payload = {
      'title': d['title'],
      'institution': d['institution'],
      'year': int.tryParse(str(d['year'])),
      'description': d['description'],
      'type': d['type'],
      'documentUrl': d['documentUrl'],
    };
    setState(() => _saving = true);
    try {
      if (_editingId != null) {
        final r = obj(await Api.updateCertificate(_editingId!, payload));
        final c = obj(r['certificate']);
        setState(() => _certs = _certs.map((e) => e['_id'] == _editingId ? c : e).toList());
        Toast.success(t('certificate_updated', 'Certificate updated successfully'));
      } else {
        final r = obj(await Api.addCertificate(payload));
        setState(() => _certs.add(obj(r['certificate'])));
        Toast.success(strOrNull(r['message']) ?? t('certificate_added', 'Certificate added successfully'));
      }
      setState(() {
        _draft = null;
        _editingId = null;
      });
    } catch (e) {
      Toast.error(apiError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: SectionTitle('${t('certifications')} & ${t('credentials')}', icon: LucideIcons.award)),
            if (_draft == null)
              AppButton(label: t('add', 'Add'), icon: LucideIcons.plus, expand: false, compact: true, kind: BtnKind.secondary, onPressed: _add),
          ],
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else ...[
          for (final c in _certs.where((c) => c['_id'] != _editingId)) _certTile(c),
          if (_draft != null) _form(),
          if (_certs.isEmpty && _draft == null)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.gray50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.gray200),
              ),
              child: Column(
                children: [
                  const Icon(LucideIcons.award, color: AppColors.gray400),
                  const SizedBox(height: 8),
                  Text(
                    t('no_certifications_added_yet'),
                    textAlign: TextAlign.center,
                    style: AppText.body(size: 14, color: AppColors.mutedForeground),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _certTile(Json c) {
    final status = str(c['status'], 'PENDING');
    final editable = status == 'PENDING' || status == 'REJECTED';
    final doc = str(c['documentUrl']);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.cream, borderRadius: BorderRadius.circular(12)),
            child: const Icon(LucideIcons.graduationCap, size: 20, color: AppColors.bluntRed),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(str(c['title']), style: AppText.body(size: 15, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('${str(c['institution'])} • ${str(c['year'])}', style: AppText.body(size: 13, color: AppColors.mutedForeground)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusBadge(status),
                    Text(
                      _types.firstWhere((e) => e.$1 == str(c['type']), orElse: () => (str(c['type']), str(c['type']))).$2,
                      style: AppText.body(size: 12, color: AppColors.mutedForeground),
                    ),
                    if (doc.isNotEmpty)
                      InkWell(
                        onTap: () => launchUrl(Uri.parse(doc), mode: LaunchMode.externalApplication),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.fileText, size: 14, color: AppColors.bluntRed),
                            const SizedBox(width: 4),
                            Text(
                              t('view_document', 'View document'),
                              style: AppText.body(size: 12, weight: FontWeight.w600, color: AppColors.bluntRed),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (editable)
            PopupMenuButton<String>(
              icon: const Icon(LucideIcons.ellipsisVertical, size: 18),
              onSelected: (v) => v == 'edit' ? _edit(c) : _delete(c),
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: Text(t('edit', 'Edit'))),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(t('delete', 'Delete'), style: const TextStyle(color: AppColors.red600)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _form() {
    final d = _draft!;
    final type = str(d['type'], 'education');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cream.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.bluntRed.withValues(alpha: .3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _editingId != null ? t('edit_certification', 'Edit certification') : t('add_new_certification', 'Add new certification'),
            style: AppText.body(size: 16, weight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          AppTextField(
            label: t('certification_title'),
            required: true,
            hint: t('enter_certification_title'),
            initialValue: str(d['title']),
            onChanged: (v) => d['title'] = v,
          ),
          const SizedBox(height: 12),
          AppTextField(
            label: t('institution_authority'),
            required: true,
            hint: t('enter_institution_authority'),
            initialValue: str(d['institution']),
            onChanged: (v) => d['institution'] = v,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  label: t('year'),
                  required: true,
                  hint: t('enter_year'),
                  initialValue: str(d['year']),
                  digitsOnly: true,
                  maxLength: 4,
                  keyboardType: TextInputType.number,
                  onChanged: (v) => d['year'] = v,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PickerField(
                  label: t('type'),
                  required: true,
                  value: _types.firstWhere((e) => e.$1 == type, orElse: () => _types.first).$2,
                  onTap: () async {
                    final v = await showNativePicker<(String, String)>(
                      context,
                      title: t('type'),
                      options: _types,
                      labelOf: (e) => e.$2,
                      selected: _types.firstWhere((e) => e.$1 == type, orElse: () => _types.first),
                    );
                    if (v != null) setState(() => d['type'] = v.$1);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppTextField(
            label: t('description'),
            hint: t('enter_description'),
            maxLines: 3,
            initialValue: str(d['description']),
            onChanged: (v) => d['description'] = v,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _uploading ? null : _upload,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: BorderSide(color: str(d['documentUrl']).isNotEmpty ? AppColors.green600 : AppColors.border),
            ),
            icon: _uploading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(
                    str(d['documentUrl']).isNotEmpty ? LucideIcons.circleCheck : LucideIcons.upload,
                    size: 18,
                    color: str(d['documentUrl']).isNotEmpty ? AppColors.green600 : AppColors.bluntRed,
                  ),
            label: Text(
              str(d['documentUrl']).isNotEmpty
                  ? t('document_uploaded_label', 'Document uploaded')
                  : _uploading
                  ? t('uploading', 'Uploading…')
                  : t('upload_document'),
              style: AppText.body(size: 14, weight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: t('cancel'),
                  kind: BtnKind.outline,
                  compact: true,
                  onPressed: () => setState(() {
                    _draft = null;
                    _editingId = null;
                  }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AppButton(label: _editingId != null ? t('update') : t('add_certification'), compact: true, loading: _saving, onPressed: _submit),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
