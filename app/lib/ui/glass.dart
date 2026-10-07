import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'layout.dart';

/// «Liquid Glass», the browser's optional look: panels you see through to
/// soft colour blobs behind them, each with a bright rim, a sheen along the
/// top and a shadow that falls only outside it. What it needs beyond
/// ThemeData; [Glass.off] (the default) changes nothing.
@immutable
class Glass extends ThemeExtension<Glass> {
  const Glass({
    required this.on,
    this.base = Colors.transparent,
    this.blobs = const [],
    this.panel = Colors.transparent,
    this.bar = Colors.transparent,
    this.card = Colors.transparent,
    this.solid = Colors.transparent,
    this.lens = Colors.transparent,
    this.field = Colors.transparent,
    this.stroke = Colors.transparent,
    this.line = Colors.transparent,
    this.highlight = Colors.transparent,
    this.sheen = Colors.transparent,
    this.rim = const [Colors.transparent, Colors.transparent],
    this.shadows = const [],
    this.wash = const [],
    this.grain = 0,
    this.frost = 0,
    this.ice = Colors.transparent,
    this.iceEdge = Colors.transparent,
    this.strength = 1,
  });

  static const off = Glass(on: false);

  final bool on;

  /// The wallpaper: [base], an even [wash] across it, and over it soft
  /// round [blobs] of colour.
  final Color base;
  final List<Color> wash;
  final List<Color> blobs;

  /// Matte glass: how strongly the fine [grain] of frosting shows, on the
  /// wallpaper and the glass (0: none, 1: as drawn).
  final double grain;

  /// Matte glass: how far frost has grown on it, as on a window in winter
  /// (0: none, 1: in full; see [GlassFrost]): [ice], as on a stem, with its
  /// [iceEdge] beside it (see [paintFrost]).
  final double frost;
  final Color ice;
  final Color iceEdge;

  bool get scuffed => grain > 0 || frost > 0;

  /// How strong the effect is, as [scaled] made it: 1, the full design.
  final double strength;

  /// The blur behind a frosted panel.
  double get blur => 24 * strength;

  /// This glass at [t] of its strength (0 to 1): the panels, cards and bars
  /// thicken towards [solid], the wallpaper's colour fades towards [base],
  /// and the rim, sheen, shadows and texture soften — the shape stays. At 1
  /// it is this glass as designed, the one the contrast tests hold to the
  /// most see-through; anything less is thicker, so reads at least as well.
  Glass scaled(double t) {
    t = t.clamp(0.0, 1.0);
    if (!on || t == 1) return this;
    Color thicken(Color c) => mixOver(solid, c, t);
    Color fade(Color c, double least) =>
        c.withValues(alpha: c.a * (least + (1 - least) * t));
    return Glass(
      on: true,
      base: base,
      blobs: [for (final b in blobs) fade(b, 0)],
      wash: [for (final w in wash) Color.lerp(base, w, t)!],
      panel: thicken(panel),
      bar: thicken(bar),
      card: thicken(card),
      field: thicken(field),
      solid: solid,
      lens: lens,
      stroke: fade(stroke, 0.35),
      line: line,
      highlight: fade(highlight, 0.35),
      sheen: fade(sheen, 0.2),
      rim: [for (final r in rim) fade(r, 0.35)],
      shadows: [
        for (final s in shadows) s.copyWith(color: fade(s.color, 0.5)),
      ],
      grain: grain * t,
      frost: frost * t,
      ice: ice,
      iceEdge: iceEdge,
      strength: strength * t,
    );
  }

  /// The menu and the drawer.
  final Color panel;

  /// The top bar.
  final Color bar;

  /// Cards and tiles.
  final Color card;

  /// What comes over the page — dialogs, menus, sheets, snackbars: glass
  /// thick enough to read on whatever is under it.
  final Color solid;

  /// The selected item, a drop of clearer glass.
  final Color lens;

  /// Text fields.
  final Color field;

  /// A glass panel's edge, and a hairline between parts.
  final Color stroke;
  final Color line;

  /// The light along a panel's top edge, and the sheen fading down from it.
  final Color highlight;
  final Color sheen;

  /// The rim: bright at the top left, [rim].last at the bottom right.
  final List<Color> rim;

  final List<BoxShadow> shadows;

  static Glass of(BuildContext context) =>
      Theme.of(context).extension<Glass>() ?? off;

  // After the jury-score app's glass (CSS blur radii halved into sigmas),
  // in a business palette: steel, slate and the brand's muted blue.
  static const light = Glass(
    on: true,
    base: Color(0xFFEDF0F5),
    blobs: [
      Color(0xD9A7B9D6),
      Color(0xD98FA6C8),
      Color(0xD9BAC5D4),
      Color(0xD9AFB3D1),
      Color(0x99D3DAE4),
    ],
    panel: Color(0x80FFFFFF),
    bar: Color(0xB8F6F8FF),
    card: Color(0x8FFFFFFF),
    solid: Color(0xFFF7F8FD),
    lens: Color(0xF0FFFFFF),
    field: Color(0xBFFFFFFF),
    stroke: Color(0xB8FFFFFF),
    line: Color(0x170F1426),
    highlight: Color(0xF2FFFFFF),
    sheen: Color(0x80FFFFFF),
    rim: [Color(0xFFFFFFFF), Color(0x8CFFFFFF)],
    shadows: [
      BoxShadow(
          color: Color(0x6124306E),
          offset: Offset(0, 14),
          blurRadius: 28.6,
          spreadRadius: -16),
      BoxShadow(
          color: Color(0x1424306E),
          offset: Offset(0, 2),
          blurRadius: 6,
          spreadRadius: -2),
    ],
  );

