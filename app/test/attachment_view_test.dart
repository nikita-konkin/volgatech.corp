import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volgatech_pro/mail/attachments.dart';
import 'package:volgatech_pro/mail/ui/attachment_view.dart';

void main() {
  test('previewKind: pictures, PDFs and text in the app; the rest not', () {
    expect(previewKind('фото.JPG', null), PreviewKind.image);
    expect(previewKind('scan', 'image/png'), PreviewKind.image);
    expect(
        previewKind('отчёт.pdf', 'application/octet-stream'), PreviewKind.pdf);
    expect(previewKind('файл', 'application/pdf'), PreviewKind.pdf);
    expect(previewKind('список.csv', null), PreviewKind.text);
    expect(previewKind('readme', 'text/plain'), PreviewKind.text);
    expect(previewKind('отчёт.docx', null), isNull);
    expect(previewKind('фото.heic', 'image/heic'), isNull);
    expect(previewKind('архив.zip', 'application/zip'), isNull);
  });

  test('decodeText: UTF-8 (with or without a BOM), else Windows-1251', () {
    expect(decodeText(Uint8List.fromList(utf8.encode('Привет'))), 'Привет');
    expect(
        decodeText(
            Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode('Да')])),
        'Да');
    expect(decodeText(Uint8List.fromList([0xCF, 0xF0, 0xE8, 0xE2, 0xE5, 0xF2])),
        'Привет');
  });

  Widget page(ReceivedFile f) => MaterialApp(home: AttachmentViewPage(f));

  testWidgets('a text file: its text, and the bar to open, save or share',
      (tester) async {
    await tester.pumpWidget(page(ReceivedFile(
        name: 'заметка.txt',
        bytes: Uint8List.fromList(utf8.encode('Ауд. 305, в 10:00')),
        type: 'text/plain')));
    expect(find.text('заметка.txt'), findsOneWidget);
    expect(find.text('Ауд. 305, в 10:00'), findsOneWidget);
    for (final t in ['Открыть в приложении', 'Сохранить в…', 'Поделиться']) {
      expect(find.byTooltip(t), findsOneWidget, reason: t);
    }
  });

  testWidgets('a picture: shown to zoom into', (tester) async {
    final png = base64.decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=');
    await tester.pumpWidget(page(ReceivedFile(
        name: 'фото.png', bytes: Uint8List.fromList(png), type: 'image/png')));
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });
}
