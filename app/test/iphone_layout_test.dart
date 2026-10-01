// Every screen of the web build at the size of each iPhone it may open on,
// with that model's status bar and home indicator: nothing may overflow.
import 'dart:io';

import 'package:flutter/foundation.dart';
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
import 'package:volgatech_pro/ui/exams_page.dart';
import 'package:volgatech_pro/ui/foreign_memo_page.dart';
import 'package:volgatech_pro/ui/login_page.dart';
import 'package:volgatech_pro/ui/profile_page.dart';
import 'package:volgatech_pro/ui/schedule_page.dart';
import 'package:volgatech_pro/ui/settings_page.dart';
import 'package:volgatech_pro/web/insets.dart';

import 'fakes.dart';

/// Points, portrait, as a home-screen web app: the status bar (taller with
/// a notch or Dynamic Island) and the home indicator.
const iphones = <(String, Size, EdgeInsets)>[
  ('SE (1st gen)', Size(320, 568), EdgeInsets.only(top: 20)),
  ('SE (2nd/3rd gen), 8', Size(375, 667), EdgeInsets.only(top: 20)),
  ('8 Plus', Size(414, 736), EdgeInsets.only(top: 20)),
  ('X, XS, 11 Pro', Size(375, 812), EdgeInsets.only(top: 44, bottom: 34)),
  ('12 mini, 13 mini', Size(375, 812), EdgeInsets.only(top: 50, bottom: 34)),
  ('XR, 11', Size(414, 896), EdgeInsets.only(top: 48, bottom: 34)),
  ('12, 13, 14', Size(390, 844), EdgeInsets.only(top: 47, bottom: 34)),
  ('14 Pro, 15, 16', Size(393, 852), EdgeInsets.only(top: 59, bottom: 34)),
  ('16 Pro, 17 Pro', Size(402, 874), EdgeInsets.only(top: 62, bottom: 34)),
  (
    '12/13 Pro Max, 14 Plus',
    Size(428, 926),
    EdgeInsets.only(top: 47, bottom: 34)
  ),
  (
    '14 Pro Max … 16 Plus',
    Size(430, 932),
    EdgeInsets.only(top: 59, bottom: 34)
  ),
  (
    '16 Pro Max, 17 Pro Max',
    Size(440, 956),
    EdgeInsets.only(top: 62, bottom: 34)
  ),
  // Turned: the Dynamic Island on the left.
  (
    '15 landscape',
    Size(852, 393),
    EdgeInsets.only(left: 59, right: 59, bottom: 21)
  ),
];

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

ScheduleEvent _lesson(String begin, String subject, String groups,
        {String type = 'Лекции', String room = '333г (III)'}) =>
    ScheduleEvent(
      timeBegin: '$begin:00',
      timeEnd: '$begin:00',
      description: subject,
      fullDescription: groups,
      typeWorkName: type,
      room: room,
      weekNumber: 1,
      category: 'TimeTable',
    );

/// Texts drawn where the phone covers them: under the status bar or a side's
/// notch, or — unless they scroll there — under the home indicator.
List<String> underInsets(Size size, EdgeInsets insets) {
  final screen = Offset.zero & size;
  final safe = insets.deflateRect(screen);
  return [
    for (final e in find.byType(RichText).evaluate())
      if (_drawn(e, screen) case (final rect, final scrolls)
          when rect.top < safe.top - 0.5 ||
              rect.left < safe.left - 0.5 ||
              rect.right > safe.right + 0.5 ||
              (!scrolls && rect.bottom > safe.bottom + 0.5))
        '${(e.widget as RichText).text.toPlainText()} at $rect',
  ];
}

