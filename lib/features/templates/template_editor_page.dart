import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api/api.dart';
import '../../core/i18n/i18n.dart';
import '../../core/storage/prefs.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/json.dart';
import '../../core/widgets/toast.dart';
import '../../core/widgets/ui.dart';
import 'template_utils.dart';

/// Fill a status template's text fields over its image, then save locally,
/// download to the gallery, or share (TemplateEditorScreen.js).
class TemplateEditorPage extends StatefulWidget {
  const TemplateEditorPage({super.key, this.args});
  final Object? args;

  @override
  State<TemplateEditorPage> createState() => _TemplateEditorPageState();
}

class _TemplateEditorPageState extends State<TemplateEditorPage> {
  late final Map _a = (widget.args as Map?) ?? {};
  late final bool _isSaved = _a['isSaved'] == true;
  late Json _tpl = obj(_a['template']);
  final _shot = ScreenshotController();
  final _values = <String, TextEditingController>{};
  bool _busy = false;
  bool _loadingOriginal = false;

  List<Json> get _fields => objList(_tpl['textFields']);

  @override
  void initState() {
    super.initState();
    final full = _fields.isNotEmpty && str(_tpl['imageUrl']).isNotEmpty && _tpl['imageWidth'] != null && _tpl['imageHeight'] != null;
    if (_isSaved && !full) {
      _loadOriginal();
    } else {
      _initValues();
    }
  }

  Future<void> _loadOriginal() async {
    final id = str(_tpl['originalTemplateId'], str(_tpl['_id']));
    if (id.isEmpty) return _initValues();
    setState(() => _loadingOriginal = true);
    try {
      final r = obj(await Api.getTemplateById(id));
      if (boolOf(r['success'])) {
        final o = obj(r['template']);
        _tpl = {...o, 'name': _tpl['name'] ?? o['name'], 'savedId': _tpl['savedId'], 'originalTemplateId': id, 'editedValues': _tpl['editedValues']};
      }
    } catch (_) {}
    _initValues();
    if (mounted) setState(() => _loadingOriginal = false);
  }

  void _initValues() {
    final edited = obj(_tpl['editedValues']);
    for (final f in _fields) {
      final id = str(f['id']);
      final v = _isSaved && edited[id] != null ? str(edited[id]) : str(f['defaultValue'], str(f['placeholder']));
      _values[id] = TextEditingController(text: v)..addListener(() => setState(() {}));
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in _values.values) {
      c.dispose();
    }
    super.dispose();
  }

  int _maxLen(Json f) => intOf(f['maxLength']) > 0 ? intOf(f['maxLength']) : 100;

  Future<File?> _capture() async {
    final bytes = await _shot.capture(pixelRatio: 3);
    if (bytes == null) {
      Toast.error(t('cannot_capture', 'Cannot capture image'));
      return null;
    }
    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/template_${DateTime.now().millisecondsSinceEpoch}.png');
    await f.writeAsBytes(bytes);
    return f;
  }