  static const dark = Glass(
    on: true,
    base: Color(0xFF0A0D14),
    blobs: [
      Color(0x99203352),
      Color(0x99254272),
      Color(0x99273140),
      Color(0x99252A4F),
      Color(0x6B141B27),
    ],
    panel: Color(0x75181C32),
    bar: Color(0xC7101326),
    card: Color(0x0FFFFFFF),
    solid: Color(0xFF14182A),
    lens: Color(0x26FFFFFF),
    field: Color(0x3D000000),
    stroke: Color(0x21FFFFFF),
    line: Color(0x1AFFFFFF),
    highlight: Color(0x33FFFFFF),
    sheen: Color(0x12FFFFFF),
    rim: [Color(0x80FFFFFF), Color(0x1FFFFFFF)],
    shadows: [
      BoxShadow(
          color: Color(0xCC000000),
          offset: Offset(0, 18),
          blurRadius: 32,
          spreadRadius: -18),
    ],
  );

  /// Matte glass, frosted and lightly scuffed, on an even wash of steel
  /// grey — no blobs to read as smudges behind it.
  static const scuffedLight = Glass(
    on: true,
    base: Color(0xFFE6EAF0),
    wash: [Color(0xFFDDE3EB), Color(0xFFECEFF4), Color(0xFFD6DDE7)],
    panel: Color(0xA6FFFFFF),
    bar: Color(0xD1F5F7FA),
    card: Color(0xB8FFFFFF),
    solid: Color(0xFFF5F7FA),
    lens: Color(0xF5FFFFFF),
    field: Color(0xCCFFFFFF),
    stroke: Color(0xCCFFFFFF),
    line: Color(0x1A0F1426),
    highlight: Color(0xF2FFFFFF),
    sheen: Color(0x59FFFFFF),
    rim: [Color(0xFFFFFFFF), Color(0x66FFFFFF)],
    shadows: [
      BoxShadow(
          color: Color(0x4720283F),
          offset: Offset(0, 10),
          blurRadius: 20,
          spreadRadius: -12),
      BoxShadow(color: Color(0x0F20283F), offset: Offset(0, 1), blurRadius: 3),
    ],
    grain: 1,
    ice: Color(0x66334E70),
    iceEdge: Color(0xE6FFFFFF),
  );

  static const scuffedDark = Glass(
    on: true,
    base: Color(0xFF0D1117),
    wash: [Color(0xFF161C26), Color(0xFF0D1117), Color(0xFF141B25)],
    panel: Color(0x991B212C),
    bar: Color(0xE0121720),
    card: Color(0x1AFFFFFF),
    solid: Color(0xFF171C26),
    lens: Color(0x2EFFFFFF),
    field: Color(0x47000000),
    stroke: Color(0x24FFFFFF),
    line: Color(0x1FFFFFFF),
    highlight: Color(0x2EFFFFFF),
    sheen: Color(0x0FFFFFFF),
    rim: [Color(0x66FFFFFF), Color(0x14FFFFFF)],
    shadows: [
      BoxShadow(
          color: Color(0xB3000000),
          offset: Offset(0, 14),
          blurRadius: 26,
          spreadRadius: -16),
    ],
    grain: 1,
    ice: Color(0x47FFFFFF),
    iceEdge: Color(0x66000000),
  );

  /// Text on glass, and the quieter text under it.
  static const lightText = Color(0xFF0F1426);
  static const darkText = Color(0xFFFFFFFF);
  static const lightMuted = Color(0xA80F1426);
  static const darkMuted = Color(0xC7FFFFFF);

  /// Brand blue on dark glass: paler, to stand out over the deep blobs.
  static const darkAccent = Color(0xFFC6D9F8);

  /// [c] as glass shows an accent: no more saturated than a business
  /// palette allows (the week's red and blue, coral).
  static Color tone(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withSaturation(math.min(hsl.saturation, 0.5))
        .toColor()
        .withValues(alpha: c.a);
  }

  /// [frost]: matte glass with frost grown that far.
  @override
  Glass copyWith({bool? on, double? frost}) => Glass(
        on: on ?? this.on,
        base: base,
        blobs: blobs,
        panel: panel,
        bar: bar,
        card: card,
        solid: solid,
        lens: lens,
        field: field,
        stroke: stroke,
        line: line,
        highlight: highlight,
        sheen: sheen,
        rim: rim,
        shadows: shadows,
        wash: wash,
        grain: grain,
        frost: (frost ?? this.frost).clamp(0.0, 1.0),
        ice: ice,
        iceEdge: iceEdge,
        strength: strength,
      );

  @override
  Glass lerp(Glass? other, double t) => t < 0.5 || other == null ? this : other;
}

