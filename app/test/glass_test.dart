import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volgatech_pro/core/prefs.dart';
import 'package:volgatech_pro/state/theme_controller.dart';
import 'package:volgatech_pro/theme.dart';
import 'package:volgatech_pro/ui/glass.dart';

void main() {
  // WCAG AA: 4.5 for text, AAA 7 for the main text where we can.
  group('glass text reads on every part of the wallpaper', () {
    for (final (dark, scuffed, strength) in [
      for (final dark in [false, true])
        for (final scuffed in [false, true])
          // Matte glass is as thick at any wear; see the wear's own test.
          for (final strength in scuffed ? [1.0] : [1.0, 0.75, 0.5, 0.25, 0.0])
            (dark, scuffed, strength),
    ]) {
      final theme = dark
          ? buildDarkTheme(
              browser: true, glass: true, scuffed: scuffed, strength: strength)
          : buildLightTheme(
              browser: true, glass: true, scuffed: scuffed, strength: strength);
      final scheme = theme.colorScheme;
      final glass = theme.extension<Glass>()!;
      final name = '${dark ? 'dark' : 'light'}${scuffed ? ', matte' : ''}'
          '${strength < 1 ? ', ${(strength * 100).round()} %' : ''}';

      test('$name: cards', () {
        for (final wall in wallpaperColors(glass)) {
          final card = composite(scheme.surface, wall);
          expect(contrast(composite(scheme.onSurface, card), card),
              greaterThanOrEqualTo(7),
              reason: '$wall');
          expect(contrast(composite(scheme.onSurfaceVariant, card), card),
              greaterThanOrEqualTo(4.5),
              reason: 'muted on $wall');
          final room = Brand.roomFor(dark: dark, glass: true);
          expect(contrast(room, card), greaterThanOrEqualTo(4.5),
              reason: 'room on $wall');
        }
      });

      test('$name: the top bar', () {
        for (final wall in wallpaperColors(glass)) {
          final bar = composite(theme.appBarTheme.backgroundColor!, wall);
          expect(contrast(theme.appBarTheme.foregroundColor!, bar),
              greaterThanOrEqualTo(7),
              reason: '$wall');
        }
      });

      test('$name: the menu', () {
        for (final wall in wallpaperColors(glass)) {
          final panel = composite(glass.panel, wall);
          expect(contrast(composite(scheme.onSurface, panel), panel),
              greaterThanOrEqualTo(7),
              reason: '$wall');
          expect(contrast(composite(scheme.onSurfaceVariant, panel), panel),
              greaterThanOrEqualTo(4.5),
              reason: 'a subtitle on $wall');
          final lens = composite(glass.lens, panel);
          expect(contrast(scheme.primary, lens), greaterThanOrEqualTo(4.5),
              reason: 'the selected item on $wall');
        }
      });

      // The day, the month, the study year.
      test('$name: white on the coloured bars', () {
        for (final colour in [
          Brand.weekAccentFor(1, dark: dark),
          Brand.weekAccentFor(2, dark: dark),
          Brand.weekAccentFor(null, dark: dark),
          Brand.blue,
          Brand.coral,
        ]) {
          for (final wall in wallpaperColors(glass)) {
            for (final end in AccentBar.pill(colour)) {
              expect(contrast(Colors.white, composite(end, wall)),
                  greaterThanOrEqualTo(4.5),
                  reason: '$colour on $wall');
            }
          }
        }
      });

      test('$name: dialogs, sheets and menus stay solid', () {
        for (final c in [
          scheme.surfaceContainerLow,
          scheme.surfaceContainer,
          scheme.surfaceContainerHigh,
          scheme.surfaceContainerHighest,
        ]) {
          expect(c.a, 1.0);
        }
      });
    }
  });

  test('the strength slider: full is as designed, none is solid glass', () {
    for (final g in [
      Glass.light,
      Glass.dark,
      Glass.scuffedLight,
      Glass.scuffedDark,
    ]) {
      expect(identical(g.scaled(1), g), isTrue);
      final none = g.scaled(0);
      expect(none.card, g.solid);
      expect(none.panel, g.solid);
      expect(none.bar, g.solid);
      expect(none.grain, 0);
      expect(none.wear, 0);
      expect(none.blur, 0);
      expect(none.blobs.every((b) => b.a == 0), isTrue);
      final half = g.scaled(0.5);
      expect(half.card.a, inInclusiveRange(g.card.a, 1));
      expect(half.blur, 12);
    }
    expect(Glass.off.scaled(0.3).on, isFalse);
  });

  test('thickening glass looks halfway between, over anything', () {
    const solid = Color(0xFF14182A), clear = Color(0x0FFFFFFF);
    for (final below in [Colors.black, Colors.white, const Color(0xFF254272)]) {
      final half = composite(mixOver(solid, clear, 0.5), below);
      final expected =
          Color.lerp(composite(solid, below), composite(clear, below), 0.5)!;
      expect(half.r, closeTo(expected.r, 0.002));
      expect(half.g, closeTo(expected.g, 0.002));
      expect(half.b, closeTo(expected.b, 0.002));
    }
  });

  for (final wear in [0.0, 0.4, 1.0]) {
    testWidgets('matte glass worn to ${(wear * 100).round()} %: drawn',
        (tester) async {
      final theme = buildLightTheme(
          browser: true, glass: true, scuffed: true, wear: wear);
      expect(theme.extension<Glass>()!.scuffed, isTrue);
      expect(theme.extension<Glass>()!.wear, wear);
      expect(GlassTexture.grain, isNotNull);
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Builder(
            builder: (context) => Container(
              width: 200,
              height: 80,
              decoration: cardDecoration(
                  context,
                  const BoxDecoration(
                      border: Border(
                          left: BorderSide(color: Colors.red, width: 5))),
                  seed: 'a lesson'),
            ),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
      final box = tester.widget<Container>(find.byType(Container).last);
      expect(box.decoration, isA<GlassDecoration>());
      expect((box.decoration! as GlassDecoration).seed, 'a lesson'.hashCode);
    });
  }

  group('wear on matte glass', () {
    const card = Size(360, 90);
    double length(Iterable<WearMark> marks) => [
          for (final m in marks)
            for (final metric in m.path.computeMetrics()) metric.length
        ].fold(0.0, (a, b) => a + b);
    Iterable<WearMark> scratches(GlassWear w) =>
        w.marks.where((m) => !m.lit && m.width == null);
    Iterable<WearMark> cracks(GlassWear w) =>
        w.marks.where((m) => !m.lit && m.width != null);

    test('as new, none; then more and longer scratches; cracks past half', () {
      expect(GlassWear.of(card, 0, 1).marks, isEmpty);
      var scratched = 0.0, cracked = 0.0;
      for (final wear in [0.2, 0.4, 0.6, 0.8, 1.0]) {
        final w = GlassWear.of(card, wear, 1);
        final s = length(scratches(w)), c = length(cracks(w));
        expect(s, greaterThan(scratched), reason: 'scratches at $wear');
        if (wear <= 0.5) {
          expect(c, 0, reason: 'no cracks yet at $wear');
        } else {
          expect(c, greaterThan(cracked), reason: 'cracks at $wear');
        }
        scratched = s;
        cracked = c;
      }
    });

    test('a crack only grows: what it was, it still is', () {
      Rect bounds(GlassWear w) => cracks(w)
          .map((m) => m.path.getBounds())
          .where((b) => !b.isEmpty)
          .reduce((a, b) => a.expandToInclude(b));
      final half = bounds(GlassWear.of(card, 0.75, 3));
      final full = bounds(GlassWear.of(card, 1, 3));
      expect(full.inflate(0.01).contains(half.topLeft), isTrue);
      expect(full.inflate(0.01).contains(half.bottomRight), isTrue);
      expect(full.width * full.height, greaterThan(half.width * half.height));
    });

    test('each card its own, and the same each time', () {
      final a = GlassWear.of(card, 0.6, 'one'.hashCode);
      final b = GlassWear.of(card, 0.6, 'two'.hashCode);
      expect(scratches(a).last.path.getBounds(),
          isNot(scratches(b).last.path.getBounds()));
      expect(GlassWear.of(card, 0.6, 'one'.hashCode), same(a));
    });

    // Where a scratch or crack runs under text, the text still reads.
    for (final dark in [false, true]) {
      test('${dark ? 'dark' : 'light'}: text over the deepest marks', () {
        final theme = (dark ? buildDarkTheme : buildLightTheme)(
            browser: true, glass: true, scuffed: true, wear: 1);
        final glass = theme.extension<Glass>()!;
        for (final wall in wallpaperColors(glass)) {
          final under = composite(theme.colorScheme.surface, wall);
          for (final mark in [glass.scratch, glass.glint]) {
            final marked = composite(mark, under);
            expect(
                contrast(
                    composite(theme.colorScheme.onSurface, marked), marked),
                greaterThanOrEqualTo(4.5),
                reason: '$mark on $wall');
          }
        }
      });
    }
  });

  test('clear glass keeps its strength, matte its wear', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = Prefs(await SharedPreferences.getInstance());
    final theme = ThemeController(prefs);
    expect(theme.strength, 1);
    expect(theme.wear, 0.4);
    await theme.setWear(0.9);
    await theme.setStrength(0.3);
    final again = ThemeController(prefs);
    expect(again.wear, 0.9);
    expect(again.strength, 0.3);
  });

  test('without glass the theme is as before', () {
    final t = buildLightTheme(browser: true);
    expect(t.extension<Glass>()!.on, isFalse);
    expect(t.scaffoldBackgroundColor, Brand.bgLight);
    expect(t.colorScheme.surface, Brand.surfaceLight);
    expect(t.appBarTheme.backgroundColor, Brand.blue);
  });

  testWidgets('turning glass on or off keeps each page as it was',
      (tester) async {
    final on = ValueNotifier(false);
    await tester.pumpWidget(ValueListenableBuilder<bool>(
      valueListenable: on,
      builder: (_, glass, __) => MaterialApp(
        theme: buildLightTheme(browser: true, glass: glass),
        home: const _Counter(),
      ),
    ));
    await tester.tap(find.byType(FloatingActionButton));
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pump();
    expect(find.text('2'), findsOneWidget);

    on.value = true;
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget, reason: 'the page kept its state');
    expect(Glass.of(tester.element(find.text('2'))).on, isTrue);
    expect(find.byType(Wallpaper), findsOneWidget);

    on.value = false;
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
  });
}

class _Counter extends StatefulWidget {
  const _Counter();

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  var _n = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(child: Text('$_n')),
        floatingActionButton:
            FloatingActionButton(onPressed: () => setState(() => _n++)),
      );
}
