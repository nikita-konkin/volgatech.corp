import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