/// [a] turning into [b] by [t], the way one looks over anything below:
/// colour weighted by how opaque it is (premultiplied), unlike Color.lerp,
/// which takes an opaque dark and a see-through white halfway to a
/// see-through grey lighter than either.
Color mixOver(Color a, Color b, double t) {
  final alpha = a.a + (b.a - a.a) * t;
  if (alpha <= 0) return const Color(0x00000000);
  double channel(double ca, double cb) =>
      ((ca * a.a) + (cb * b.a - ca * a.a) * t) / alpha;
  return Color.from(
      alpha: alpha,
      red: channel(a.r, b.r),
      green: channel(a.g, b.g),
      blue: channel(a.b, b.b));
}

/// What a glass surface of [fill] looks like over [below]: what text on it
/// has to stand out from.
Color composite(Color fill, Color below) => Color.alphaBlend(fill, below);

/// WCAG contrast ratio of two opaque colours, 1 to 21.
double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// Every colour the wallpaper of [glass] shows somewhere: the base, each
/// blob at its middle, and where two of them overlap.
List<Color> wallpaperColors(Glass glass) => [
      glass.base,
      ...glass.wash,
      for (final b in glass.blobs) composite(b, glass.base),
      for (final a in glass.blobs)
        for (final b in glass.blobs)
          if (a != b) composite(b, composite(a, glass.base)),
    ];

/// Where the blobs of a [window] sit, as the jury-score page has them: a
/// circle of 40% of the window's longer side each, around the edges.
List<(Offset, double)> blobSpots(Size window) {
  final w = window.width, h = window.height;
  final m = math.max(w, h) / 100;
  return [
    (Offset(2 * m, 6 * m), 40 * m),
    (Offset(w, 32 * m), 40 * m),
    (Offset(10 * m, 0.38 * h + 40 * m), 40 * m),
    (Offset(w - 6 * m, h - 4 * m), 40 * m),
    (Offset(0.1 * w + 40 * m, h + 10 * m), 40 * m),
  ];
}

/// Under each page (see theme.dart) and in the browser's side strips: the
/// glass wallpaper, lined up with the window so it runs on unbroken across
/// the menu, the panes and a page sliding in. Without glass it paints
/// [solid] (or nothing) — the same widget either way, so turning glass on
/// or off keeps every page as it was.
class Wallpaper extends SingleChildRenderObjectWidget {
  const Wallpaper({super.key, this.solid, super.child});

  /// What to paint without glass; nothing when null.
  final Color? solid;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderWallpaper()..update(Glass.of(context), solid, _window(context));

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) =>
      (renderObject as _RenderWallpaper)
          .update(Glass.of(context), solid, _window(context));

  /// The whole window, whatever a pane's MediaQuery says.
  static Size _window(BuildContext context) {
    final view = View.of(context);
    return view.physicalSize / view.devicePixelRatio;
  }
}

class _RenderWallpaper extends RenderProxyBox {
  Glass _glass = Glass.off;
  Color? _solid;
  Size _window = Size.zero;

  void update(Glass glass, Color? solid, Size window) {
    if (glass == _glass && solid == _solid && window == _window) return;
    _glass = glass;
    _solid = solid;
    _window = window;
    markNeedsPaint();
  }

  // Placed by where the box is in the window, so a page's own transform (a
  // slide in) moves its content over a wallpaper that stays put.
  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    final box = offset & size;
    if (_glass.on) {
      final origin = offset - localToGlobal(Offset.zero);
      canvas.drawRect(box, Paint()..color = _glass.base);
      if (_glass.wash.length > 1) {
        canvas.drawRect(
            box,
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _glass.wash,
              ).createShader(origin & _window));
      }
      final spots = blobSpots(_window);
      for (var i = 0; i < _glass.blobs.length && i < spots.length; i++) {
        final (centre, radius) = spots[i];
        final c = _glass.blobs[i];
        canvas.drawRect(
            box,
            Paint()
              ..shader = RadialGradient(colors: [c, c.withAlpha(0)])
                  .createShader(Rect.fromCircle(
                      center: origin + centre, radius: radius)));
      }
      // Frosting held still against the window, as the wash is.
      paintTexture(canvas, box, GlassTexture.grain, origin, _glass.grain);
    } else if (_solid case final c?) {
      canvas.drawRect(box, Paint()..color = c);
    }
    super.paint(context, offset);
  }
}

/// Wraps each page in a [Wallpaper], in every theme (see [Wallpaper]).
class OnWallpaper extends PageTransitionsBuilder {
  const OnWallpaper(this.inner);
  final PageTransitionsBuilder inner;

  @override
  Widget buildTransitions<T>(
          PageRoute<T> route,
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child) =>
      inner.buildTransitions(route, context, animation, secondaryAnimation,
          Wallpaper(child: child));
}

/// Page transitions as Flutter's own, each page on its [Wallpaper].
PageTransitionsTheme wallpaperTransitions() {
  const plain = PageTransitionsTheme();
  return PageTransitionsTheme(builders: {
    for (final p in TargetPlatform.values)
      p: OnWallpaper(plain.builders[p] ?? const ZoomPageTransitionsBuilder()),
  });
}

