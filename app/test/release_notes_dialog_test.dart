import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volgatech_pro/ui/release_notes_dialog.dart';

void main() {
  testWidgets('The dialog shows its title and notes and closes on Понятно.',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) {
      return TextButton(
        onPressed: () => showDialog<void>(
          context: context,
          builder: (_) => const ReleaseNotesDialog(
            version: '13.7.26',
            lines: [
              'Keep the last filter',
              'Print room changes',
              'Find drafts'
            ],
          ),
        ),
        child: const Text('Open'),
      );
    })));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final counts = [
      for (final text in [
        'Что нового в 13.7.26',
        'Keep the last filter',
        'Print room changes',
        'Find drafts',
      ])
        find.text(text).evaluate().length,
    ];
    await tester.tap(find.text('Понятно'));
    await tester.pumpAndSettle();
    expect([
      ...counts,
      find.byType(ReleaseNotesDialog).evaluate().length
    ], [
      1,
      1,
      1,
      1,
      0
    ], reason: 'The title or bullets were missing, or the dialog stayed open.');
  });
}
