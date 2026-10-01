// Every screen of the web build at the size of each iPhone it may open on,
// with that model's status bar and home indicator: nothing may overflow.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volgatech_pro/state/auth_controller.dart';
import 'package:volgatech_pro/ui/exams_page.dart';
import 'package:volgatech_pro/ui/foreign_memo_page.dart';
import 'package:volgatech_pro/ui/home_shell.dart';
import 'package:volgatech_pro/ui/login_page.dart';
import 'package:volgatech_pro/ui/profile_page.dart';
import 'package:volgatech_pro/ui/settings_page.dart';

import 'screens_harness.dart';

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
  setUpAll(setUpScreens);

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
        await tester
            .pumpWidget(await screensApp(page, insets: insets, status: status));
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
      await check('Расписание', const HomeShell(), 'Системы искусственного',
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
      await closeScreens(tester);
    }, variant: ios);
  }
}
