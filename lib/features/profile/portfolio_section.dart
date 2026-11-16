import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/api/api.dart';
import '../../core/api/api_client.dart';
import '../../core/i18n/i18n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/format.dart';
import '../../core/utils/json.dart';
import '../../core/utils/pickers.dart';
import '../../core/utils/upload.dart';
import '../../core/widgets/media.dart';
import '../../core/widgets/toast.dart';
import '../../core/widgets/ui.dart';

/// Media portfolio: photos / videos (≤10 MB) with a title (UploadMediaCard.js).
class PortfolioSection extends StatefulWidget {
  const PortfolioSection({super.key});

  @override
  State<PortfolioSection> createState() => _PortfolioSectionState();
}

class _PortfolioSectionState extends State<PortfolioSection> {
  static const _maxBytes = 10 * 1024 * 1024;
  List<Json> _items = [];
  bool _loading = true;
  bool _adding = false;
  bool _uploading = false;
  bool _saving = false;
  String _mediaUrl = '';
  final _title = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      _items = objList(obj(await Api.fetchPortfolioMedia())['media']);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pick() async {
    final kind = await showActionSheet<String>(
      context,
      title: t('upload_media'),
      actions: [('photo', LucideIcons.image, t('photo', 'Photo')), ('video', LucideIcons.video, t('video', 'Video'))],
    );
    if (kind == null) return;
    final files = await pickGalleryMedia(video: kind == 'video', multiple: false);
    if (files.isEmpty) return;
    final f = files.first;
    if (await f.length() > _maxBytes) return Toast.error('File size exceeds 10MB limit');
    setState(() => _uploading = true);
    try {
      final url = await uploadFile(f, folder: 'media');
      setState(() => _mediaUrl = url);
    } catch (e) {
      Toast.error(apiError(e, 'Failed to upload media file'));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty) return Toast.error(t('please_enter_title_for_the_media_item'));
    if (_mediaUrl.isEmpty) return Toast.error(t('please_upload_media', 'Please upload a photo or video'));
    setState(() => _saving = true);
    try {
      await Api.uploadPortfolioMedia({'title': _title.text.trim(), 'mediaUrl': _mediaUrl});
      Toast.success(t('media_added', 'Media added to your portfolio'));
      setState(() {
        _adding = false;
        _mediaUrl = '';
        _title.clear();
      });
      _load();
    } catch (e) {
      Toast.error(apiError(e, 'Failed to add media item. Please try again.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Expanded(child: SectionTitle(t('media_portfolio'), icon: LucideIcons.images)),
          if (!_adding)
            AppButton(
              label: t('upload_media'),
              icon: LucideIcons.upload,
              compact: true,
              expand: false,
              kind: BtnKind.secondary,
              onPressed: () => setState(() => _adding = true),
            ),
        ],
      ),
      const SizedBox(height: 12),
      if (_adding)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cream.withValues(alpha: .5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.bluntRed.withValues(alpha: .3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t('upload_new_media'), style: AppText.body(size: 15, weight: FontWeight.w700)),
              const SizedBox(height: 12),
              AppTextField(controller: _title, label: t('title'), hint: t('enter_title'), required: true),
              const SizedBox(height: 12),
              InkWell(
                onTap: _uploading ? null : _pick,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _uploading
                      ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                      : _mediaUrl.isEmpty
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(LucideIcons.cloudUpload, color: AppColors.bluntRed, size: 30),
                            const SizedBox(height: 6),
                            Text(
                              t('tap_to_select', 'Tap to select a photo or video (max 10 MB)'),
                              style: AppText.body(size: 13, color: AppColors.mutedForeground),
                            ),
                          ],
                        )
                      : isVideoUrl(_mediaUrl)
                      ? const Center(child: Icon(LucideIcons.circlePlay, size: 40, color: AppColors.bluntRed))
                      : NetImage(_mediaUrl),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: t('cancel'),
                      kind: BtnKind.outline,
                      compact: true,
                      onPressed: () => setState(() {
                        _adding = false;
                        _mediaUrl = '';
                      }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppButton(label: t('save', 'Save'), compact: true, loading: _saving, onPressed: _submit),
                  ),
                ],
              ),
            ],
          ),
        ),
      if (_loading)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        )
      else if (_items.isEmpty && !_adding)
        EmptyState(
          compact: true,
          icon: LucideIcons.images,
          title: t('no_media', 'No media yet'),
          message: t('media_hint', 'Add photos and videos of pujas you have performed.'),
        )
      else
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: .82),
          itemCount: _items.length,
          itemBuilder: (_, i) {
            final m = _items[i];
            final url = str(m['mediaUrl']);
            return GestureDetector(
              onTap: () => showMediaPreview(context, url),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: isVideoUrl(url)
                          ? Container(
                              color: AppColors.maroonDark,
                              child: const Icon(LucideIcons.circlePlay, color: Colors.white, size: 36),
                            )
                          : NetImage(url),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            str(m['title']),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body(size: 13, weight: FontWeight.w700),
                          ),
                          Text(fmtDate(m['createdAt']), style: AppText.body(size: 11, color: AppColors.mutedForeground)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
    ],
  );
}