/// Where [e]'s text shows on [screen], cut by the lists it is in; null when
/// it doesn't show.
(Rect, bool)? _drawn(Element e, Rect screen) {
  final box = e.renderObject! as RenderBox;
  var rect = (box.localToGlobal(Offset.zero) & box.size).intersect(screen);
  var scrolls = false;
  e.visitAncestorElements((a) {
    if (a.widget is Scrollable) {
      scrolls = true;
      final view = a.renderObject! as RenderBox;
      rect = rect.intersect(view.localToGlobal(Offset.zero) & view.size);
    }
    return true;
  });
  return rect.width > 0 && rect.height > 0 ? (rect, scrolls) : null;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru_RU');
    // The real face: the test font's square glyphs are far wider. Text in a
    // style without a family still gets the test font, so none may lack it.
    final roboto = FontLoader('Roboto');
    for (final f in ['Regular', 'Medium', 'Bold']) {
      roboto.addFont(File('assets/fonts/Roboto-$f.ttf')
          .readAsBytes()
          .then((b) => ByteData.view(Uint8List.fromList(b).buffer)));
    }
    await roboto.load();
  });

  Future<Widget> app(Widget home, EdgeInsets insets,
      {AuthStatus status = AuthStatus.authenticated}) async {
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
                    'Проектирование систем искусственного '
                        'интеллекта в спутниковой и наземной связи',
                    'ИСТ-43'),
                _lesson('09:45', 'Системы искусственного интеллекта', 'ИСТм-11',
                    type: 'Лабораторные'),
                _lesson(
                    '11:30', 'Введение в инженерную деятельность', 'ИСТ-110',
                    type: 'Практические'),
              ]),
          ];
    final auth = AuthController(api, Session(), cache)
      ..status = status
      ..personId = 7
      ..profile = _profile;
    return MultiProvider(
      providers: [
        Provider<VolgatechApi>.value(value: api),
        Provider<JsonCache>.value(value: cache),
        Provider<Prefs>.value(value: prefs),
        Provider<PhotoStore>.value(value: PhotoStore(api, cache)),
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider(create: (_) => ThemeController(prefs)),
        ChangeNotifierProvider(create: (_) => AppLock(prefs)),
        ChangeNotifierProvider(
            create: (_) => Updater(prefs: prefs, enabled: false)),
      ],
      child: MaterialApp(
        theme: buildLightTheme(browser: true),
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
    );
  }

  // Long names scroll on their own, and placeholders shimmer: no settling.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  // Safari on an iPhone: Flutter takes the platform to be iOS.
  final ios = TargetPlatformVariant.only(TargetPlatform.iOS);
  for (final (model, size, insets) in iphones) {
    testWidgets('iPhone $model: every screen fits', (tester) async {
      // The web engine reports no insets: BrowserInsets brings them.
      tester.view
        ..devicePixelRatio = 3
        ..physicalSize = size * 3;
      addTearDown(tester.view.reset);

      /// Nothing overflows, and nothing is drawn where the phone covers it.
      void clear(String screen) {
        expect(tester.takeException(), isNull, reason: '$model: $screen');
        expect(underInsets(size, insets), isEmpty,
            reason: '$model: $screen — text under the status bar, the notch '
                'or the home indicator');
      }

      /// [page] has to show [shows] — its data, not a spinner — and fit.
      Future<void> check(String screen, Widget page, String shows,
          {AuthStatus status = AuthStatus.authenticated,
          Future<void> Function()? then}) async {
        // A new app each time, not the last one's routes with a new home.
        await tester.pumpWidget(KeyedSubtree(
            key: UniqueKey(), child: await app(page, insets, status: status)));
        await settle(tester);
        expect(find.textContaining(shows), findsWidgets,
            reason: '$model: $screen');
        clear(screen);
        await then?.call();
        clear(screen);
      }

      // kIsWeb is false here, so this is the app's login page; the web one,
      // whose banner runs up behind the clock, is the same below it.
      await check('Вход', const LoginPage(), 'ВОЙТИ',
          status: AuthStatus.unauthenticated);
      await check('Расписание', const SchedulePage(), 'Системы искусственного',
          then: () async {
        // The menu, and the week overview.
        final scaffold = tester
            .state<ScaffoldState>(find.byType(Scaffold).first)
          ..openDrawer();
        await settle(tester);
        clear('меню');
        scaffold.closeDrawer();
        await settle(tester);
        await tester.tap(find.byTooltip('Обзор недели'));
        await settle(tester);
        expect(find.text('Обзор недели'), findsOneWidget);
      });
      await check('Профиль', const ProfilePage(), 'Константинопольский');
      await check('Экзамены', const ExamsPage(), 'Проектирование систем');
      await check('Иностранные группы', const ForeignMemoPage(), 'ИСТ-110');
      await check('Настройки', const SettingsPage(), 'Тема оформления');
      // Lets the names' pending scroll delays run out.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    }, variant: ios);
  }
}
