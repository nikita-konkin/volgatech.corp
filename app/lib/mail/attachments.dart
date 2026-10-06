import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:enough_convert/enough_convert.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:path_provider/path_provider.dart';

/// A received attachment's name made safe for the file system: no path
/// separators or characters Android refuses, and short enough (in UTF-8
/// bytes, which Cyrillic doubles) that the extension survives.
String attachmentFileName(String? name) {
  final clean =
      (name ?? '').replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_').trim();
  if (clean.replaceAll('.', '').isEmpty) return 'вложение';
  const maxBytes = 200;
  if (utf8.encode(clean).length <= maxBytes) return clean;
  final dot = clean.lastIndexOf('.');
  final ext = dot > 0 && clean.length - dot <= 10 ? clean.substring(dot) : '';
  var base = clean.substring(0, clean.length - ext.length).runes.toList();
  while (utf8.encode(String.fromCharCodes(base) + ext).length > maxBytes) {
    base = base.sublist(0, base.length - 1);
  }
  return String.fromCharCodes(base).trimRight() + ext;
}

/// The type to hand a viewer app: the declared one, unless it is the
/// catch-all octet-stream many mailers send — then a guess from the name, or
/// null to let the viewer guess.
String? attachmentType(String name, MediaType? declared) {
  bool known(MediaType? t) =>
      t != null && t.sub != MediaSubtype.applicationOctetStream;
  if (known(declared)) return declared!.text;
  final guess = MediaType.guessFromFileName(name);
  return known(guess) ? guess.text : null;
}

/// What the app can show itself, without another app.
enum PreviewKind { image, pdf, text }

/// How to show [name] of [type] in the app; null when only another app can.
PreviewKind? previewKind(String name, String? type) {
  final t = (type ?? '').toLowerCase();
  final dot = name.lastIndexOf('.');
  final ext = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  // What Flutter decodes itself on every phone.
  const images = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'};
  if (images.contains(ext) ||
      const {'image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/bmp'}
          .contains(t)) {
    return PreviewKind.image;
  }
  if (ext == 'pdf' || t == 'application/pdf') return PreviewKind.pdf;
  if (const {'txt', 'csv', 'log'}.contains(ext) ||
      t == 'text/plain' ||
      t == 'text/csv') {
    return PreviewKind.text;
  }
  return null;
}

/// A text file's text: UTF-8 when it is that, else Windows-1251, which
/// Russian files from Windows mostly are.
String decodeText(Uint8List bytes) {
  try {
    final text = utf8.decode(bytes);
    return text.startsWith('\uFEFF') ? text.substring(1) : text;
  } on FormatException {
    return const Windows1251Codec(allowInvalid: true).decode(bytes);
  }
}

/// Where attachments go to be opened or shared: the app's private cache,
/// which other apps reach only through the URI they are handed.
Future<Directory> _dir() async =>
    Directory('${(await getTemporaryDirectory()).path}/attachments');

/// Writes [bytes] to the private attachments folder as [name].
Future<File> attachmentFile(String name, Uint8List bytes) async {
  final dir = await _dir();
  await dir.create(recursive: true);
  return File('${dir.path}/$name').writeAsBytes(bytes, flush: true);
}

/// Forgets every attachment opened or shared, on signing out.
Future<void> clearAttachmentFiles() async {
  try {
    final dir = await _dir();
    if (await dir.exists()) await dir.delete(recursive: true);
  } on Object {
    // Only the app can read the cache; a leftover file is not worth a crash.
  }
}