/// A piece of glass: [fill] (a card's, by default) or a [gradient], the
/// sheen fading down from the top, the light along the top edge, the rim,
/// and [shadows] (the glass's own by default) that fall only outside it, as
/// a CSS box-shadow does — under see-through glass a whole shadow would show
/// through as a grey haze. An [accent] stripe down the left side, or an
/// [outline] all round, marks it as a plain card's border did. On matte
/// glass, [seed] picks this piece's own frost (by default, its size's).
@immutable
class GlassDecoration extends Decoration {
  const GlassDecoration(
    this.glass, {
    this.fill,
    this.gradient,
    this.radius = 18,
    this.accent,
    this.accentWidth = 0,
    this.outline,
    this.shadows,
    this.sheen = true,
    this.rimmed = true,
    this.highlight,
    this.inset = EdgeInsets.zero,
    this.seed,
  });

  final Glass glass;
  final Color? fill;
  final Gradient? gradient;
  final double radius;
  final Color? accent;
  final double accentWidth;
  final BorderSide? outline;
  final List<BoxShadow>? shadows;
  final bool sheen;

  /// With the glass's edge and rim; and the light along the top, if not
  /// the glass's own.
  final bool rimmed;
  final Color? highlight;

  /// What the child keeps clear of, as a border would make it.
  final EdgeInsets inset;

  final int? seed;

  @override
  EdgeInsetsGeometry get padding => inset;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) => _GlassPainter(this);

  @override
  bool operator ==(Object other) =>
      other is GlassDecoration &&
      other.glass == glass &&
      other.fill == fill &&
      other.gradient == gradient &&
      other.radius == radius &&
      other.accent == accent &&
      other.accentWidth == accentWidth &&
      other.outline == outline &&
      other.shadows == shadows &&
      other.sheen == sheen &&
      other.rimmed == rimmed &&
      other.highlight == highlight &&
      other.inset == inset &&
      other.seed == seed;

  @override
  int get hashCode => Object.hash(glass, fill, gradient, radius, accent,
      accentWidth, outline, shadows, sheen, rimmed, highlight, inset, seed);
}

class _GlassPainter extends BoxPainter {
  _GlassPainter(this.d);
  final GlassDecoration d;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final g = d.glass;
    final rect = offset & configuration.size!;
    final shape = RRect.fromRectAndRadius(rect, Radius.circular(d.radius));
    final outside = Path.combine(PathOperation.difference,
        Path()..addRect(rect.inflate(120)), Path()..addRRect(shape));

    final shadows = d.shadows ?? g.shadows;
    if (shadows.isNotEmpty) {
      canvas
        ..save()
        ..clipPath(outside);
      for (final s in shadows) {
        canvas.drawRRect(
            shape.shift(s.offset).inflate(s.spreadRadius), s.toPaint());
      }
      canvas.restore();
    }

    canvas.drawRRect(
        shape,
        d.gradient == null
            ? (Paint()..color = d.fill ?? g.card)
            : (Paint()..shader = d.gradient!.createShader(rect)));
    if (d.sheen) {
      canvas.drawRRect(
          shape,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [g.sheen, g.sheen.withAlpha(0)],
              stops: const [0, 0.46],
            ).createShader(rect));
    }
    // Matte glass: frosted, with frost grown on it, moving with it.
    if (g.scuffed && d.sheen) {
      canvas
        ..save()
        ..clipRRect(shape);
      paintTexture(canvas, rect, GlassTexture.grain, rect.topLeft, g.grain);
      paintFrost(canvas, rect, g,
          d.seed ?? Object.hash(rect.width.round(), rect.height.round()));
      canvas.restore();
    }
    // The accent: a capsule standing just inside the left edge.
    if (d.accent case final accent? when d.accentWidth > 0) {
      final inset = math.min(12.0, rect.height / 4);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTRB(rect.left + 8, rect.top + inset,
                  rect.left + 8 + d.accentWidth, rect.bottom - inset),
              Radius.circular(d.accentWidth / 2)),
          Paint()..color = accent);
    }
    // The light along the top: CSS's `inset 0 1px 0`.
    canvas.drawPath(
        Path.combine(PathOperation.difference, Path()..addRRect(shape),
            Path()..addRRect(shape.shift(const Offset(0, 1)))),
        Paint()..color = d.highlight ?? g.highlight);
    final edge = shape.deflate(0.5);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    if (d.rimmed) {
      canvas
        ..drawRRect(edge, stroke..color = g.stroke)
        ..drawRRect(
            edge,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..shader = LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  g.rim.first,
                  g.rim.first.withAlpha(0),
                  g.rim.last.withAlpha(0),
                  g.rim.last,
                ],
                stops: const [0, 0.32, 0.66, 1],
              ).createShader(rect));
    }
    if (d.outline case final o? when o.width > 0 && o.color.a > 0) {
      canvas.drawRRect(
          shape.deflate(o.width / 2),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = o.width
            ..color = o.color);
    }
  }
}

/// The tile of matte glass's texture, drawn once: [grain], fine specks of
/// light and shade as frosting has (laid at half a logical pixel each: a
/// device pixel on most screens). Null where the renderer can't draw it.
abstract final class GlassTexture {
  static final ui.Image? grain = _draw(256, (canvas, rnd) {
    final light = <Offset>[], shade = <Offset>[];
    for (var i = 0; i < 12000; i++) {
      (rnd.nextBool() ? light : shade)
          .add(Offset(rnd.nextDouble() * 256, rnd.nextDouble() * 256));
    }
    canvas
      ..drawPoints(
          ui.PointMode.points,
          light,
          Paint()
            ..color = const Color(0x12FFFFFF)
            ..strokeWidth = 1)
      ..drawPoints(
          ui.PointMode.points,
          shade,
          Paint()
            ..color = const Color(0x0B000000)
            ..strokeWidth = 1);
  });

