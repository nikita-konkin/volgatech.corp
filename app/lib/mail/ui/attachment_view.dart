import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';

import '../attachments.dart';

/// A decoded attachment and what can be done with it.
class ReceivedFile {
  const ReceivedFile({required this.name, required this.bytes, this.type});
  final String name;
  final Uint8List bytes;
  final String? type;

  PreviewKind? get preview => previewKind(name, type);

  /// In whichever app handles the type (a PDF reader, Word, a gallery…).
  Future<void> open(ScaffoldMessengerState messenger) async {
    final file = await attachmentFile(name, bytes);
    final result = await OpenFilex.open(file.path, type: type);
    switch (result.type) {
      case ResultType.done:
        return;
      case ResultType.noAppToOpen:
        messenger.showSnackBar(SnackBar(
          content: const Text('Нет приложения, чтобы открыть этот файл'),
          // Goes after its duration (with an action Flutter would keep it).
          persist: false,
          action: SnackBarAction(
              label: 'Сохранить', onPressed: () => unawaited(save(messenger))),
        ));
      case _:
        messenger.showSnackBar(
            const SnackBar(content: Text('Не удалось открыть файл')));
    }
  }

  /// Through the system «save as» dialog — Загрузки or any folder, drive.
  Future<void> save(ScaffoldMessengerState messenger) async {
    try {
      final saved = await FilePicker.saveFile(fileName: name, bytes: bytes);
      if (saved != null) {
        messenger.showSnackBar(SnackBar(content: Text('Сохранено: $name')));
      }
    } on Object {
      messenger.showSnackBar(
          const SnackBar(content: Text('Не удалось сохранить файл')));
    }
  }

  Future<void> share() async {
    final file = await attachmentFile(name, bytes);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: type)],
    ));
  }
}

/// A picture, PDF or text attachment shown in the app: pinch to zoom, PDF
/// pages one under another; the bar opens it elsewhere, saves or shares it.
class AttachmentViewPage extends StatelessWidget {
  const AttachmentViewPage(this.file, {super.key});
  final ReceivedFile file;

  @override
  Widget build(BuildContext context) {
    final messenger = ScaffoldMessenger.of(context);
    final kind = file.preview;
    return Scaffold(
      backgroundColor: kind == PreviewKind.text ? null : Colors.black,
      appBar: AppBar(
        title: Text(file.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Открыть в приложении',
            icon: const Icon(Icons.open_in_new),
            onPressed: () => unawaited(file.open(messenger)),
          ),
          IconButton(
            tooltip: 'Сохранить в…',
            icon: const Icon(Icons.download_outlined),
            onPressed: () => unawaited(file.save(messenger)),
          ),
          IconButton(
            tooltip: 'Поделиться',
            icon: const Icon(Icons.share_outlined),
            onPressed: () => unawaited(file.share()),
          ),
        ],
      ),
      body: switch (kind) {
        PreviewKind.image => _Picture(file),
        PreviewKind.pdf => _Pdf(file),
        PreviewKind.text => _Text(file),
        null => const _Unshown(),
      },
    );
  }
}

class _Picture extends StatelessWidget {
  const _Picture(this.file);
  final ReceivedFile file;

  @override
  Widget build(BuildContext context) => InteractiveViewer(
        maxScale: 8,
        child: Center(
          child: Image.memory(
            file.bytes,
            semanticLabel: file.name,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => const _Unshown(),
          ),
        ),
      );
}

class _Pdf extends StatefulWidget {
  const _Pdf(this.file);
  final ReceivedFile file;

  @override
  State<_Pdf> createState() => _PdfState();
}

class _PdfState extends State<_Pdf> {
  late final _controller =
      PdfControllerPinch(document: PdfDocument.openData(widget.file.bytes));
  int _page = 1;
  int? _pages;
  bool _failed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const _Unshown();
    return Stack(
      children: [
        PdfViewPinch(
          controller: _controller,
          backgroundDecoration: const BoxDecoration(color: Colors.black),
          onDocumentLoaded: (d) => setState(() => _pages = d.pagesCount),
          onPageChanged: (p) => setState(() => _page = p),
          onDocumentError: (_) => setState(() => _failed = true),
        ),
        if (_pages case final n? when n > 1)
          Positioned(
            right: 12,
            bottom: 12 + MediaQuery.paddingOf(context).bottom,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Text('$_page / $n',
                    style: const TextStyle(color: Colors.white)),
              ),
            ),
          ),
      ],
    );
  }
}

class _Text extends StatelessWidget {
  const _Text(this.file);
  final ReceivedFile file;

  /// Beyond this a phone scrolls for ever; the rest is for another app.
  static const _limit = 200000;

  @override
  Widget build(BuildContext context) {
    final all = decodeText(file.bytes);
    final cut = all.length > _limit;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 16 + MediaQuery.paddingOf(context).bottom),
      child: SelectableText(
        cut ? '${all.substring(0, _limit)}\n\n… (дальше — в приложении)' : all,
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
      ),
    );
  }
}

class _Unshown extends StatelessWidget {
  const _Unshown();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
              'Не получилось показать файл здесь. Откройте его в приложении '
              '(кнопка вверху).',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70)),
        ),
      );
}
