import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../i18n/i18n.dart';
import '../theme/app_colors.dart';
import '../widgets/ui.dart';

final _picker = ImagePicker();

/// Camera or gallery, chosen from a sheet. Returns null when cancelled.
Future<File?> pickImage(BuildContext context, {bool crop = false, bool square = false, String? title}) async {
  final source = await showActionSheet<ImageSource>(
    context,
    title: title ?? t('select_photo', 'Select photo'),
    actions: [
      (ImageSource.camera, LucideIcons.camera, t('take_photo', 'Take photo')),
      (ImageSource.gallery, LucideIcons.image, t('choose_from_gallery', 'Choose from gallery')),
    ],
  );
  if (source == null) return null;
  final x = await _picker.pickImage(source: source, imageQuality: 85, maxWidth: 2000);
  if (x == null) return null;
  if (!crop) return File(x.path);
  return cropImage(File(x.path), square: square);
}

Future<File?> cropImage(File f, {bool square = false}) async {
  final c = await ImageCropper().cropImage(
    sourcePath: f.path,
    compressQuality: 85,
    aspectRatio: square ? const CropAspectRatio(ratioX: 1, ratioY: 1) : null,
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: t('crop_image', 'Crop image'),
        toolbarColor: AppColors.bluntRed,
        toolbarWidgetColor: Colors.white,
        activeControlsWidgetColor: AppColors.bluntRed,
        lockAspectRatio: square,
      ),
      IOSUiSettings(title: t('crop_image', 'Crop image'), aspectRatioLockEnabled: square),
    ],
  );
  return c == null ? null : File(c.path);
}

Future<List<File>> pickGalleryMedia({bool video = false, bool multiple = true}) async {
  if (video) {
    final v = await _picker.pickVideo(source: ImageSource.gallery);
    return v == null ? [] : [File(v.path)];
  }
  if (multiple) {
    final xs = await _picker.pickMultiImage(imageQuality: 85, maxWidth: 2000);
    return xs.map((x) => File(x.path)).toList();
  }
  final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 2000);
  return x == null ? [] : [File(x.path)];
}

/// Image or PDF/document, chosen from a sheet ("Select Document Type").
Future<File?> pickDocument(BuildContext context) async {
  final kind = await showActionSheet<String>(
    context,
    title: t('select_document_type', 'Select document type'),
    actions: [('image', LucideIcons.image, t('image', 'Image')), ('pdf', LucideIcons.fileText, t('pdf_document', 'PDF / Document'))],
  );
  if (kind == null) return null;
  if (kind == 'image') {
    final x = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    return x == null ? null : File(x.path);
  }
  final r = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png']);
  final path = r.isEmpty ? null : r.first.path;
  return path == null ? null : File(path);
}
