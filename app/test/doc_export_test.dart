import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volgatech_pro/ui/doc_export.dart';

void main() {
  testWidgets('a report can be saved to files or sent', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => exportDocx(context, Uint8List(4),
              fileName: 'Отчёт октябрь 2026.docx', subject: 'Отчёт'),
          child: const Text('Сформировать'),
        ),
      ),
    ));
    await tester.tap(find.text('Сформировать'));
    await tester.pumpAndSettle();
    expect(find.text('Отчёт октябрь 2026.docx'), findsOneWidget);
    expect(find.text('Сохранить в файлы'), findsOneWidget);
    expect(find.text('Отправить…'), findsOneWidget);
  });
}
