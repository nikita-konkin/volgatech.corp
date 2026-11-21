import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volgatech_pro/core/prefs.dart';
import 'package:volgatech_pro/data/portal_timetable_store.dart';
import 'package:volgatech_pro/models/schedule.dart';
import 'package:volgatech_pro/ui/study_forms_page.dart';

Future<void> open(WidgetTester tester, Widget page) async {
  await tester.pumpWidget(MaterialApp(
    home: Builder(
        builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => page),
                ),
                child: const Text('Открыть'),
              ),
            )),
  ));
  await tester.tap(find.text('Открыть'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a completed read stores the rows and returns', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final id = 517 + Random().nextInt(23071);
    final store = PortalTimetableStore(await Prefs.load());
    await open(
        tester,
        StudyFormsPage(
          personId: id,
          store: store,
          readTimetable: () async => [
            {
              'weekday': 3,
              'begin': '14:37',
              'discipline': 'Облачные сады',
              'group': 'ФВ-$id',
              'form': 'оз',
              'dates': <Object?>[],
            },
          ],
          signInView: (_, __) => const SizedBox(),
        ));
    expect(
      (
        store.read(id).formFor(ScheduleEvent(fullDescription: 'ФВ-$id')),
        find.text('Открыть').evaluate().length
      ),
      ('оз', 1),
      reason: 'the page did not save the forms and return',
    );
  });

  testWidgets('a failed read keeps the page open with a retry', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final id = 831 + Random().nextInt(17739);
    final store = PortalTimetableStore(await Prefs.load());
    await open(
        tester,
        StudyFormsPage(
          personId: id,
          store: store,
          readTimetable: () async => throw StateError('Offline'),
          signInView: (_, __) => const SizedBox(),
        ));
    expect(find.widgetWithText(FilledButton, 'Повторить'), findsOneWidget,
        reason: 'the page did not stay open with a retry action');
  });
}