  /// Grain texture pixels per logical pixel.
  static const grainScale = 0.5;

  static ui.Image? _draw(int size, void Function(Canvas, math.Random) draw) {
    try {
      final recorder = ui.PictureRecorder();
      draw(Canvas(recorder), math.Random(7));
      return recorder.endRecording().toImageSync(size, size);
    } on Object {
      return null;
    }
  }
}

/// [texture] tiled over [rect] from [origin], at [strength] (0: not at all).
void paintTexture(Canvas canvas, Rect rect, ui.Image? texture, Offset origin,
    double strength) {
  if (texture == null || strength <= 0) return;
  final scale =
      identical(texture, GlassTexture.grain) ? GlassTexture.grainScale : 1.0;
  canvas.drawRect(
      rect,
      Paint()
        ..shader = ImageShader(
            texture,
            TileMode.repeated,
            TileMode.repeated,
            (Matrix4.translationValues(origin.dx, origin.dy, 0)
                  ..scaleByDouble(scale, scale, 1, 1))
                .storage)
        ..colorFilter = ColorFilter.mode(
            Color.fromRGBO(255, 255, 255, strength.clamp(0.0, 1.0)),
            BlendMode.modulate));
}

/// Ice of one thickness: [path], to draw at [depth] (0 to 1) of the ice's
/// colour over its edge, which shows [lift] beside it (see [paintFrost]).
typedef FrostMark = ({Path path, double depth, double lift});

/// Frost on a piece of matte glass, as on a window in winter, grown as
/// fractal crystals: [GlassFrost.of] its size and how far it has grown (0
/// to 1), as marks to draw in order. Each crystal is a snowflake of six
/// arms alike; off each arm, pairs of branches at sixty degrees, as ice
/// branches, shorter towards its tip; each branch the same again, smaller,
/// three times over. Big ones grow first from the edges — most from the
/// bottom, seldom from the top — then smaller ones fill the room left.
/// Where ice reaches ice another crystal got to first, it stops: they meet
/// but don't cross. A piece's seed keeps its frost as it grows: it only
/// grows on.
@immutable
class GlassFrost {
  const GlassFrost._(this.marks);

  final List<FrostMark> marks;

  /// Ice by thickness, fine to thick — twigs, branches, arms: one path
  /// each, to draw at once.
  static const _depths = 3;

  static final _made = <(int, int, int, int), GlassFrost>{};

  static GlassFrost of(Size size, double frost, int seed) {
    final key = (
      seed,
      size.width.round(),
      size.height.round(),
      (frost.clamp(0.0, 1.0) * 100).round(),
    );
    if (_made[key] case final made?) return made;
    if (_made.length >= 128) _made.clear();
    return _made[key] = _make(
        _Ice.of(Size(key.$2.toDouble(), key.$3.toDouble()), seed),
        key.$4 / 100);
  }

  /// The frost on a piece [size] across, grown in full: each branch as far
  /// as it got — of which crystal, whether one of the small ones between,
  /// whether an arm, and how many branchings from one.
  @visibleForTesting
  static List<
          ({int frond, bool flake, bool root, int level, List<Offset> line})>
      fronds(Size size, int seed) {
    final ice = _Ice.of(size, seed);
    return [
      for (final b in ice.branches)
        if (b.alive > 0)
          (
            frond: b.frond,
            flake: ice._flake[b.frond],
            root: b.parent < 0,
            level: b.level,
            line: b.points.sublist(0, b.alive + 1),
          ),
    ];
  }

  static GlassFrost _make(_Ice ice, double frost) {
    if (frost <= 0) return const GlassFrost._([]);
    final paths = [for (var i = 0; i < _depths; i++) Path()];
    for (final b in ice.branches) {
      final reach =
          math.min(ice.reach(b.frond, frost) - b.from, b.alive * _Ice.step);
      if (reach <= 0) continue;
      final wide = const [1.6, 1.1, 0.75, 0.55][b.level] * (0.6 + 0.4 * frost);
      paths[_depths - 1 - math.min(b.level, _depths - 1)]
          .addPolygon(b.outline(reach, wide), true);
    }
    return GlassFrost._([
      for (var k = 0; k < _depths; k++)
        (path: paths[k], depth: _strength(k), lift: 0.35 + 0.2 * k),
    ]);
  }

  /// How strongly ice of thickness [k] shows: arms most.
  static double _strength(int k) => 0.55 + 0.45 * (k + 1) / _depths;
}

/// Frost on a piece of glass grown in full, the same at any stage: its
/// branches, where each runs, and how far each got before it met another
/// frond's ice. [reach] says how far along a frond it has got at a stage.
class _Ice {
  final branches = <_Branch>[];

  /// For each crystal: the stage it starts at, how many stages it takes to
  /// grow in full, its farthest point along it, and whether it is one of
  /// the small ones between.
  final _appear = <double>[], _span = <double>[], _longest = <double>[];
  final _flake = <bool>[];

  /// For each crystal: how long its arms are.
  final _radius = <double>[];

  /// Pixels between a branch's points.
  static const step = 2.0;

