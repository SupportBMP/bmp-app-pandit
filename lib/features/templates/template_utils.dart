const s3AssetsBase = 'https://mob-app-assets-p.s3.ap-south-1.amazonaws.com/';

/// Template image paths are stored relative to the assets bucket.
String templateImageUrl(String? path) {
  final p = (path ?? '').trim();
  if (p.isEmpty) return '';
  if (p.startsWith('http') || p.startsWith('blob:')) return p;
  return p.startsWith('templates/') || p.startsWith('icons/') ? '$s3AssetsBase$p' : '${s3AssetsBase}templates/$p';
}