  Future<void> _run(Future<void> Function() job) async {
    setState(() => _busy = true);
    try {
      await job();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveLocally() => _run(() async {
    final f = await _capture();
    if (f == null) return;
    final savedId = str(_tpl['savedId']).isNotEmpty ? str(_tpl['savedId']) : 'saved_${DateTime.now().millisecondsSinceEpoch}';
    final entry = {
      'savedId': savedId,
      'name': _tpl['name'],
      'originalTemplateId': str(_tpl['originalTemplateId'], str(_tpl['_id'])),
      'editedImageUri': 'file://${f.path}',
      'editedValues': {for (final e in _values.entries) e.key: e.value.text},
      'savedAt': DateTime.now().toIso8601String(),
      'imageUrl': _tpl['imageUrl'],
      'imageWidth': _tpl['imageWidth'],
      'imageHeight': _tpl['imageHeight'],
      'textFields': _tpl['textFields'],
    };
    final list = Prefs.savedTemplates.map(obj).toList();
    final i = list.indexWhere((e) => e['savedId'] == savedId);
    if (i >= 0) {
      list[i] = entry;
    } else {
      list.insert(0, entry);
    }
    await Prefs.setSavedTemplates(list);
    Toast.success(t('template_saved', 'Saved template'));
    if (mounted) context.pop();
  });

  Future<void> _download() => _run(() async {
    final f = await _capture();
    if (f == null) return;
    try {
      if (!await Gal.hasAccess()) await Gal.requestAccess();
      await Gal.putImage(f.path, album: 'BookMyPooja');
      Toast.success(t('saved_to_gallery', 'Saved to your gallery'));
    } catch (_) {
      Toast.error(t('download_failed', 'Failed to download image'));
    }
  });

  Future<void> _share() => _run(() async {
    final f = await _capture();
    if (f == null) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(f.path, mimeType: 'image/png')],
        title: str(_tpl['name']),
      ),
    );
  });

  @override
  Widget build(BuildContext context) {
    if (_loadingOriginal)
      return Scaffold(
        appBar: appBar(context, str(_tpl['name'])),
        body: const AppLoader(message: 'Loading template…'),
      );
    return Scaffold(
      backgroundColor: pageBg,
      appBar: appBar(context, str(_tpl['name'], t('template', 'Template'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          LayoutBuilder(builder: (context, box) => Center(child: _canvas(box.maxWidth))),
          const SizedBox(height: 20),
          if (_fields.isNotEmpty) ...[
            SectionTitle(t('edit_text_fields', 'Edit text'), icon: LucideIcons.type),
            const SizedBox(height: 12),
            for (final f in _fields) ...[
              AppTextField(
                controller: _values[str(f['id'])],
                label: str(f['label']),
                hint: str(f['placeholder'], 'Enter ${str(f['label'])}'),
                maxLength: _maxLen(f),
                maxLines: boolOf(f['multiline']) ? math.max(2, intOf(f['rows'], 2)) : 1,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text('${_values[str(f['id'])]?.text.length ?? 0}/${_maxLen(f)}', style: AppText.body(size: 11, color: AppColors.mutedForeground)),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
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
                  label: t('save', 'Save'),
                  kind: BtnKind.outline,
                  icon: LucideIcons.bookmark,
                  compact: true,
                  onPressed: _busy ? null : _saveLocally,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(
                  label: t('download', 'Download'),
                  kind: BtnKind.secondary,
                  icon: LucideIcons.download,
                  compact: true,
                  onPressed: _busy ? null : _download,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AppButton(label: t('share'), icon: LucideIcons.share2, compact: true, loading: _busy, onPressed: _share),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _canvas(double maxW) {
    final iw = dbl(_tpl['imageWidth'], 1080), ih = dbl(_tpl['imageHeight'], 1920);
    final maxH = MediaQuery.sizeOf(context).height * .5;
    var w = maxW, h = w / (iw / ih);
    if (h > maxH) {
      h = maxH;
      w = h * iw / ih;
    }
    final scale = math.max(w / iw, h / ih);
    final ox = (w - iw * scale) / 2, oy = (h - ih * scale) / 2;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Screenshot(
        controller: _shot,
        child: SizedBox(
          width: w,
          height: h,
          child: Stack(
            children: [
              Positioned.fill(child: NetImage(templateImageUrl(str(_tpl['imageUrl'])), fit: BoxFit.cover)),
              for (final f in _fields) _overlay(f, scale, ox, oy),
            ],
          ),
        ),
      ),
    );
  }

  Widget _overlay(Json f, double scale, double ox, double oy) {
    final value = _values[str(f['id'])]?.text ?? '';
    final text = value.isEmpty ? str(f['placeholder']) : value;
    final size = dbl(f['fontSize'], 16) * scale;
    final transform = str(f['textTransform']);
    final shown = transform == 'uppercase'
        ? text.toUpperCase()
        : transform == 'lowercase'
        ? text.toLowerCase()
        : text;
    var style = TextStyle(
      fontSize: size,
      color: _color(str(f['color'], '#000000')),
      fontWeight: str(f['fontWeight']) == 'bold' || intOf(f['fontWeight']) >= 600 ? FontWeight.w700 : FontWeight.w400,
      fontStyle: str(f['fontStyle']) == 'italic' ? FontStyle.italic : FontStyle.normal,
      decoration: str(f['textDecoration']) == 'underline' ? TextDecoration.underline : null,
      letterSpacing: dbl(f['letterSpacing']),
      height: f['lineHeight'] != null ? dbl(f['lineHeight']) : null,
      backgroundColor: str(f['backgroundColor']).isEmpty || str(f['backgroundColor']) == 'transparent' ? null : _color(str(f['backgroundColor'])),
    );
    final family = str(f['fontFamily']);
    if (family.isNotEmpty && family != 'Arial') {
      try {
        style = GoogleFonts.getFont(family, textStyle: style);
      } catch (_) {}
    }
    final align = switch (str(f['textAlign'], 'center')) {
      'left' => TextAlign.left,
      'right' => TextAlign.right,
      _ => TextAlign.center,
    };
    return Positioned(
      left: dbl(f['x']) * scale + ox,
      top: dbl(f['y']) * scale + oy,
      width: dbl(f['width'], 200) * scale,
      height: dbl(f['height'], 40) * scale,
      child: Transform.rotate(
        angle: dbl(f['rotation']) * math.pi / 180,
        child: Text(
          shown,
          textAlign: align,
          maxLines: boolOf(f['multiline']) ? math.max(1, intOf(f['rows'], 1)) : 1,
          overflow: TextOverflow.clip,
          style: style,
        ),
      ),
    );
  }

  static Color _color(String hex) {
    var h = hex.replaceFirst('#', '');
    if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
    if (h.length == 6) h = 'FF$h';
    return Color(int.tryParse(h, radix: 16) ?? 0xFF000000);
  }
}