  /// Ice keeps this far (a cell, in pixels) from another frond's.
  static const _cell = 3.0;

  /// How far past the edges ice is kept track of: a crystal centred on one
  /// spreads out past it too.
  static const _margin = 24.0;

  double reach(int frond, double stage) =>
      (stage - _appear[frond]) / _span[frond] * _longest[frond];

  double _time(int frond, double along) =>
      _appear[frond] + along / _longest[frond] * _span[frond];

  static final _grown = <(int, int, int), _Ice>{};

  static _Ice of(Size size, int seed) {
    final key = (seed, size.width.round(), size.height.round());
    if (_grown[key] case final ice?) return ice;
    if (_grown.length >= 64) _grown.clear();
    return _grown[key] = _grow(size, seed);
  }

  static _Ice _grow(Size size, int seed) {
    final w = size.width, h = size.height;
    final ice = _Ice();
    if (w <= 0 || h <= 0) return ice;
    final rnd = math.Random(seed);
    final small = math.min(w, h);

    // Big crystals centred on the edges, the frost creeping in.
    final count = ((w + h) * 2 / 110).clamp(2, 24).round();
    final gap = (w + h) * 2 / count * 0.6;
    final centres = <Offset>[];
    for (var i = 0; i < count; i++) {
      // Somewhere along an edge — the bottom likeliest, the top seldom —
      // and not too near another.
      Offset? centre;
      var inwards = 0.0;
      for (var tries = 0; tries < 6 && centre == null; tries++) {
        final pick = rnd.nextDouble() * (1.9 * w + 2 * h);
        final along = rnd.nextDouble();
        final (p, n) = pick < 1.6 * w
            ? (Offset(along * w, h), -math.pi / 2)
            : pick < 1.9 * w
                ? (Offset(along * w, 0), math.pi / 2)
                : pick < 1.9 * w + h
                    ? (Offset(0, along * h), 0.0)
                    : (Offset(w, along * h), math.pi);
        if (centres.every((c) => (c - p).distance >= gap)) {
          centre = p;
          inwards = n;
        }
      }
      final radius = math.min(110.0, (0.45 + 0.35 * rnd.nextDouble()) * small);
      final turn = rnd.nextDouble() * math.pi / 3;
      final arm = _arm(rnd, radius);
      if (centre == null) continue;
      centres.add(centre);
      ice._crystal(centre, turn, arm, i / count * 0.45, 0.4,
          inwards: inwards, small: false);
    }

    // Then smaller ones in the room left.
    final flakes = (w * h / 3500).clamp(1, 40).round();
    for (var i = 0; i < flakes; i++) {
      final centre = Offset(rnd.nextDouble() * w, rnd.nextDouble() * h);
      final radius =
          math.min(50.0, (0.12 + 0.18 * rnd.nextDouble()) * small + 4);
      final turn = rnd.nextDouble() * math.pi / 3;
      ice._crystal(
          centre, turn, _arm(rnd, radius), 0.4 + 0.45 * i / flakes, 0.15,
          small: true);
    }

    // Grow it all in the order it would grow. Where a step comes within a
    // cell of another frond's ice, that branch stops; a branch that would
    // spring from beyond where its parent stopped never grows.
    final branches = ice.branches;
    final steps = <(double, int, int)>[
      for (var b = 0; b < branches.length; b++)
        for (var j = 0; j < branches[b].points.length - 1; j++)
          (
            ice._time(branches[b].frond, branches[b].from + (j + 1) * step),
            b,
            j
          ),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    final cols = ((w + 2 * _margin) / _cell).ceil() + 1,
        rows = ((h + 2 * _margin) / _cell).ceil() + 1;
    final owner = List<int>.filled(cols * rows, -1);
    (int, int) cell(Offset p) => (
          ((p.dx + _margin) / _cell).floor(),
          ((p.dy + _margin) / _cell).floor()
        );
    bool free(Offset p, int frond) {
      final (cx, cy) = cell(p);
      for (var y = math.max(0, cy - 1); y <= math.min(rows - 1, cy + 1); y++) {
        for (var x = math.max(0, cx - 1);
            x <= math.min(cols - 1, cx + 1);
            x++) {
          final o = owner[y * cols + x];
          if (o >= 0 && o != frond) return false;
        }
      }
      return true;
    }

    void take(Offset p, int frond) {
      final (cx, cy) = cell(p);
      if (cx >= 0 && cy >= 0 && cx < cols && cy < rows) {
        owner[cy * cols + cx] = frond;
      }
    }

    // A small crystal grows only where there is room for it whole — not a
    // stray arm or two squeezed in between.
    bool roomy(int crystal) {
      final centre = branches.firstWhere((b) => b.frond == crystal).points[0];
      final r = ice._radius[crystal] * 0.8;
      for (var y = centre.dy - r; y <= centre.dy + r; y += _cell) {
        for (var x = centre.dx - r; x <= centre.dx + r; x += _cell) {
          final p = Offset(x, y);
          if ((p - centre).distance <= r && !free(p, crystal)) return false;
        }
      }
      return true;
    }

    final room = <int, bool>{};
    final stopped = List.filled(branches.length, false);
    for (final (_, b, j) in steps) {
      if (stopped[b]) continue;
      final branch = branches[b];
      if (ice._flake[branch.frond] &&
          !room.putIfAbsent(branch.frond, () => roomy(branch.frond))) {
        stopped[b] = true;
        continue;
      }
      final a = branch.points[j], z = branch.points[j + 1];
      final mid = Offset.lerp(a, z, 0.5)!;
      final sprung = j > 0 ||
          (branch.parent < 0
              ? free(a, branch.frond)
              : branches[branch.parent].alive * step >= branch.at);
      if (!sprung || !free(mid, branch.frond) || !free(z, branch.frond)) {
        stopped[b] = true;
        continue;
      }
      if (j == 0) take(a, branch.frond);
      take(mid, branch.frond);
      take(z, branch.frond);
      branch.alive = j + 1;
    }
    return ice;
  }

  /// A crystal of six [arm]s alike about [centre], the first at [turn],
  /// starting at stage [appear] and grown in full [span] stages later. One
  /// on an edge leaves out the arms that would point off the glass, away
  /// from [inwards].
  void _crystal(
      Offset centre, double turn, List<_Shoot> arm, double appear, double span,
      {double? inwards, required bool small}) {
    final crystal = _appear.length, first = branches.length;
    for (var a = 0; a < 6; a++) {
      final angle = turn + a * math.pi / 3;
      if (inwards != null && math.cos(angle - inwards) < -0.5) continue;
      final (sin, cos) = (math.sin(angle), math.cos(angle));
      Offset turned(Offset p) =>
          Offset(p.dx * cos - p.dy * sin, p.dx * sin + p.dy * cos);
      final base = branches.length;
      for (final shoot in arm) {
        final heading = shoot.heading + angle;
        final from = centre + turned(shoot.from);
        final along = Offset(math.cos(heading), math.sin(heading)) * step;
        final steps = (shoot.length / step).floor();
        branches.add(_Branch(
            crystal,
            shoot.level,
            shoot.parent < 0 ? -1 : base + shoot.parent,
            shoot.at,
            shoot.along,
            [for (var j = 0; j <= steps; j++) from + along * j.toDouble()],
            List.filled(steps + 1, heading)));
      }
    }
    if (branches.length == first) return;
    _appear.add(appear);
    _span.add(span);
    _flake.add(small);
    _radius.add(arm.first.length);
    _longest.add(
        branches.skip(first).map((b) => b.from + b.length).reduce(math.max));
  }

  /// One arm of a crystal, [length] long, laid out from the origin along
  /// heading 0: off it, four pairs of branches at sixty degrees either side,
  /// each pair shorter than the last, and each branch the same again,
  /// smaller, down to level 3 or a few pixels. Short enough, for four to a
  /// side, that no branch reaches the next one along.
  static List<_Shoot> _arm(math.Random rnd, double length) {
    final shoots = <_Shoot>[];
    void grow(Offset from, double heading, double length, int level, int parent,
        double at, double along) {
      if (length < 4) return;
      final index = shoots.length;
      shoots.add((
        from: from,
        heading: heading,
        length: length,
        level: level,
        parent: parent,
        at: at,
        along: along,
      ));
      if (level == 3 || length < 8) return;
      final towards = Offset(math.cos(heading), math.sin(heading));
      for (final f in const [0.25, 0.45, 0.65, 0.82]) {
        final x = f + (rnd.nextDouble() - 0.5) * 0.04;
        final at = (x * length / step).round() * step;
        final child = length * 0.5 * (1 - x) * (0.85 + 0.3 * rnd.nextDouble());
        for (final side in const [-1.0, 1.0]) {
          grow(from + towards * at, heading + side * math.pi / 3, child,
              level + 1, index, at, along + at);
        }
      }
    }

    grow(Offset.zero, 0, length, 0, -1, 0, 0);
    return shoots;
  }
}

/// One branch of a crystal's arm, laid out from the origin along heading 0
/// (see [_Ice._arm]).
typedef _Shoot = ({
  Offset from,
  double heading,
  double length,
  int level,
  int parent,
  double at,
  double along,
});

/// A branch of frost, [level] branchings from an arm, of crystal [frond];
/// springing [at] that far along branch [parent], [from] that far from the
/// crystal's centre along it; [points] a step apart, of which [alive] steps
/// grew before it met other ice.
class _Branch {
  _Branch(this.frond, this.level, this.parent, this.at, this.from, this.points,
      this.headings);

