// The app's screens with made-up data, the real font and a size to fit:
// shared by the layout tests (iphone_layout_test, desktop_layout_test).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volgatech_pro/core/app_lock.dart';
import 'package:volgatech_pro/core/cache.dart';
import 'package:volgatech_pro/core/crash_log.dart';
import 'package:volgatech_pro/core/lesson_reminders.dart';
import 'package:volgatech_pro/core/lesson_widget.dart';
import 'package:volgatech_pro/core/photo_store.dart';
import 'package:volgatech_pro/core/prefs.dart';
import 'package:volgatech_pro/core/session.dart';
import 'package:volgatech_pro/data/volgatech_api.dart';
import 'package:volgatech_pro/models/exams.dart';
import 'package:volgatech_pro/models/profile.dart';
import 'package:volgatech_pro/models/schedule.dart';
import 'package:volgatech_pro/state/auth_controller.dart';
import 'package:volgatech_pro/state/theme_controller.dart';
import 'package:volgatech_pro/state/updater.dart';
import 'package:volgatech_pro/theme.dart';
import 'package:volgatech_pro/web/insets.dart';

import 'fakes.dart';

class _Api extends FakeApi {
  @override
  Future<List<StudyYear>> getStudyYears(int personId) async =>
      const [StudyYear(value: 2025, name: '2025 / 2026')];

  @override
  Future<List<Exam>> getExams(int personId, int year) async => [
        Exam(
          examDate: DateTime(2026, 1, 15, 9),
          subjectName: 'Проектирование систем искусственного интеллекта в '
              'спутниковой и наземной связи',
          groupName: 'ИСТм-11',
          buildingName: 'III',
          roomName: '333г',
        ),
      ];
}

const _profile = PersonProfile(
  personId: 7,
  personFIO: 'Константинопольский Александр Владимирович',
  salaries: [
    SalaryEntry(
      postName: 'Старший преподаватель',
      departmentName: 'Кафедра информационных и телекоммуникационных '
          'технологий и систем связи',
      isMainJob: true,
      salary: 100,
      salaryType: 1,
    ),
    SalaryEntry(
      postName: 'Почасовик',
      departmentName: 'Институт дополнительного профессионального образования',
      salary: 120,
      salaryType: 2,
    ),
  ],
  experiences: [ExperienceEntry(typeName: 'Общий стаж', year: 12, month: 4)],
);

ScheduleEvent _lesson(String begin, String end, String subject, String groups,
        {String type = 'Лекции', String room = '333г (III)'}) =>
    ScheduleEvent(
      timeBegin: '$begin:00',
      timeEnd: '$end:00',
      description: subject,
      fullDescription: groups,
      typeWorkName: type,
      room: room,
      weekNumber: 1,
      category: 'TimeTable',
    );

/// Russian dates, and the real face: the test font's square glyphs are far
/// wider. Text in a style without a family still gets the test font, so
/// none may lack it.
Future<void> setUpScreens() async {
  await initializeDateFormatting('ru_RU');
  final roboto = FontLoader('Roboto');
  for (final f in ['Regular', 'Medium', 'Bold']) {
    roboto.addFont(File('assets/fonts/Roboto-$f.ttf')
        .readAsBytes()
        .then((b) => ByteData.view(Uint8List.fromList(b).buffer)));
  }
  await roboto.load();
}

/// The app around [home], signed in unless [status] says otherwise, with
/// three lessons every day; [insets] are Safari's on an iPhone; in [theme],
/// or the plain light one.
Future<Widget> screensApp(Widget home,
    {EdgeInsets insets = EdgeInsets.zero,
    AuthStatus status = AuthStatus.authenticated,
    ThemeData? theme}) async {
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({});
  final prefs = await Prefs.load();
  final cache = FakeCache();
  final api = _Api()
    ..onSchedule = (monday) async => [
          for (var d = 0; d < 7; d++)
            day(DateTime(monday.year, monday.month, monday.day + d), [
              _lesson(
                  '08:00',
                  '09:30',
                  'Проектирование систем искусственного '
                      'интеллекта в спутниковой и наземной связи',
                  'ИСТ-43'),
              _lesson('09:45', '11:15', 'Системы искусственного интеллекта',
                  'ИСТм-11',
                  type: 'Лабораторные'),
              _lesson('11:30', '13:00', 'Введение в инженерную деятельность',
                  'ИСТ-110',
                  type: 'Практические'),
            ]),
        ];
  final auth = AuthController(api, Session(), cache)
    ..status = status
    ..personId = 7
    ..profile = _profile;
  // A new app each time, not the last one's routes with a new home.
  return KeyedSubtree(
    key: UniqueKey(),
    child: MultiProvider(
      providers: [
        Provider<VolgatechApi>.value(value: api),
        Provider<JsonCache>.value(value: cache),
        Provider<Prefs>.value(value: prefs),
        ChangeNotifierProvider(create: (_) => CrashLog(prefs)),
        Provider<PhotoStore>.value(value: PhotoStore(api, cache)),
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider(create: (_) => ThemeController(prefs)),
        ChangeNotifierProvider(create: (_) => AppLock(prefs)),
        ChangeNotifierProvider(
            create: (_) => Updater(prefs: prefs, enabled: false)),
        ChangeNotifierProvider(
            create: (_) => LessonReminders(prefs, FakeReminders())),
        Provider(
            create: (_) => LessonWidget(
                channel: const MethodChannel('test/lesson_widget'))),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme ?? buildLightTheme(browser: true),
        locale: const Locale('ru'),
        supportedLocales: const [Locale('ru')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // As app.dart has it, with Safari's insets.
        builder: (context, child) =>
            BrowserInsets(insets: ValueNotifier(insets), child: child!),
        home: home,
      ),
    ),
  );
}

/// Long names scroll on their own, and placeholders shimmer: no settling.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

/// Lets the names' pending scroll delays run out before the test ends.
Future<void> closeScreens(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 2));
}
