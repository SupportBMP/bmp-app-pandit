import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../api/api.dart';
import 'json.dart';

const _uuid = Uuid();

String mimeOf(String path) {
  final ext = p.extension(path).toLowerCase().replaceFirst('.', '');
  return switch (ext) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    'gif' => 'image/gif',
    'pdf' => 'application/pdf',
    'mp4' => 'video/mp4',
    'mov' => 'video/quicktime',
    'doc' => 'application/msword',
    'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    _ => 'application/octet-stream',
  };
}

/// Presigned S3 upload (`getS3presignedUrl` + `uploadToS3` in the RN app).
/// Returns the public asset URL.
Future<String> uploadFile(File file, {String? folder, String? fileName, String? mime}) async {
  final type = mime ?? mimeOf(file.path);
  final ext = p.extension(file.path).replaceFirst('.', '');
  final name = fileName ?? '${_uuid.v4()}.${ext.isEmpty ? type.split('/').last : ext}';
  final res = obj(await Api.presignedUrl({'fileName': name, 'fileType': type, 'folder': ?folder}));
  final data = obj(res['data']);
  final url = str(data['presignedUrl']);
  final asset = str(data['assetUrl']);
  if (url.isEmpty) throw Exception('Upload URL not available');
  final bytes = await file.readAsBytes();
  await Dio().put(
    url,
    data: Stream.fromIterable([bytes]),
    options: Options(headers: {Headers.contentTypeHeader: type, Headers.contentLengthHeader: bytes.length}),
  );
  return asset;
}

String newId() => _uuid.v4();
