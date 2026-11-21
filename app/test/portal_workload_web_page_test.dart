import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volgatech_pro/core/portal_workload.dart';
import 'package:volgatech_pro/models/schedule.dart';
import 'package:volgatech_pro/ui/portal_workload_web_page.dart';

import 'fakes.dart';

void main() {
  testWidgets('the browser page shows timetable hours for the default month',
      (tester) async {
    final random = Random();
    final subject = 'Геодезия №${random.nextInt(283) + 17}';
    final group = 'СТ-${random.nextInt(91) + 13}';
    final today = DateTime.now().toUtc().add(const Duration(hours: 3));
    final month = workloadMonth(today);
    final api = FakeApi()
      ..onSchedule = (_) async => [
            ScheduleDay(date: month, events: [
              ScheduleEvent(
                category: 'TimeTable',
                description: subject,
                typeWorkName: 'Практические',
                fullDescription: group,
                room: '412а',
                timeBegin: '12:19',
              ),
            ])
          ];
    await tester.pumpWidget(MaterialApp(
      home: PortalWorkloadWebPage(api: api, personId: random.nextInt(731) + 42),
    ));
    await tester.pumpAndSettle();
    expect(
      find.ancestor(
        of: find.text('Практические · $group · 2 ч.'),
        matching: find.widgetWithText(ListTile, subject),
      ),
      findsOneWidget,
      reason: 'the default month did not show the lesson with its hours',
    );
  });
}