  final int frond, level, parent;
  final double at, from;
  final List<Offset> points;
  final List<double> headings;
  int alive = 0;

  double get length => (points.length - 1) * _Ice.step;

  /// Its ice as far as [reach], [wide] at its root and narrowing towards
  /// its tip, which comes to a point.
  List<Offset> outline(double reach, double wide) {
    final last = (reach / _Ice.step).ceil().clamp(1, points.length - 1);
    final left = <Offset>[], right = <Offset>[];
    for (var j = 0; j <= last; j++) {
      final s = math.min(j * _Ice.step, reach);
      final tip = ((reach - s) / 3).clamp(0.2, 1.0);
      final half = wide / 2 * (1 - 0.65 * s / length) * tip;
      final h = headings[j];
      final across = Offset(-math.sin(h), math.cos(h)) * half;
      final at = j * _Ice.step > reach
          ? Offset.lerp(points[j - 1], points[j],
              1 - (j * _Ice.step - reach) / _Ice.step)!
          : points[j];
      left.add(at + across);
      right.add(at - across);
    }
    return [...left, ...right.reversed];
  }
}

/// The frost on [glass] at [rect], picked by [seed] (see [GlassFrost]):
/// the ice in [Glass.ice], standing proud — its edge, [Glass.iceEdge], shows
/// beside it as light on the side towards the light at the top left, or,
/// if darker, as shade on the other.
void paintFrost(Canvas canvas, Rect rect, Glass glass, int seed) {
  if (glass.frost <= 0) return;
  final frost = GlassFrost.of(rect.size, glass.frost, seed);
  if (frost.marks.isEmpty) return;
  final towards =
      glass.iceEdge.computeLuminance() > glass.ice.computeLuminance()
          ? -1.0
          : 1.0;
  Paint paint(Color c, double depth) =>
      Paint()..color = c.withValues(alpha: c.a * depth);
  canvas
    ..save()
    ..translate(rect.left, rect.top);
  for (final m in frost.marks) {
    canvas.drawPath(m.path.shift(Offset(towards, towards) * m.lift),
        paint(glass.iceEdge, m.depth));
  }
  for (final m in frost.marks) {
    canvas.drawPath(m.path, paint(glass.ice, m.depth));
  }
  canvas.restore();
}

/// A card's decoration: [plain] without glass; on glass, glass that keeps
/// its accent — the stripe down the left as a capsule inside the edge, or
/// the outline all round — and room for it. [seed]: what the card shows,
/// so that on matte glass each has frost of its own.
Decoration cardDecoration(BuildContext context, BoxDecoration plain,
    {Object? seed}) {
  final glass = Glass.of(context);
  if (!glass.on) return plain;
  final border = plain.border;
  final inset =
      border?.dimensions.resolve(TextDirection.ltr) ?? EdgeInsets.zero;
  if (border is Border && !border.isUniform && border.left.width > 0) {
    return GlassDecoration(glass,
        accent: Glass.tone(border.left.color),
        accentWidth: 4,
        inset: inset.copyWith(left: 18),
        seed: seed?.hashCode);
  }
  return GlassDecoration(glass,
      outline: border is Border ? border.top : null,
      inset: inset,
      seed: seed?.hashCode);
}

/// Glass's own saturation boost behind a blur: CSS's `saturate(180%)`.
ui.ColorFilter _saturate(double s) {
  const r = 0.2126, g = 0.7152, b = 0.0722;
  final i = 1 - s;
  return ui.ColorFilter.matrix([
    r * i + s, g * i, b * i, 0, 0, //
    r * i, g * i + s, b * i, 0, 0, //
    r * i, g * i, b * i + s, 0, 0, //
    0, 0, 0, 1, 0,
  ]);
}

/// The menu's glass ([Glass.panel]). [frosted] blurs what is under it —
/// only for one that comes over the page, the drawer: over the wallpaper
/// alone a blur would cost the browser and show nothing.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.radius = 0,
    this.frosted = false,
    this.shadow = false,
  });

  final Widget child;
  final double radius;
  final bool frosted;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final glass = Glass.of(context);
    Widget panel = DecoratedBox(
      decoration: GlassDecoration(glass,
          fill: glass.panel, radius: radius, shadows: shadow ? null : const []),
      child: Material(type: MaterialType.transparency, child: child),
    );
    if (frosted) {
      panel = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ui.ImageFilter.compose(
              outer: _saturate(1.8),
              inner:
                  ui.ImageFilter.blur(sigmaX: glass.blur, sigmaY: glass.blur)),
          child: panel,
        ),
      );
    }
    return panel;
  }
}

