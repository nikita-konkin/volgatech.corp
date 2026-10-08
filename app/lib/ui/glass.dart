import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../core/season.dart';
import 'layout.dart';

export '../core/season.dart';

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
    this.ornament = 0,
    this.season = Season.winter,
    this.ink = Colors.transparent,
    this.inkEdge = Colors.transparent,
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

  /// How far the ornament has grown on the glass, clear or matte, as frost
  /// on a window in winter (0: none, 1: in full; see [GlassOrnament]): what
  /// the [season] brings — frost, leaves, flowers or children on scooters —
  /// in [ink], with its [inkEdge] beside it (see [paintOrnament]).
  final double ornament;
  final Season season;
  final Color ink;
  final Color inkEdge;

  /// Matte: frosted.
  bool get scuffed => grain > 0;

  /// How strong the effect is, as [scaled] made it: 1, the full design.
  final double strength;

  /// The blur behind a frosted panel.
  double get blur => 24 * strength;

  /// This glass at [t] of its strength (0 to 1): the panels, cards and bars
  /// thicken towards [solid], the wallpaper's colour fades towards [base],
  /// and the rim, sheen, shadows and grain soften — the shape stays, and
  /// the ornament is as it was. At 1
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
      ornament: ornament,
      season: season,
      ink: ink,
      inkEdge: inkEdge,
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
    ink: Color(0xD9FFFFFF),
    inkEdge: Color(0x4D334E70),
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
    ink: Color(0x47FFFFFF),
    inkEdge: Color(0x66000000),
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
    ink: Color(0x66334E70),
    inkEdge: Color(0xE6FFFFFF),
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
    ink: Color(0x47FFFFFF),
    inkEdge: Color(0x66000000),
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

  /// [ornament]: glass with its ornament grown that far, of [season].
  @override
  Glass copyWith({bool? on, double? ornament, Season? season}) => Glass(
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
        ornament: (ornament ?? this.ornament).clamp(0.0, 1.0),
        season: season ?? this.season,
        ink: ink,
        inkEdge: inkEdge,
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
/// glass, [seed] picks this piece's own ornament (by default, its size's).
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
    // Matte glass's frosting, and the ornament grown on the glass, moving
    // with it.
    if ((g.scuffed || g.ornament > 0) && d.sheen) {
      canvas
        ..save()
        ..clipRRect(shape);
      paintTexture(canvas, rect, GlassTexture.grain, rect.topLeft, g.grain);
      paintOrnament(canvas, rect, g,
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

/// Ink of one weight: [path], to draw at [depth] (0 to 1) of the ink's
/// colour over its edge, which shows [lift] beside it (see
/// [paintOrnament]).
typedef OrnamentMark = ({Path path, double depth, double lift});

/// The ornament on a piece of glass, in fine raised lines as frost draws
/// them on a window, for the time of year ([Season]):
///
/// * winter — frost, grown as fractal crystals. Each is a snowflake of six
///   arms alike; off each arm, pairs of branches at sixty degrees, shorter
///   towards its tip; each branch the same again, smaller, three times
///   over. Big ones grow first from the edges — most from the bottom,
///   seldom from the top — then smaller ones fill the room left. Where ice
///   reaches ice another crystal got to first, it stops: they meet but
///   don't cross;
/// * autumn — maple, birch and oak leaves, veined, fallen into a pile along
///   the bottom and still falling above it;
/// * spring — a meadow along the bottom, daisies, blossoms and tulips on
///   stems with leaves among the grass, and blossoms drifting above;
/// * summer — schoolchildren with backpacks riding kick scooters along the
///   bottom, and in a tall panel along lanes above it.
///
/// [GlassOrnament.of] its size, how far it has grown (0 to 1) and the
/// season, as marks to draw in order. Leaves, flowers and riders keep clear
/// of each other, each drawn line by line as a pen would. A piece's seed
/// keeps its ornament as it grows: it only grows on.
@immutable
class GlassOrnament {
  const GlassOrnament._(this.marks);

  final List<OrnamentMark> marks;

  /// Ink by weight, fine to bold — for frost: twigs, branches, arms — one
  /// path each, to draw at once.
  static const _depths = 3;

  static final _made = <(Season, int, int, int, int), GlassOrnament>{};

  static GlassOrnament of(Size size, double grown, int seed, Season season) {
    final key = (
      season,
      seed,
      size.width.round(),
      size.height.round(),
      (grown.clamp(0.0, 1.0) * 100).round(),
    );
    if (_made[key] case final made?) return made;
    if (_made.length >= 128) _made.clear();
    return _made[key] = _make(
        _Sketch.of(Size(key.$3.toDouble(), key.$4.toDouble()), seed, season),
        key.$5 / 100);
  }

  /// The ornament on a piece [size] across, drawn in full: each line as
  /// far as it got — of which crystal, leaf, flower or rider; whether one
  /// of the small ones between; whether it springs from no other line;
  /// and its weight, 0 the boldest (for frost, how many branchings from an
  /// arm).
  @visibleForTesting
  static List<
          ({int group, bool small, bool root, int level, List<Offset> line})>
      strokes(Size size, int seed, Season season) {
    final sketch = _Sketch.of(size, seed, season);
    return [
      for (final s in sketch.strokes)
        if (s.alive > 0)
          (
            group: s.group,
            small: sketch._small[s.group],
            root: s.parent < 0,
            level: s.level,
            line: s.points.sublist(0, s.alive + 1),
          ),
    ];
  }

  static GlassOrnament _make(_Sketch sketch, double grown) {
    if (grown <= 0) return const GlassOrnament._([]);
    final paths = [for (var i = 0; i < _depths; i++) Path()];
    for (final s in sketch.strokes) {
      final reach = math.min(
          sketch.reach(s.group, grown) - s.from, s.alive * _Sketch.step);
      if (reach <= 0) continue;
      final wide = const [1.6, 1.1, 0.75, 0.55][s.level] * (0.6 + 0.4 * grown);
      paths[_depths - 1 - math.min(s.level, _depths - 1)]
          .addPolygon(s.outline(reach, wide), true);
    }
    return GlassOrnament._([
      for (var k = 0; k < _depths; k++)
        (path: paths[k], depth: _strength(k), lift: 0.35 + 0.2 * k),
    ]);
  }

  /// How strongly ink of weight [k] shows: the boldest most.
  static double _strength(int k) => 0.55 + 0.45 * (k + 1) / _depths;
}

/// An ornament on a piece of glass drawn in full, the same at any stage:
/// its strokes, where each runs, and how far each got. Strokes come in
/// groups — a crystal, a leaf, a flower, a rider — each drawn from a stage
/// of its own on; [reach] says how far along a group it has got at a stage.
class _Sketch {
  final strokes = <_Stroke>[];

  /// For each group: the stage it starts at, how many stages it takes to
  /// draw in full, how far it runs along it, and whether it is one of the
  /// small ones between.
  final _appear = <double>[], _span = <double>[], _longest = <double>[];
  final _small = <bool>[];

  /// For each crystal: how long its arms are.
  final _radius = <double>[];

  /// Pixels between a stroke's points.
  static const step = 2.0;

  /// Ice keeps this far (a cell, in pixels) from another crystal's; a
  /// drawing, two cells from another (a tuft of grass, one).
  static const _cell = 3.0;

  /// How far past the edges the ornament is kept track of: a crystal
  /// centred on one spreads out past it too.
  static const _margin = 24.0;

  double reach(int group, double stage) =>
      (stage - _appear[group]) / _span[group] * _longest[group];

  double _time(int group, double along) =>
      _appear[group] + along / _longest[group] * _span[group];

  static final _drawn = <(Season, int, int, int), _Sketch>{};

  static _Sketch of(Size size, int seed, Season season) {
    final key = (season, seed, size.width.round(), size.height.round());
    if (_drawn[key] case final sketch?) return sketch;
    if (_drawn.length >= 64) _drawn.clear();
    final sketch = _Sketch();
    if (size.width > 0 && size.height > 0) {
      final rnd = math.Random(seed);
      switch (season) {
        case Season.winter:
          sketch._frost(size, rnd);
        case Season.autumn:
          sketch._leaves(size, rnd);
        case Season.spring:
          sketch._flowers(size, rnd);
        case Season.summer:
          sketch._riders(size, rnd);
      }
    }
    return _drawn[key] = sketch;
  }

  /// Winter: frost grown as fractal crystals (see [GlassOrnament]).
  void _frost(Size size, math.Random rnd) {
    final w = size.width, h = size.height;
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
      _crystal(centre, turn, arm, i / count * 0.45, 0.4,
          inwards: inwards, small: false);
    }

    // Then smaller ones in the room left.
    final flakes = (w * h / 3500).clamp(1, 40).round();
    for (var i = 0; i < flakes; i++) {
      final centre = Offset(rnd.nextDouble() * w, rnd.nextDouble() * h);
      final radius =
          math.min(50.0, (0.12 + 0.18 * rnd.nextDouble()) * small + 4);
      final turn = rnd.nextDouble() * math.pi / 3;
      _crystal(centre, turn, _arm(rnd, radius), 0.4 + 0.45 * i / flakes, 0.15,
          small: true);
    }

    // Grow it all in the order it would grow. Where a step comes within a
    // cell of another crystal's ice, that branch stops; a branch that would
    // spring from beyond where its parent stopped never grows.
    final steps = <(double, int, int)>[
      for (var b = 0; b < strokes.length; b++)
        for (var j = 0; j < strokes[b].points.length - 1; j++)
          (_time(strokes[b].group, strokes[b].from + (j + 1) * step), b, j),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    final cols = ((w + 2 * _margin) / _cell).ceil() + 1,
        rows = ((h + 2 * _margin) / _cell).ceil() + 1;
    final owner = List<int>.filled(cols * rows, -1);
    (int, int) cell(Offset p) => (
          ((p.dx + _margin) / _cell).floor(),
          ((p.dy + _margin) / _cell).floor()
        );
    bool free(Offset p, int group) {
      final (cx, cy) = cell(p);
      for (var y = math.max(0, cy - 1); y <= math.min(rows - 1, cy + 1); y++) {
        for (var x = math.max(0, cx - 1);
            x <= math.min(cols - 1, cx + 1);
            x++) {
          final o = owner[y * cols + x];
          if (o >= 0 && o != group) return false;
        }
      }
      return true;
    }

    void take(Offset p, int group) {
      final (cx, cy) = cell(p);
      if (cx >= 0 && cy >= 0 && cx < cols && cy < rows) {
        owner[cy * cols + cx] = group;
      }
    }

    // A small crystal grows only where there is room for it whole — not a
    // stray arm or two squeezed in between.
    bool roomy(int crystal) {
      final centre = strokes.firstWhere((s) => s.group == crystal).points[0];
      final r = _radius[crystal] * 0.8;
      for (var y = centre.dy - r; y <= centre.dy + r; y += _cell) {
        for (var x = centre.dx - r; x <= centre.dx + r; x += _cell) {
          final p = Offset(x, y);
          if ((p - centre).distance <= r && !free(p, crystal)) return false;
        }
      }
      return true;
    }

    final room = <int, bool>{};
    final stopped = List.filled(strokes.length, false);
    for (final (_, b, j) in steps) {
      if (stopped[b]) continue;
      final stroke = strokes[b];
      if (_small[stroke.group] &&
          !room.putIfAbsent(stroke.group, () => roomy(stroke.group))) {
        stopped[b] = true;
        continue;
      }
      final a = stroke.points[j], z = stroke.points[j + 1];
      final mid = Offset.lerp(a, z, 0.5)!;
      final sprung = j > 0 ||
          (stroke.parent < 0
              ? free(a, stroke.group)
              : strokes[stroke.parent].alive * step >= stroke.at);
      if (!sprung || !free(mid, stroke.group) || !free(z, stroke.group)) {
        stopped[b] = true;
        continue;
      }
      if (j == 0) take(a, stroke.group);
      take(mid, stroke.group);
      take(z, stroke.group);
      stroke.alive = j + 1;
    }
  }

  /// A crystal of six [arm]s alike about [centre], the first at [turn],
  /// starting at stage [appear] and grown in full [span] stages later. One
  /// on an edge leaves out the arms that would point off the glass, away
  /// from [inwards].
  void _crystal(
      Offset centre, double turn, List<_Shoot> arm, double appear, double span,
      {double? inwards, required bool small}) {
    final crystal = _appear.length, first = strokes.length;
    for (var a = 0; a < 6; a++) {
      final angle = turn + a * math.pi / 3;
      if (inwards != null && math.cos(angle - inwards) < -0.5) continue;
      final (sin, cos) = (math.sin(angle), math.cos(angle));
      Offset turned(Offset p) =>
          Offset(p.dx * cos - p.dy * sin, p.dx * sin + p.dy * cos);
      final base = strokes.length;
      for (final shoot in arm) {
        final heading = shoot.heading + angle;
        final from = centre + turned(shoot.from);
        final along = Offset(math.cos(heading), math.sin(heading)) * step;
        final steps = (shoot.length / step).floor();
        strokes.add(_Stroke(
            crystal,
            shoot.level,
            shoot.parent < 0 ? -1 : base + shoot.parent,
            shoot.at,
            shoot.along,
            [for (var j = 0; j <= steps; j++) from + along * j.toDouble()],
            List.filled(steps + 1, heading)));
      }
    }
    if (strokes.length == first) return;
    _appear.add(appear);
    _span.add(span);
    _small.add(small);
    _radius.add(arm.first.length);
    _longest.add(
        strokes.skip(first).map((s) => s.from + s.length).reduce(math.max));
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

  /// A drawing: [lines] in the order a pen draws them, one group from
  /// stage [appear] on, drawn in full [span] stages later.
  void _draw(List<_Line> lines, double appear, double span,
      {bool small = false}) {
    final group = _appear.length;
    var along = 0.0;
    for (final line in lines) {
      if (line.points.length < 2) continue;
      final stroke = _Stroke(
          group, line.level, -1, 0, along, line.points, _headings(line.points),
          pen: !line.taper)
        ..alive = line.points.length - 1;
      strokes.add(stroke);
      along += stroke.length;
    }
    if (along == 0) return;
    _appear.add(appear);
    _span.add(span);
    _small.add(small);
    _radius.add(0);
    _longest.add(along);
  }

  /// [drawings] one after another, from [first] to [last] of the stages,
  /// each drawn in [span].
  void _drawAll(
      List<List<_Line>> drawings, double first, double last, double span,
      {bool small = false}) {
    for (final (i, lines) in drawings.indexed) {
      _draw(lines, first + (last - first) * i / drawings.length, span,
          small: small);
    }
  }

  /// Which way [points] head at each: from the one before to the one
  /// after; at the ends of a closed line, across where they meet.
  static List<double> _headings(List<Offset> points) {
    final n = points.length;
    final closed = n > 2 && (points.first - points.last).distance < 0.5;
    return [
      for (var j = 0; j < n; j++)
        closed && (j == 0 || j == n - 1)
            ? (points[1] - points[n - 2]).direction
            : (points[math.min(j + 1, n - 1)] - points[math.max(j - 1, 0)])
                .direction,
    ];
  }

  /// Autumn: leaves fallen into a pile along the bottom and still falling
  /// above it, the lowest drawn first.
  void _leaves(Size size, math.Random rnd) {
    final w = size.width, h = size.height;
    final room = _Room(size);
    final short = math.min(w, h);
    final fallen = <(double, List<_Line>)>[];
    final count = (w * h / 1600).clamp(2, 64).round();
    for (var i = 0; i < count; i++) {
      // How far up it lies — low down likeliest: they fall. Where there is
      // no room left at that height, it doesn't land higher up instead:
      // they pile up.
      final up = _pow(rnd.nextDouble(), 2.2);
      for (var tries = 0; tries < 8; tries++) {
        final length =
            math.min(46.0, (0.26 + 0.22 * rnd.nextDouble()) * short + 8);
        final drop = h + 0.15 * length;
        final at = Offset(rnd.nextDouble() * w, drop - drop * up);
        final leaf = switch (rnd.nextInt(3)) {
          0 => _maple(rnd),
          1 => _birch(rnd),
          _ => _oak(rnd),
        };
        final lines = _lay(
            leaf,
            _place(at, length,
                turn: rnd.nextDouble() * 2 * math.pi,
                flip: rnd.nextBool(),
                from: const Offset(0, -0.5)));
        if (!room.fits(lines, at, 0.5 * length)) continue;
        room.take(lines, at, 0.5 * length);
        fallen.add((at.dy, lines));
        break;
      }
    }
    fallen.sort((a, b) => b.$1.compareTo(a.$1));
    _drawAll([for (final (_, lines) in fallen) lines], 0, 0.92, 0.08);
  }

  /// A maple leaf, a unit long from its stalk at the origin up to its tip:
  /// five pointed lobes, toothed, a vein to each.
  static List<_Line> _maple(math.Random rnd) {
    const centre = Offset(0, -0.36);
    Offset polar(double degrees, double r) {
      final a = degrees * math.pi / 180;
      return centre + Offset(math.sin(a), -math.cos(a)) * r;
    }

    // Each lobe: where it points (degrees from up), half as wide, how far
    // out its tip is.
    final lobes = [
      for (final (mid, half, tip) in const [
        (-108.0, 24.0, 0.34),
        (-56.0, 26.0, 0.54),
        (0.0, 28.0, 0.62),
        (56.0, 26.0, 0.54),
        (108.0, 24.0, 0.34),
      ])
        (mid, half, tip * (0.9 + 0.2 * rnd.nextDouble())),
    ];
    double radius(double degrees) {
      for (final (mid, half, tip) in lobes) {
        final t = (degrees - mid).abs() / half;
        if (t > 1) continue;
        final r = 0.2 + (tip - 0.2) * _pow(1 - t, 1.3);
        // Teeth along its sides.
        final tooth = (degrees - mid).abs() / 10 % 1;
        return t > 0.15 && t < 0.8 ? r * (1 + 0.08 * tooth) : r;
      }
      // Between the lowest lobes, in to the stalk.
      return 0.2 - 0.13 * ((degrees.abs() - 132) / 48).clamp(0.0, 1.0);
    }

    final bend = (rnd.nextDouble() - 0.5) * 0.12;
    return _bent(bend, [
      _pen([
        for (var d = -178.0; d <= 178; d += 2) polar(d, radius(d)),
        polar(-178, radius(-178)),
      ]),
      _pen(
          _smooth([
            polar(180, 0.07),
            const Offset(0.01, -0.15),
            const Offset(0.03, 0)
          ]),
          1),
      for (final (mid, _, tip) in lobes)
        _pen([const Offset(0, -0.32), polar(mid, tip * 0.8)], 2),
    ]);
  }

  /// A birch leaf, a unit long from its stalk at the origin up to its tip:
  /// broad near the stalk, pointed, finely toothed; a midrib and veins off
  /// it in pairs.
  static List<_Line> _birch(math.Random rnd) {
    final wide = 0.32 + 0.08 * rnd.nextDouble();
    double y(double t) => -0.1 - 0.9 * t;
    double half(double t) {
      final h = wide * _pow(math.sin(math.pi * _pow(t, 0.7)), 0.9);
      return t > 0.08 && t < 0.94 ? h * (1 + 0.06 * (t * 18 % 1)) : h;
    }

    return _bent((rnd.nextDouble() - 0.5) * 0.25, [
      _pen(_outline(half, y)),
      _pen(
          _smooth([
            Offset(0, y(0)),
            const Offset(0.01, 0),
            const Offset(0.03, 0.1)
          ]),
          1),
      _pen([for (var t = 0.0; t <= 0.96; t += 0.08) Offset(0, y(t))], 1),
      for (final t in const [0.16, 0.3, 0.44, 0.58, 0.72])
        for (final side in const [-1.0, 1.0])
          _pen([
            Offset(0, y(t)),
            Offset(side * 0.78 * half(t + 0.09), y(t + 0.09))
          ], 2),
    ]);
  }

  /// An oak leaf, a unit long from its stalk at the origin up to its tip:
  /// round lobes, a midrib and a vein out to each.
  static List<_Line> _oak(math.Random rnd) {
    final wide = 0.3 + 0.06 * rnd.nextDouble();
    const lobes = 4.5;
    double y(double t) => -0.08 - 0.92 * t;
    double half(double t) =>
        wide *
        math.sin(math.pi * _pow(t, 0.85)) *
        (0.58 + 0.42 * _pow(math.sin(math.pi * lobes * t).abs(), 0.6));

    return _bent((rnd.nextDouble() - 0.5) * 0.25, [
      _pen(_outline(half, y)),
      _pen([Offset(0, y(0)), const Offset(0.01, 0.05)], 1),
      _pen([for (var t = 0.0; t <= 0.94; t += 0.08) Offset(0, y(t))], 1),
      for (var k = 0; k < 4; k++)
        for (final side in const [-1.0, 1.0])
          _pen([
            Offset(0, y((k + 0.5) / lobes - 0.06)),
            Offset(side * 0.75 * half((k + 0.5) / lobes), y((k + 0.5) / lobes)),
          ], 2),
    ]);
  }

  /// A leaf's outline, [half] as wide at each [y] along it (0 the stalk, 1
  /// the tip): up the right side and down the left.
  static List<Offset> _outline(
      double Function(double) half, double Function(double) y) {
    const n = 72;
    return [
      for (var i = 0; i <= n; i++) Offset(half(i / n), y(i / n)),
      for (var i = n - 1; i >= 0; i--) Offset(-half(i / n), y(i / n)),
    ];
  }

  /// [lines] bent sideways by [bend], the more the farther up.
  static List<_Line> _bent(double bend, List<_Line> lines) => [
        for (final l in lines)
          (
            points: [
              for (final p in l.points) Offset(p.dx + bend * p.dy * p.dy, p.dy)
            ],
            level: l.level,
            taper: l.taper,
          ),
      ];

  /// Spring: a meadow along the bottom — daisies, blossoms and tulips on
  /// stems with leaves, grass between — then blossoms drifting above.
  void _flowers(Size size, math.Random rnd) {
    final w = size.width, h = size.height;
    final room = _Room(size);
    final tall = math.min(h, 150.0);

    final meadow = <List<_Line>>[];
    for (var x = 4 + 10 * rnd.nextDouble(); x < w - 4;) {
      var grown = false;
      for (var tries = 0; tries < 5 && !grown; tries++) {
        var height = (0.4 + 0.4 * rnd.nextDouble()) * tall + 6;
        final head = (0.17 * height).clamp(5.0, 16.0);
        // Its head on the glass, whole.
        height = math.min(height, h - 3 - 2 * head);
        if (height < 2 * head) continue;
        final lines = _flower(rnd, Offset(x, h + 2), height, head);
        final top = Offset(x, h - height);
        if (!room.fits(lines, top, head)) continue;
        room.take(lines, top, head);
        meadow.add(lines);
        grown = true;
      }
      x += grown ? 8 + 14 * rnd.nextDouble() : 6;
    }
    meadow.shuffle(rnd);

    final grass = <List<_Line>>[];
    for (var x = 6 * rnd.nextDouble(); x < w; x += 5 + 6 * rnd.nextDouble()) {
      final lines = _tuft(
          rnd, Offset(x, h + 1), (0.1 + 0.1 * rnd.nextDouble()) * tall + 4);
      if (!room.fits(lines, Offset(x, h), 0, gap: 1)) continue;
      room.take(lines, Offset(x, h), 0);
      grass.add(lines);
    }
    grass.shuffle(rnd);

    final drifting = <List<_Line>>[];
    final count = (w * h / 4000).clamp(1, 36).round();
    for (var i = 0; i < count; i++) {
      for (var tries = 0; tries < 6; tries++) {
        final r = math.min(12.0, (0.03 + 0.05 * rnd.nextDouble()) * tall + 4);
        final at = Offset(rnd.nextDouble() * w, rnd.nextDouble() * h * 0.9);
        final lines = r < 8 || rnd.nextDouble() < 0.6
            ? _blossom(rnd, at, r)
            : _daisy(rnd, at, r);
        if (!room.fits(lines, at, r)) continue;
        room.take(lines, at, r);
        drifting.add(lines);
        break;
      }
    }

    _drawAll(meadow, 0, 0.5, 0.12);
    _drawAll(grass, 0.05, 0.55, 0.08);
    _drawAll(drifting, 0.55, 0.92, 0.08, small: true);
  }

  /// A flower on a stem from [ground], [height] tall, its head [head]
  /// across: a daisy, a blossom or a tulip, a leaf or two on the stem.
  static List<_Line> _flower(
      math.Random rnd, Offset ground, double height, double head) {
    final lean = (rnd.nextDouble() - 0.5) * 0.35 * height;
    final top = ground + Offset(lean, -height);
    final stem = _even(_smooth([
      ground,
      ground +
          Offset(lean * 0.2 + (rnd.nextDouble() - 0.5) * 0.1 * height,
              -0.5 * height),
      top,
    ]));
    final lines = <_Line>[_pen(stem, 1)];
    final side = rnd.nextBool() ? 1.0 : -1.0;
    for (var k = 0, n = 1 + rnd.nextInt(2); k < n; k++) {
      final i = ((0.18 + 0.2 * rnd.nextDouble() + 0.18 * k) * (stem.length - 1))
          .round()
          .clamp(1, stem.length - 2);
      final along = (stem[i + 1] - stem[i - 1]).direction;
      lines.add(_pen(
          _blade(
              stem[i],
              along +
                  (k.isEven ? side : -side) * (0.6 + 0.3 * rnd.nextDouble()),
              math.min(0.3 * height, 24.0),
              0.24),
          1));
    }
    final kind = rnd.nextDouble();
    lines.addAll(head >= 8 && kind < 0.4
        ? _daisy(rnd, top - Offset(0, head), head)
        : kind < 0.7
            ? _blossom(rnd, top - Offset(0, head), head, turn: math.pi / 2)
            : _tulip(top, head));
    return lines;
  }

  /// A leaf's outline from [base], [length] long towards [heading], at its
  /// widest [wide] of its length across.
  static List<Offset> _blade(
      Offset base, double heading, double length, double wide) {
    final along = Offset(math.cos(heading), math.sin(heading)),
        across = Offset(-along.dy, along.dx);
    Offset at(double t, double side) =>
        base +
        along * (t * length) +
        across * (side * wide * length / 2 * math.sin(math.pi * _pow(t, 0.8)));
    return [
      for (var i = 0; i <= 12; i++) at(i / 12, 1),
      for (var i = 11; i >= 0; i--) at(i / 12, -1),
    ];
  }

  /// A daisy [r] across about [centre]: slim petals round a round heart.
  static List<_Line> _daisy(math.Random rnd, Offset centre, double r) {
    final n = 8 + rnd.nextInt(5);
    final heart = 0.3 * r, turn = rnd.nextDouble() * 2 * math.pi;
    final inner = heart * 1.35, length = r - inner, mid = (inner + r) / 2;
    final slim = math.min(0.32 * length, mid * math.pi / n * 0.7);
    // Petal [k]: a slim loop out from the heart.
    _Line petal(int k) {
      final a = turn + 2 * math.pi * k / n;
      final along = Offset(math.cos(a), math.sin(a)),
          across = Offset(-along.dy, along.dx);
      return _pen([
        for (var i = 0; i <= 16; i++)
          centre +
              along * (mid - length / 2 * math.cos(2 * math.pi * i / 16)) +
              across * (slim * math.sin(2 * math.pi * i / 16)),
      ], 1);
    }

    return [
      _pen(_ring(centre, heart), 1),
      for (var k = 0; k < n; k++) petal(k)
    ];
  }

  /// A blossom [r] across about [centre]: five round petals in one line,
  /// the first towards [turn], and a small heart.
  static List<_Line> _blossom(math.Random rnd, Offset centre, double r,
      {double? turn}) {
    final from = turn ?? rnd.nextDouble() * 2 * math.pi;
    Offset edge(double a) {
      // 1 across a petal's middle, 0 between two.
      final petal = _pow(math.cos(2.5 * a).abs(), 0.5);
      return centre +
          Offset(math.cos(a + from), math.sin(a + from)) *
              (r * (0.42 + 0.58 * petal));
    }

    return [
      _pen([for (var i = 0; i <= 80; i++) edge(2 * math.pi * i / 80)], 1),
      _pen(_ring(centre, 0.2 * r), 1),
    ];
  }

  /// A tulip's cup, [r] across, on [base]: three pointed petals.
  static List<_Line> _tulip(Offset base, double r) {
    Offset p(double x, double y) => base + Offset(x, y) * r;
    return [
      _pen([
        ..._smooth([p(0, 0), p(-0.45, -0.25), p(-0.58, -0.75), p(-0.45, -1.3)]),
        p(-0.22, -0.85),
        p(0, -1.4),
        p(0.22, -0.85),
        ..._smooth([p(0.45, -1.3), p(0.58, -0.75), p(0.45, -0.25), p(0, 0)]),
      ], 1),
      _pen(_smooth([p(-0.22, -0.85), p(-0.1, -0.45), p(0.02, -0.15)]), 2),
    ];
  }

  /// A tuft of grass from [ground]: two or three blades, [height] tall at
  /// most, fanning out.
  static List<_Line> _tuft(math.Random rnd, Offset ground, double height) {
    final n = 2 + rnd.nextInt(2);
    _Line blade(int k) {
      final lean = (k - (n - 1) / 2) * 0.35 * height +
          (rnd.nextDouble() - 0.5) * 0.2 * height;
      final tall = height * (0.7 + 0.3 * rnd.nextDouble());
      final root = ground + Offset(k * 1.5, 0);
      return (
        points: _smooth([
          root,
          root + Offset(lean * 0.25, -0.55 * tall),
          root + Offset(lean, -tall),
        ]),
        level: 2,
        taper: true,
      );
    }

    return [for (var k = 0; k < n; k++) blade(k)];
  }

  /// Summer: schoolchildren with backpacks riding kick scooters along the
  /// bottom, and in a tall panel along lanes above it.
  void _riders(Size size, math.Random rnd) {
    final w = size.width, h = size.height;
    final room = _Room(size);
    final tall = (0.62 * h).clamp(26.0, 64.0);
    final riders = <List<_Line>>[];
    // Above the bottom, lanes far apart and riders few.
    for (var ground = h - 1; ground - tall >= 2; ground -= tall * 2.2) {
      final bottom = ground == h - 1;
      for (var x = (0.2 + 0.6 * rnd.nextDouble()) * tall; x < w;) {
        final unit = tall * (0.85 + 0.15 * rnd.nextDouble());
        final rightwards = rnd.nextBool();
        // From the speed lines behind to the cap's brim in front.
        final origin = x + (rightwards ? 0.42 : 0.26) * unit;
        final end = x + 0.68 * unit;
        if (end > w - 2) break;
        final lines = _lay(_rider(rnd),
            _place(Offset(origin, ground), unit, flip: !rightwards));
        final centre = Offset(origin, ground - 0.45 * unit);
        if (room.fits(lines, centre, 0.35 * unit)) {
          room.take(lines, centre, 0.35 * unit);
          riders.add(lines);
          x = end +
              (bottom
                      ? 0.15 + 0.9 * rnd.nextDouble()
                      : 0.8 + 2 * rnd.nextDouble()) *
                  tall;
        } else {
          x += 0.2 * tall;
        }
      }
    }
    riders.shuffle(rnd);
    _drawAll(riders, 0, 0.92, 0.08);
  }

  /// A schoolchild with a backpack on a kick scooter, a unit tall, riding
  /// rightwards along the ground at the origin: in a cap, or with a
  /// ponytail and a skirt; the free foot kicked back, or down pushing off.
  static List<_Line> _rider(math.Random rnd) {
    final girl = rnd.nextBool(), push = rnd.nextDouble();
    Offset pose(Offset back, Offset down) => Offset.lerp(back, down, push)!;
    const hip = Offset(-0.03, -0.42), shoulder = Offset(0.05, -0.67);
    const bar = Offset(0.18, -0.62);
    final up = (shoulder - hip) / (shoulder - hip).distance;
    final behind = Offset(up.dy, -up.dx);
    // The backpack: a rounded box on the back, [a] up it and [b] out
    // behind; its flap across.
    Offset pack(double a, double b) => hip + up * a + behind * b;
    Offset box(double t) {
      double round(double v) => v.sign * _pow(v.abs(), 0.35);
      return pack(
          0.16 + 0.09 * round(math.cos(t)), 0.05 + 0.05 * round(math.sin(t)));
    }

    return [
      // The scooter: wheels, deck, the stem up to the handlebar.
      _pen(_ring(const Offset(-0.22, -0.045), 0.045)),
      _pen(_ring(const Offset(0.24, -0.045), 0.045)),
      _pen([const Offset(-0.27, -0.1), const Offset(0.23, -0.1)]),
      _pen([const Offset(0.24, -0.045), bar]),
      _pen([const Offset(0.13, -0.64), const Offset(0.22, -0.605)], 1),
      // Standing on the deck; the other leg kicking.
      _pen([
        hip,
        const Offset(0.05, -0.25),
        const Offset(0.0, -0.11),
        const Offset(0.07, -0.105),
      ]),
      _pen([
        hip,
        pose(const Offset(-0.13, -0.28), const Offset(-0.0, -0.24)),
        pose(const Offset(-0.3, -0.16), const Offset(-0.05, -0.03)),
        pose(const Offset(-0.35, -0.11), const Offset(0.02, -0.015)),
      ]),
      if (girl)
        _pen([
          const Offset(-0.01, -0.5),
          const Offset(-0.11, -0.36),
          const Offset(0.07, -0.36),
          const Offset(-0.01, -0.5),
        ], 1),
      // Body, arm to the handlebar, head.
      _pen([hip, const Offset(0.065, -0.71)]),
      _pen([
        shoulder,
        const Offset(0.125, -0.55),
        bar + const Offset(-0.005, 0.005)
      ]),
      _pen(_ring(const Offset(0.09, -0.81), 0.095)),
      if (girl)
        _pen(
            _smooth([
              const Offset(0.005, -0.85),
              const Offset(-0.07, -0.885),
              const Offset(-0.12, -0.82),
              const Offset(-0.095, -0.75),
            ]),
            1)
      else
        _pen([
          const Offset(-0.003, -0.835),
          const Offset(0.175, -0.865),
          const Offset(0.255, -0.845),
        ], 1),
      _pen([for (var i = 0; i <= 32; i++) box(2 * math.pi * i / 32)], 1),
      _pen([pack(0.2, 0), pack(0.2, 0.1)], 2),
      // Speed lines behind.
      _pen([const Offset(-0.36, -0.55), const Offset(-0.24, -0.55)], 3),
      _pen([const Offset(-0.4, -0.42), const Offset(-0.26, -0.42)], 3),
      _pen([const Offset(-0.42, -0.03), const Offset(-0.31, -0.03)], 3),
    ];
  }
}

/// One branch of a crystal's arm, laid out from the origin along heading 0
/// (see [_Sketch._arm]).
typedef _Shoot = ({
  Offset from,
  double heading,
  double length,
  int level,
  int parent,
  double at,
  double along,
});

/// A line of a drawing: its [points], of [level] weight (0 the boldest),
/// narrowing to its end as ice does ([taper]) or even, as a pen draws.
typedef _Line = ({List<Offset> points, int level, bool taper});

_Line _pen(List<Offset> points, [int level = 0]) =>
    (points: points, level: level, taper: false);

double _pow(double x, double e) => math.pow(x, e).toDouble();

/// [lines] laid out on the glass by [place], with points put in between so
/// that none is farther than a step from the next.
List<_Line> _lay(List<_Line> lines, Offset Function(Offset) place) => [
      for (final l in lines)
        (
          points: _even([for (final p in l.points) place(p)]),
          level: l.level,
          taper: l.taper,
        ),
    ];

/// Where a drawing [unit] pixels to its unit goes: its point [from] at
/// [at], turned by [turn] and, [flip]ped, mirrored.
Offset Function(Offset) _place(Offset at, double unit,
    {double turn = 0, bool flip = false, Offset from = Offset.zero}) {
  final (sin, cos) = (math.sin(turn), math.cos(turn));
  return (p) {
    final x = (flip ? from.dx - p.dx : p.dx - from.dx) * unit,
        y = (p.dy - from.dy) * unit;
    return at + Offset(x * cos - y * sin, x * sin + y * cos);
  };
}

/// [line] with points put in between so that none is farther than a step
/// from the next, keeping its corners; any too near the last left out.
List<Offset> _even(List<Offset> line) {
  final out = <Offset>[];
  for (final p in line) {
    if (out.isEmpty) {
      out.add(p);
      continue;
    }
    final from = out.last, d = (p - from).distance;
    if (d < 0.4) continue;
    final n = (d / _Sketch.step).ceil();
    for (var k = 1; k <= n; k++) {
      out.add(Offset.lerp(from, p, k / n)!);
    }
  }
  return out;
}

/// A smooth curve through [knots], [per] points from each to the next.
List<Offset> _smooth(List<Offset> knots, {int per = 8}) {
  final n = knots.length;
  Offset k(int i) => knots[i.clamp(0, n - 1)];
  // A Catmull-Rom spline: [t] of the way from knot [i] to the next.
  Offset at(int i, double t) {
    final p0 = k(i - 1), p1 = k(i), p2 = k(i + 1), p3 = k(i + 2);
    final t2 = t * t, t3 = t2 * t;
    return (p1 * 2 +
            (p2 - p0) * t +
            (p0 * 2 - p1 * 5 + p2 * 4 - p3) * t2 +
            (p1 * 3 - p0 - p2 * 3 + p3) * t3) *
        0.5;
  }

  return [
    for (var i = 0; i < n - 1; i++)
      for (var s = 0; s < per; s++) at(i, s / per),
    knots.last,
  ];
}

/// A circle [r] across about [centre], round to where it started.
List<Offset> _ring(Offset centre, double r) => [
      for (var i = 0; i <= 24; i++)
        centre +
            Offset(math.cos(2 * math.pi * i / 24),
                    math.sin(2 * math.pi * i / 24)) *
                r,
    ];

/// Where on a piece of glass is drawn on: cells a few pixels across,
/// reaching a little past its edges, and each drawing's middle and size.
class _Room {
  _Room(Size size)
      : cols = ((size.width + 2 * _Sketch._margin) / _Sketch._cell).ceil() + 1,
        rows = ((size.height + 2 * _Sketch._margin) / _Sketch._cell).ceil() + 1;

  final int cols, rows;
  late final _taken = List<bool>.filled(cols * rows, false);
  final _drawings = <(Offset, double)>[];

  (int, int) _cell(Offset p) => (
        ((p.dx + _Sketch._margin) / _Sketch._cell).floor(),
        ((p.dy + _Sketch._margin) / _Sketch._cell).floor()
      );

  /// Whether [lines] keep [gap] cells clear of all drawn so far, and,
  /// [centre]d [radius] across, sit neither inside another drawing nor
  /// round one.
  bool fits(List<_Line> lines, Offset centre, double radius, {int gap = 2}) {
    for (final (c, r) in _drawings) {
      if ((c - centre).distance < 0.5 * (r + radius)) return false;
    }
    for (final line in lines) {
      for (final p in line.points) {
        final (cx, cy) = _cell(p);
        for (var y = math.max(0, cy - gap);
            y <= math.min(rows - 1, cy + gap);
            y++) {
          for (var x = math.max(0, cx - gap);
              x <= math.min(cols - 1, cx + gap);
              x++) {
            if (_taken[y * cols + x]) return false;
          }
        }
      }
    }
    return true;
  }

  void take(List<_Line> lines, Offset centre, double radius) {
    _drawings.add((centre, radius));
    for (final line in lines) {
      for (final p in line.points) {
        final (cx, cy) = _cell(p);
        if (cx >= 0 && cy >= 0 && cx < cols && cy < rows) {
          _taken[cy * cols + cx] = true;
        }
      }
    }
  }
}

/// A stroke of the ornament, of group [group], [level] — for frost,
/// branchings from an arm — springing [at] that far along stroke [parent]
/// (none, for a drawing's); [from] that far along its group; [points] a
/// step apart, of which [alive] steps were drawn — for frost, before it
/// met other ice. Ice narrows from its root to its tip; a [pen]'s line is
/// even, thinning a little at its ends.
class _Stroke {
  _Stroke(this.group, this.level, this.parent, this.at, this.from, this.points,
      this.headings,
      {this.pen = false});

  final int group, level, parent;
  final double at, from;
  final List<Offset> points;
  final List<double> headings;
  final bool pen;
  int alive = 0;

  double get length => (points.length - 1) * _Sketch.step;

  /// Its line as far as [reach], [wide] at its widest; while still being
  /// drawn, it comes to a point.
  List<Offset> outline(double reach, double wide) {
    final last = (reach / _Sketch.step).ceil().clamp(1, points.length - 1);
    final done = pen && reach >= length;
    final left = <Offset>[], right = <Offset>[];
    for (var j = 0; j <= last; j++) {
      final s = math.min(j * _Sketch.step, reach);
      final tip = done ? 1.0 : ((reach - s) / 3).clamp(0.2, 1.0);
      final shape = pen
          ? 0.6 + 0.4 * math.sin(math.pi * s / length)
          : 1 - 0.65 * s / length;
      final half = wide / 2 * shape * tip;
      final h = headings[j];
      final across = Offset(-math.sin(h), math.cos(h)) * half;
      final at = j * _Sketch.step > reach
          ? Offset.lerp(points[j - 1], points[j],
              1 - (j * _Sketch.step - reach) / _Sketch.step)!
          : points[j];
      left.add(at + across);
      right.add(at - across);
    }
    return [...left, ...right.reversed];
  }
}

/// The ornament on [glass] at [rect], picked by [seed] (see
/// [GlassOrnament]): its lines in [Glass.ink], standing proud — their
/// edge, [Glass.inkEdge], shows beside them as light on the side towards
/// the light at the top left, or, if darker, as shade on the other.
void paintOrnament(Canvas canvas, Rect rect, Glass glass, int seed) {
  if (glass.ornament <= 0) return;
  final ornament =
      GlassOrnament.of(rect.size, glass.ornament, seed, glass.season);
  if (ornament.marks.isEmpty) return;
  final towards =
      glass.inkEdge.computeLuminance() > glass.ink.computeLuminance()
          ? -1.0
          : 1.0;
  Paint paint(Color c, double depth) =>
      Paint()..color = c.withValues(alpha: c.a * depth);
  canvas
    ..save()
    ..translate(rect.left, rect.top);
  for (final m in ornament.marks) {
    canvas.drawPath(m.path.shift(Offset(towards, towards) * m.lift),
        paint(glass.inkEdge, m.depth));
  }
  for (final m in ornament.marks) {
    canvas.drawPath(m.path, paint(glass.ink, m.depth));
  }
  canvas.restore();
}

/// A card's decoration: [plain] without glass; on glass, glass that keeps
/// its accent — the stripe down the left as a capsule inside the edge, or
/// the outline all round — and room for it. [seed]: what the card shows,
/// so that on glass each has an ornament of its own.
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
