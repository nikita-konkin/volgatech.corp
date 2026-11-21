import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volgatech_pro/core/prefs.dart';
import 'package:volgatech_pro/data/portal_timetable_store.dart';
import 'package:volgatech_pro/models/schedule.dart';

void main() {
  test('a failed refresh preserves the saved rows for their original person',
      () async {
    SharedPreferences.setMockInitialValues({});
    final id = Random().nextInt(25000) + 500;
    final store = PortalTimetableStore(await Prefs.load());
    addTearDown(store.dispose);
    await store.refresh(
        id,
        () async => [
              {
                'weekday': 4,
                'begin': '13:15',
                'discipline': 'Замеры радуги',
                'group': 'ЖЩ-$id',
                'form': 'оз',
                'dates': <Object?>[],
              }
            ]);
    await store.refresh(id, () async => throw StateError('Request failed'));
    final reopened = PortalTimetableStore(await Prefs.load());
    addTearDown(reopened.dispose);
    final event = ScheduleEvent(fullDescription: 'ЖЩ-$id');
    expect(
      (reopened.read(id).formFor(event), reopened.read(id + 1).formFor(event)),
      ('оз', null),
      reason:
          'the failed refresh removed the rows or exposed them to another person',
    );
  });
}
