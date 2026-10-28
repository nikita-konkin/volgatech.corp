import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../web/files.dart';

const docxMime =
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

/// A report made: kept on the device (the system «save as» on Android, a
/// download in a browser) or sent through the share sheet — which on a Mac's
/// Safari has no way to save it. Each runs straight from its tap: a browser
/// takes a download or a share later than that for one it didn't ask for.
Future<void> exportDocx(BuildContext context, Uint8List bytes,
    {required String fileName, required String subject}) {
  final messenger = ScaffoldMessenger.of(context);

  Future<void> save() async {
    try {
      if (kIsWeb) {
        saveInBrowser(bytes, fileName, docxMime);
        return;
      }
      final saved = await FilePicker.saveFile(
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['docx'],
          bytes: bytes);
      if (saved != null) {
        messenger.showSnackBar(SnackBar(content: Text('Сохранено: $fileName')));
      }
    } on Object {
      messenger.showSnackBar(
          const SnackBar(content: Text('Не удалось сохранить файл')));
    }
  }

  Future<void> share() async {
    try {
      await _share(bytes, fileName, subject);
    } on Object {
      messenger.showSnackBar(
          const SnackBar(content: Text('Не удалось отправить файл')));
    }
  }

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: Text(fileName, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text(kIsWeb ? 'Скачать' : 'Сохранить в файлы'),
            onTap: () {
              unawaited(save());
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.share_outlined),
            title: const Text('Отправить…'),
            onTap: () {
              unawaited(share());
              Navigator.pop(context);
            },
          ),
        ],
      ),
    ),
  );
}

Future<void> _share(Uint8List bytes, String fileName, String subject) async {
  final XFile doc;
  if (kIsWeb) {
    // No files in a browser: the share sheet takes it from memory.
    doc = XFile.fromData(bytes, name: fileName, mimeType: docxMime);
  } else {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    doc = XFile(file.path, mimeType: docxMime);
  }
  await SharePlus.instance.share(ShareParams(
    files: [doc],
    fileNameOverrides: [fileName],
    subject: subject,
  ));
}
