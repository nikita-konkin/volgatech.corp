import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volgatech_pro/core/prefs.dart';
import 'package:volgatech_pro/ui/study_forms_hint.dart';

Future<void> showHint(
  WidgetTester tester,
  Prefs prefs, {
  required bool hasForms,
  required bool hasLessons,
}) =>
    tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: StudyFormsHint(
      prefs: prefs,
      hasForms: hasForms,
      hasLessons: hasLessons,
      onOpen: () {},
    ))));

void main() {
  testWidgets('the hint shows on a day with lessons and no cached forms',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await showHint(tester, await Prefs.load(),
        hasForms: false, hasLessons: true);
    expect(find.textContaining('Показать форму обучения групп'), findsOneWidget,
        reason: 'the hint did not appear above the lessons');
  });

  testWidgets('the hint is hidden when forms are cached', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await showHint(tester, await Prefs.load(),
        hasForms: true, hasLessons: true);
    expect(find.byTooltip('Не показывать'), findsNothing,
        reason: 'the hint did not go away after forms were cached');
  });

  testWidgets('the hint is hidden on a day without lessons', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await showHint(tester, await Prefs.load(),
        hasForms: false, hasLessons: false);
    expect(find.byTooltip('Не показывать'), findsNothing,
        reason: 'the hint did not stay hidden on an empty day');
  });

  testWidgets('dismissing the hint keeps it hidden when reopened',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await showHint(tester, await Prefs.load(),
        hasForms: false, hasLessons: true);
    await tester.tap(find.byTooltip('Не показывать'));
    await tester.pumpWidget(const SizedBox());
    final prefs = await Prefs.load();
    await prefs.reload();
    await showHint(tester, prefs, hasForms: false, hasLessons: true);
    expect(find.byTooltip('Не показывать'), findsNothing,
        reason: 'the dismissal did not survive reopening the timetable');
  });
}
