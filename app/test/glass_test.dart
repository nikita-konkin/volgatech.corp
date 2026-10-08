import 'dart:math' as math;

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
          // Matte glass is as thick however much ornament; see its tests.
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
      expect(none.ornament, g.ornament,
          reason: 'the ornament has a slider of its own');
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

  for (final (scuffed, season, grown) in [
    for (final scuffed in [true, false])
      for (final grown in [0.0, 0.5, 1.0]) (scuffed, Season.winter, grown),
    for (final season in Season.values) (false, season, 1.0),
  ]) {
    testWidgets(
        '${scuffed ? 'matte' : 'clear'} glass, ${season.name} '
        '${(grown * 100).round()} %: drawn', (tester) async {
      final theme = buildLightTheme(
          browser: true,
          glass: true,
          scuffed: scuffed,
          ornament: grown,
          season: season);
      expect(theme.extension<Glass>()!.scuffed, scuffed);
      expect(theme.extension<Glass>()!.ornament, grown);
      expect(theme.extension<Glass>()!.season, season);
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

  test('the season by the calendar', () {
    for (final (month, season) in [
      (12, Season.winter),
      (1, Season.winter),
      (2, Season.winter),
      (3, Season.spring),
      (5, Season.spring),
      (6, Season.summer),
      (8, Season.summer),
      (9, Season.autumn),
      (11, Season.autumn),
    ]) {
      expect(Season.of(DateTime(2026, month, 15)), season, reason: '$month');
    }
  });

  group('the ornament', () {
    const card = Size(360, 90);
    double length(GlassOrnament o) => [
          for (final m in o.marks)
            for (final metric in m.path.computeMetrics()) metric.length
        ].fold(0.0, (a, b) => a + b);
    Rect bounds(GlassOrnament o) => o.marks
        .map((m) => m.path.getBounds())
        .where((b) => !b.isEmpty)
        .reduce((a, b) => a.expandToInclude(b));
    // Each group's line, as far as it shows: on the glass.
    List<(int, List<Offset>)> shown(Size size, int seed, Season season) => [
          for (final s in GlassOrnament.strokes(size, seed, season))
            (
              s.group,
              [
                for (final p in s.line)
                  if ((Offset.zero & size).inflate(0.5).contains(p)) p
              ]
            ),
        ];

    for (final season in Season.values) {
      group(season.name, () {
        test('none at first; then more of it', () {
          expect(GlassOrnament.of(card, 0, 1, season).marks, isEmpty);
          var before = 0.0;
          for (final grown in [0.1, 0.3, 0.5, 0.7, 0.9, 1.0]) {
            final now = length(GlassOrnament.of(card, grown, 1, season));
            expect(now, greaterThan(before), reason: 'at $grown');
            before = now;
          }
        });

        test('it only grows: what was there, still is', () {
          for (final seed in [1, 2, 3]) {
            final some = bounds(GlassOrnament.of(card, 0.4, seed, season));
            final full =
                bounds(GlassOrnament.of(card, 1, seed, season)).inflate(1);
            expect(full.contains(some.topLeft), isTrue, reason: '$seed');
            expect(full.contains(some.bottomRight), isTrue, reason: '$seed');
          }
        });

        test('they meet without crossing', () {
          for (final size in [
            card,
            const Size(300, 900),
            const Size(200, 60)
          ]) {
            for (final seed in [1, 2, 3, 4]) {
              final groups = shown(size, seed, season);
              expect(groups.map((g) => g.$1).toSet().length, greaterThan(2),
                  reason: '$size, $seed: several');
              var nearest = double.infinity;
              for (final (a, one) in groups) {
                for (final (b, other) in groups) {
                  if (a >= b) continue;
                  for (final p in one) {
                    for (final q in other) {
                      nearest = math.min(nearest, (p - q).distance);
                    }
                  }
                }
              }
              expect(nearest, greaterThanOrEqualTo(2.9),
                  reason: '$size, $seed');
            }
          }
        });

        test('each card its own, and the same each time', () {
          final a = GlassOrnament.of(card, 0.6, 'one'.hashCode, season);
          final b = GlassOrnament.of(card, 0.6, 'two'.hashCode, season);
          expect(bounds(a), isNot(bounds(b)));
          expect(GlassOrnament.of(card, 0.6, 'one'.hashCode, season), same(a));
        });
      });
    }

    test('winter: six arms alike from one centre, big ones on an edge', () {
      for (final seed in [1, 2, 3]) {
        final arms = <int, List<List<Offset>>>{};
        final small = <int>{};
        for (final s in GlassOrnament.strokes(card, seed, Season.winter)) {
          if (s.root) (arms[s.group] ??= []).add(s.line);
          if (s.small) small.add(s.group);
        }
        expect(arms.keys.where((c) => !small.contains(c)), isNotEmpty);
        for (final MapEntry(key: crystal, value: lines) in arms.entries) {
          final centre = lines.first.first;
          expect(lines.map((l) => l.first).toSet(), hasLength(1),
              reason: 'one centre');
          if (small.contains(crystal)) {
            expect((Offset.zero & card).contains(centre), isTrue);
          } else {
            expect(
                centre.dx.abs() < 0.01 ||
                    centre.dy.abs() < 0.01 ||
                    (centre.dx - card.width).abs() < 0.01 ||
                    (centre.dy - card.height).abs() < 0.01,
                isTrue,
                reason: '$centre');
          }
          // Arms sixty degrees apart.
          final first = (lines.first[1] - centre).direction;
          for (final line in lines) {
            final turn = ((line[1] - centre).direction - first) / (math.pi / 3);
            expect(turn - turn.round(), closeTo(0, 1e-6), reason: '$turn');
          }
        }
      }
    });

    test('winter: a fractal, branches of branches of branches', () {
      final levels = {
        for (final s
            in GlassOrnament.strokes(const Size(300, 900), 1, Season.winter))
          s.level
      };
      expect(levels, containsAll([0, 1, 2, 3]));
    });

    // Each drawing's points, by group.
    Map<int, List<Offset>> drawings(Size size, int seed, Season season) {
      final all = <int, List<Offset>>{};
      for (final s in GlassOrnament.strokes(size, seed, season)) {
        (all[s.group] ??= []).addAll(s.line);
      }
      return all;
    }

    test('autumn: leaves fallen, most of them low down', () {
      const panel = Size(360, 600);
      for (final seed in [1, 2, 3]) {
        final middles = [
          for (final points in drawings(panel, seed, Season.autumn).values)
            points.map((p) => p.dy).reduce((a, b) => a + b) / points.length,
        ];
        expect(middles.length, greaterThan(10));
        expect(middles.where((y) => y > panel.height / 2).length,
            greaterThan(middles.length / 2),
            reason: '$seed');
      }
    });

    test('spring: flowers stand on the bottom edge, their heads on the glass',
        () {
      for (final seed in [1, 2, 3]) {
        final meadow = [
          for (final s in GlassOrnament.strokes(card, seed, Season.spring))
            if (!s.small) s,
        ];
        final stems = {
          for (final s in meadow)
            if (s.line.first.dy > card.height) s.group
        };
        expect(stems.length, greaterThan(8), reason: '$seed');
        for (final s in meadow) {
          if (!stems.contains(s.group)) continue;
          for (final p in s.line) {
            expect(p.dy, greaterThan(0), reason: '$seed: $p');
          }
        }
      }
    });

    test('summer: riders on the ground, the whole of each on the glass', () {
      for (final size in [card, const Size(360, 400)]) {
        for (final seed in [1, 2, 3]) {
          final riders = drawings(size, seed, Season.summer);
          expect(riders, isNotEmpty);
          final grounds = <double>{};
          for (final points in riders.values) {
            final bounds = points.skip(1).fold(
                Rect.fromPoints(points.first, points.first),
                (r, p) => r.expandToInclude(Rect.fromPoints(p, p)));
            expect((Offset.zero & size).contains(bounds.topLeft), isTrue);
            expect(bounds.right, lessThanOrEqualTo(size.width));
            expect(bounds.bottom, lessThanOrEqualTo(size.height));
            grounds.add(bounds.bottom.roundToDouble());
          }
          // One lane along the bottom; a tall panel has more above it.
          expect(grounds.contains((size.height - 1).roundToDouble()), isTrue,
              reason: '$size, $seed: $grounds');
          if (size.height > 300) expect(grounds.length, greaterThan(1));
        }
      }
    });

    // Where the ornament runs under text, the text still reads.
    for (final (dark, scuffed, strength) in [
      for (final dark in [false, true]) ...[
        (dark, true, 1.0),
        (dark, false, 1.0),
        (dark, false, 0.0),
      ],
    ]) {
      final name = '${dark ? 'dark' : 'light'}, ${scuffed ? 'matte' : 'clear'}'
          '${strength < 1 ? ', ${(strength * 100).round()} %' : ''}';
      test('$name: text over the boldest ink', () {
        final theme = (dark ? buildDarkTheme : buildLightTheme)(
            browser: true,
            glass: true,
            scuffed: scuffed,
            strength: strength,
            ornament: 1);
        final glass = theme.extension<Glass>()!;
        for (final wall in wallpaperColors(glass)) {
          final under = composite(theme.colorScheme.surface, wall);
          for (final mark in [glass.ink, glass.inkEdge]) {
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

  test('the strength, the ornament and its season are kept apart', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = Prefs(await SharedPreferences.getInstance());
    final theme = ThemeController(prefs);
    expect(theme.strength, 1);
    expect(theme.ornament, 0.5);
    expect(theme.seasonChosen, isNull);
    expect(theme.season, Season.of(DateTime.now()));
    await theme.setOrnament(0.9);
    await theme.setStrength(0.3);
    await theme.setSeason(Season.summer);
    final again = ThemeController(prefs);
    expect(again.ornament, 0.9);
    expect(again.strength, 0.3);
    expect(again.season, Season.summer);
    await again.setSeason(null);
    expect(ThemeController(prefs).seasonChosen, isNull);
  });

  test('frost set before seasons came is kept', () async {
    SharedPreferences.setMockInitialValues({'flutter.theme_glass_frost': 0.8});
    final prefs = Prefs(await SharedPreferences.getInstance());
    expect(ThemeController(prefs).ornament, 0.8);
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