/// The coloured bar under the top bar — the day, the month, the study
/// year — with [child] at a readable width: across the screen; on glass, a
/// floating pill of [color] the wallpaper shows through a little.
class AccentBar extends StatelessWidget {
  const AccentBar({super.key, required this.color, required this.child});

  final Color color;
  final Widget child;

  /// The pill, top to bottom: [color] made deep enough for white text
  /// (4.5:1 even with the wallpaper showing through), a shade lighter above
  /// and darker below — one hue, no more.
  static List<Color> pill(Color color) {
    var hsl = HSLColor.fromColor(Glass.tone(color));
    while (contrast(
                Colors.white,
                hsl
                    .withLightness(math.min(1, hsl.lightness + 0.03))
                    .toColor()) <
            5.2 &&
        hsl.lightness > 0) {
      hsl = hsl.withLightness(math.max(0, hsl.lightness - 0.01));
    }
    Color at(double dl) => hsl
        .withLightness((hsl.lightness + dl).clamp(0.0, 1.0))
        .toColor()
        .withValues(alpha: 0.94);
    return [at(0.03), at(-0.05)];
  }

  @override
  Widget build(BuildContext context) {
    final glass = Glass.of(context);
    if (!glass.on) {
      return Container(color: color, child: ReadableWidth(child: child));
    }
    return ReadableWidth(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
        child: DecoratedBox(
          decoration: GlassDecoration(
            glass,
            gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: pill(color)),
            sheen: false,
            rimmed: false,
            highlight: Colors.white.withValues(alpha: 0.35),
            shadows: [
              BoxShadow(
                  color: color.withValues(alpha: 0.45),
                  offset: const Offset(0, 8),
                  blurRadius: 14,
                  spreadRadius: -8),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
