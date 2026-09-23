import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:volgatech_pro/models/schedule.dart';
import 'package:volgatech_pro/state/schedule_controller.dart';
import 'package:volgatech_pro/ui/week_summary_page.dart';
import 'package:volgatech_pro/ui/widgets/skeleton.dart';

import 'fakes.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ru_RU'));

  testWidgets('a loading week shows placeholders, not «Нет занятий»',
      (tester) async {
    final api = FakeApi();
    final network = Completer<List<ScheduleDay>>();
    api.onSchedule = (_) => network.future;
    final c = ScheduleController(api, 7, FakeCache());
    unawaited(c.goToDay(DateTime(2026, 9, 23)));

    await tester.pumpWidget(MaterialApp(
      home: ChangeNotifierProvider<ScheduleController>.value(
        value: c,
        child: const WeekSummaryPage(),
      ),
    ));
    await tester.pump();

    expect(find.byType(SkeletonBox), findsWidgets);
    expect(find.text('Нет занятий'), findsNothing);
    expect(find.text('0 пар'), findsNothing);
    expect(find.text('Понедельник'), findsOneWidget,
        reason: 'day names are known before the data arrives');

    network.complete(const []); // the week really is empty
    await tester.pumpAndSettle();

    expect(find.byType(SkeletonBox), findsNothing);
    expect(find.text('Нет занятий'), findsWidgets);
    expect(find.text('0 пар'), findsOneWidget);
  });
}
