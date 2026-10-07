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
    this.etch = 0,
    this.groove = Colors.transparent,
    this.glint = Colors.transparent,
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

  /// Matte glass: how richly it is etched with spirals (0: not at all, 1:
  /// in full; see [GlassEtching]). Each is cut as a groove: its wall towards
  /// the light, at the top left, in the shade of [groove], the far one
  /// catching the light, [glint] — both as at the deepest.
  final double etch;
  final Color groove;
  final Color glint;

  bool get scuffed => grain > 0 || etch > 0;

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
      etch: etch * t,
      groove: groove,
      glint: glint,
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
    groove: Color(0x660F1426),
    glint: Color(0xE6FFFFFF),
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
    groove: Color(0x99000000),
    glint: Color(0x47FFFFFF),
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

  /// [etch]: matte glass etched as richly as that.
  @override
  Glass copyWith({bool? on, double? etch}) => Glass(
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
        etch: (etch ?? this.etch).clamp(0.0, 1.0),
        groove: groove,
        glint: glint,
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
/// glass, [seed] picks this piece's own spirals (by default, its size's).
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
    // Matte glass: frosted and etched, the pattern moving with it.
    if (g.scuffed && d.sheen) {
      canvas
        ..save()
        ..clipRRect(shape);
      paintTexture(canvas, rect, GlassTexture.grain, rect.topLeft, g.grain);
      paintEtching(canvas, rect, g,
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

/// One kind of mark etching leaves: [path], in the shade of a groove's wall
/// or, [lit], the light off the other one, at [depth] (0 to 1).
typedef EtchMark = ({Path path, bool lit, double depth});

/// What is etched on a piece of matte glass, [GlassEtching.of] its size
/// and how richly (0 to 1), as marks to draw in order: spiral flourishes
/// cut in as grooves — a shaded wall towards the light at the top left, a
/// lit one away from it. Tendrils grow in from the edges, more often near a
/// corner, and wind up into a curl with a bead at its heart; the richer the
/// etching, the more of them, longer and cut deeper, with side curls
/// sprouting off them and small S-scrolls between. A piece's seed keeps its
/// pattern as the etching changes: a tendril only grows and winds on.
@immutable
class GlassEtching {
  const GlassEtching._(this.marks);

  final List<EtchMark> marks;

  /// Groove depths, shallow to deep: one path each, to draw at once.
  static const _depths = 3;

  static final _made = <(int, int, int, int), GlassEtching>{};

  static GlassEtching of(Size size, double etch, int seed) {
    final key = (
      seed,
      size.width.round(),
      size.height.round(),
      (etch.clamp(0.0, 1.0) * 100).round(),
    );
    if (_made[key] case final made?) return made;
    if (_made.length >= 128) _made.clear();
    return _made[key] = _make(size, key.$4 / 100, seed);
  }

  static GlassEtching _make(Size size, double etch, int seed) {
    final w = size.width, h = size.height;
    if (etch <= 0 || w <= 0 || h <= 0) return const GlassEtching._([]);
    final shade = [for (var i = 0; i < _depths; i++) Path()];
    final lit = [for (var i = 0; i < _depths; i++) Path()];

    // A groove along [curl] as far as [reach], [depth] deep; and, where it
    // has wound all the way, its bead.
    void cut(_Curl curl, double reach, double depth) {
      if (reach <= 0) return;
      final k = math.min(_depths - 1, (depth * _depths).floor());
      final width = 0.8 + 1.8 * depth;
      final o = const Offset(1, 1) * (0.25 + 0.45 * depth);
      shade[k].addPolygon(curl.outline(reach, width, -o), true);
      lit[k].addPolygon(curl.outline(reach, width * 0.8, o), true);
      final r = 0.9 + 1.3 * depth;
      for (final bead in curl.beads(reach)) {
        shade[k].addOval(Rect.fromCircle(center: bead - o, radius: r));
        lit[k].addOval(Rect.fromCircle(center: bead + o, radius: r * 0.8));
      }
    }

    // Every flourish is drawn up as at its fullest, the same at any
    // etching, so each keeps its place; the etching says which show and
    // how far each has grown.
    final rnd = math.Random(seed);
    final tendrils = ((w + h) * 2 / 90).clamp(3, 28).round();
    for (var i = 0; i < tendrils; i++) {
      // From anywhere round the edge, setting off along it one way or the
      // other, leaning in, and curling in.
      var round = rnd.nextDouble() * 2 * (w + h);
      final (origin, along, inwards) = round < w
          ? (Offset(round, 0), 0.0, const Offset(0, 1))
          : (round -= w) < h
              ? (Offset(w, round), math.pi / 2, const Offset(-1, 0))
              : (round -= h) < w
                  ? (Offset(w - round, h), math.pi, const Offset(0, -1))
                  : (
                      Offset(0, h - (round - w)),
                      -math.pi / 2,
                      const Offset(1, 0)
                    );
      final base = rnd.nextBool() ? along : along + math.pi;
      final inside =
          -math.sin(base) * inwards.dx + math.cos(base) * inwards.dy > 0
              ? 1.0
              : -1.0;
      final heading = base + inside * (0.25 + 0.55 * rnd.nextDouble());
      final length =
          (0.55 + 0.45 * rnd.nextDouble()) * (36 + 0.6 * math.min(w, h));
      final turns = (1.3 + 0.9 * rnd.nextDouble()) * 2 * math.pi;
      final deep = rnd.nextDouble();
      // A side curl, the other way round, off the outer side.
      final branchAt = 0.3 + 0.3 * rnd.nextDouble();
      final branchLean = 0.5 + 0.4 * rnd.nextDouble();
      final branchLength = (0.3 + 0.15 * rnd.nextDouble()) * length;
      final branchTurns = (1 + 0.5 * rnd.nextDouble()) * 2 * math.pi;
      final branches = rnd.nextDouble() < (etch - 0.35) * 1.6;

      final appear = i / tendrils * 0.7;
      final grown = ((etch - appear) / 0.3).clamp(0.0, 1.0);
      if (grown <= 0) continue;
      final depth = (0.45 + 0.55 * deep) * (0.35 + 0.65 * etch);
      final curl = _Curl.tendril(origin, heading, length, inside * turns);
      final reach = grown * length;
      cut(curl, reach, depth);
      if (branches) {
        final from = branchAt * length;
        cut(
            _Curl.tendril(
                curl.at(branchAt),
                curl.headingAt(branchAt) - inside * branchLean,
                branchLength,
                -inside * branchTurns),
            (reach - from) / (length - from) * branchLength,
            depth * 0.8);
      }
    }

    // Small S-scrolls between, from a third of the way on.
    final scrolls = (w * h / 7000).clamp(1, 32).round();
    for (var i = 0; i < scrolls; i++) {
      final from = Offset(rnd.nextDouble() * w, rnd.nextDouble() * h);
      final heading = rnd.nextDouble() * 2 * math.pi;
      final length = 40 + 40 * rnd.nextDouble();
      final turns = (1 + 0.5 * rnd.nextDouble()) * 2 * math.pi;
      final way = rnd.nextBool() ? 1.0 : -1.0;
      final deep = rnd.nextDouble();

      final appear = 0.3 + 0.6 * i / scrolls;
      final grown = ((etch - appear) / 0.15).clamp(0.0, 1.0);
      if (grown <= 0) continue;
      cut(_Curl.scroll(from, heading, length, way * turns), grown * length,
          (0.3 + 0.4 * deep) * (0.35 + 0.65 * etch));
    }

    return GlassEtching._([
      for (var k = 0; k < _depths; k++)
        (path: shade[k], lit: false, depth: _strength(k)),
      for (var k = 0; k < _depths; k++)
        (path: lit[k], lit: true, depth: _strength(k)),
    ]);
  }

  /// How strongly a groove of depth [k] shows: the deep ones most, but
  /// mostly they are wider and their walls further apart.
  static double _strength(int k) => 0.45 + 0.55 * (k + 1) / _depths;
}

/// A flourish's centre line: from [from], setting off at a heading that
/// [turning] (of how far along, 0 to 1) turns as it goes, [length] long;
/// its groove as wide as [width] of that, with a bead at the heart of each
/// curl.
class _Curl {
  _Curl(Offset from, double heading, this.length,
      {required double Function(double u) turning,
      required double wind,
      required this.width,
      required this.beadAtStart}) {
    // Fine enough for the heading to turn no more than 0.22 a step where
    // the curl is tightest ([wind]: the most it turns per whole length).
    _steps = (length / 2 + wind / 0.22).ceil();
    var at = from;
    _points.add(at);
    _headings.add(heading);
    for (var j = 0; j < _steps; j++) {
      final mid = heading + turning((j + 0.5) / _steps);
      at += Offset(math.cos(mid), math.sin(mid)) * (length / _steps);
      _points.add(at);
      _headings.add(heading + turning((j + 1) / _steps));
    }
  }

  /// A tendril: a gentle arc for its first [_tail], then a volute winding
  /// [turns] (radians; the sign, which way) in to its heart; widest at its
  /// root.
  factory _Curl.tendril(
          Offset from, double heading, double length, double turns) =>
      _Curl(from, heading, length,
          turning: (u) => u < _tail
              ? turns.sign * 0.6 * (u / _tail) * (u / _tail)
              : turns.sign * 0.6 + turns * _volute((u - _tail) / (1 - _tail)),
          wind: _wind * turns.abs() / (1 - _tail),
          width: (u) => 1 - 0.8 * u,
          beadAtStart: false);

  /// An S-scroll: out of one volute and into another wound the other way,
  /// [turns] each; widest in the middle.
  factory _Curl.scroll(
          Offset from, double heading, double length, double turns) =>
      _Curl(from, heading, length,
          turning: (u) => turns * (_volute((2 * u - 1).abs()) - 1),
          wind: 2 * _wind * turns.abs(),
          width: (u) => 0.3 + 0.7 * math.sin(math.pi * u),
          beadAtStart: true);

  /// How much of a tendril's length is the arc before its volute.
  static const _tail = 0.35;

  /// A volute's turning so far, 0 to 1, [x] of the way along it: a
  /// logarithmic spiral, the radius shrinking by the same share each turn
  /// to [_heart] of where it began — evenly spaced turns, to the eye, and
  /// a heart for the bead.
  static double _volute(double x) =>
      math.log(1 - (1 - _heart) * x) / math.log(_heart);
  static const _heart = 0.15;

  /// The most a volute turns, per its length, for each radian it turns in
  /// all: where it is tightest, at its heart.
  static final _wind = (1 - _heart) / _heart / -math.log(_heart);

  final double length;
  final double Function(double u) width;
  final bool beadAtStart;
  late final int _steps;
  final _points = <Offset>[];
  final _headings = <double>[];

  Offset at(double u) => _points[(u * _steps).round()];
  double headingAt(double u) => _headings[(u * _steps).round()];

  /// The groove's edge as far as [reach], [wide] at its widest, moved by
  /// [shift]: tapering to a point where it is still growing.
  List<Offset> outline(double reach, double wide, Offset shift) {
    final last = (reach / length * _steps).round().clamp(1, _steps);
    final left = <Offset>[], right = <Offset>[];
    for (var j = 0; j <= last; j++) {
      final u = j / _steps;
      final tip =
          reach >= length ? 1.0 : ((reach - u * length) / 6).clamp(0.0, 1.0);
      final half = wide / 2 * width(u) * tip;
      final h = _headings[j];
      final across = Offset(-math.sin(h), math.cos(h)) * half;
      left.add(_points[j] + across + shift);
      right.add(_points[j] - across + shift);
    }
    return [...left, ...right.reversed];
  }

  /// Where the beads sit, grown as far as [reach]: at the heart of a curl
  /// once it has wound all the way in.
  List<Offset> beads(double reach) => [
        if (beadAtStart) _points.first,
        if (reach >= length) _points.last,
      ];
}

/// What is etched on [glass] at [rect], picked by [seed] (see
/// [GlassEtching]).
void paintEtching(Canvas canvas, Rect rect, Glass glass, int seed) {
  if (glass.etch <= 0) return;
  final etching = GlassEtching.of(rect.size, glass.etch, seed);
  if (etching.marks.isEmpty) return;
  canvas
    ..save()
    ..translate(rect.left, rect.top);
  for (final m in etching.marks) {
    final c = m.lit ? glass.glint : glass.groove;
    canvas.drawPath(
        m.path, Paint()..color = c.withValues(alpha: c.a * m.depth));
  }
  canvas.restore();
}

/// A card's decoration: [plain] without glass; on glass, glass that keeps
/// its accent — the stripe down the left as a capsule inside the edge, or
/// the outline all round — and room for it. [seed]: what the card shows,
/// so that on matte glass each has spirals of its own.
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
