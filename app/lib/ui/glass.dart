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
    this.wear = 0,
    this.scratch = Colors.transparent,
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

  /// Matte glass: how worn it is (0: as new, 1: scratched deep every which
  /// way, and cracked; see [GlassWear]). A scratch is a groove: its wall
  /// towards the light, at the top left, in the shade of [scratch], the far
  /// one catching the light, [glint] — both as at the deepest.
  final double wear;
  final Color scratch;
  final Color glint;

  bool get scuffed => grain > 0 || wear > 0;

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
      wear: wear * t,
      scratch: scratch,
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
    scratch: Color(0x660F1426),
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
    scratch: Color(0x99000000),
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

  /// [wear]: matte glass as worn as that.
  @override
  Glass copyWith({bool? on, double? wear}) => Glass(
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
        wear: (wear ?? this.wear).clamp(0.0, 1.0),
        scratch: scratch,
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
/// glass, [seed] picks this piece's own scratches and cracks (by default,
/// its size's).
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
    // Matte glass: frosted and worn, the texture moving with it.
    if (g.scuffed && d.sheen) {
      canvas
        ..save()
        ..clipRRect(shape);
      paintTexture(canvas, rect, GlassTexture.grain, rect.topLeft, g.grain);
      paintWear(canvas, rect, g,
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

/// One kind of mark wear leaves: [path], in the shade of a groove's wall
/// or, [lit], the light off the other one, at [depth] (0 to 1); filled, or
/// a line [width] wide.
typedef WearMark = ({Path path, bool lit, double depth, double? width});

/// The marks wear leaves on a piece of matte glass, [GlassWear.of] its size
/// and wear (0 to 1), to draw in order. Scratches: a few short ones running
/// mostly one way, as from wiping; with wear, more of them, longer, deeper,
/// bent and running every which way. Past half way, cracks: from the edge —
/// more often near a corner, with a chip out where they start — growing
/// inwards and branching. A piece's seed keeps its marks as the wear
/// changes: a scratch only appears, deepens and turns; a crack only grows.
@immutable
class GlassWear {
  const GlassWear._(this.marks);

  final List<WearMark> marks;

  /// Scratches at full wear, per square logical pixel.
  static const _density = 1 / 700;

  /// Groove depths, shallow to deep: one path each, to draw at once.
  static const _depths = 3;

  static final _made = <(int, int, int, int), GlassWear>{};

  static GlassWear of(Size size, double wear, int seed) {
    final key = (
      seed,
      size.width.round(),
      size.height.round(),
      (wear.clamp(0.0, 1.0) * 100).round(),
    );
    if (_made[key] case final made?) return made;
    if (_made.length >= 128) _made.clear();
    return _made[key] = _make(size, key.$4 / 100, seed);
  }

  static GlassWear _make(Size size, double wear, int seed) {
    final w = size.width, h = size.height;
    if (wear <= 0 || w <= 0 || h <= 0) return const GlassWear._([]);
    final shade = [for (var i = 0; i < _depths; i++) Path()];
    final lit = [for (var i = 0; i < _depths; i++) Path()];

    // Every scratch is drawn up as at full wear, so each keeps its place;
    // the wear says how many show, and how they lie.
    final rnd = math.Random(seed);
    final most = (w * h * _density).clamp(4, 160).round();
    final shown = (most * wear).round();
    for (var i = 0; i < most; i++) {
      final from = Offset(rnd.nextDouble() * w, rnd.nextDouble() * h);
      final turn = rnd.nextDouble() * 2 - 1;
      final reach = rnd.nextDouble();
      final bend = rnd.nextDouble() * 2 - 1;
      final deep = rnd.nextDouble();
      if (i >= shown) continue;
      final angle = -0.45 + turn * (0.12 + 1.45 * wear);
      final length = 6 + reach * reach * (24 + 80 * wear);
      final along = Offset(math.cos(angle), math.sin(angle));
      final to = from + along * length;
      final mid = (from + to) / 2 +
          Offset(-along.dy, along.dx) * (bend * wear * 0.1 * length);
      final depth = (0.25 + 0.75 * deep) * (0.3 + 0.7 * wear);
      final k = math.min(_depths - 1, (depth * _depths).floor());
      final width = 0.45 + 1.1 * depth;
      // The wall towards the light (top left) in shade, the far one lit.
      final o = const Offset(1, 1) * (0.25 + 0.45 * depth);
      _sliver(shade[k], from - o, mid - o, to - o, width);
      _sliver(lit[k], from + o, mid + o, to + o, width * 0.8);
    }

    final marks = <WearMark>[
      for (var k = 0; k < _depths; k++)
        (path: shade[k], lit: false, depth: _strength(k), width: null),
      for (var k = 0; k < _depths; k++)
        (path: lit[k], lit: true, depth: _strength(k), width: null),
    ];

    final grow = (wear - 0.5) * 2;
    if (grow > 0) marks.addAll(_cracks(w, h, grow, seed));
    return GlassWear._(marks);
  }

  /// How strongly a groove of depth [k] shows: the deep ones most, but
  /// mostly they are wider and their walls further apart — and none as
  /// sharply as a crack, which shows the [Glass.scratch] and [Glass.glint]
  /// in full.
  static double _strength(int k) => 0.35 + 0.4 * (k + 1) / _depths;

  /// A scratch from [a] to [b] bending through [mid]: a sliver [width]
  /// across the middle, coming to a point at either end.
  static void _sliver(Path path, Offset a, Offset mid, Offset b, double width) {
    final d = b - a;
    if (d.distance == 0) return;
    final n = Offset(-d.dy, d.dx) / d.distance * width;
    path
      ..moveTo(a.dx, a.dy)
      ..quadraticBezierTo(mid.dx + n.dx, mid.dy + n.dy, b.dx, b.dy)
      ..quadraticBezierTo(mid.dx - n.dx, mid.dy - n.dy, a.dx, a.dy)
      ..close();
  }

  /// Cracks in a [w] by [h] piece, [grow]n that far (0 to 1) of their
  /// length: one, and one more for each 60 000 square pixels, up to four,
  /// each later one starting later. Each is a star of two or three runs
  /// from where the glass was struck, aimed roughly at the middle.
  static List<WearMark> _cracks(double w, double h, double grow, int seed) {
    final rnd = math.Random(seed ^ 0x2545F491);
    final count = (1 + w * h / 60000).floor().clamp(1, 4);
    final lines = [for (var i = 0; i < 3; i++) Path()];
    final glints = [for (var i = 0; i < 3; i++) Path()];
    final chips = Path();
    for (var c = 0; c < count; c++) {
      // Where it starts: on an edge, nearer a corner more often than not.
      final side = rnd.nextInt(4);
      final t = rnd.nextDouble();
      final at = t < 0.5 ? 2 * t * t : 1 - 2 * (1 - t) * (1 - t);
      final origin = switch (side) {
        0 => Offset(at * w, 0),
        1 => Offset(w, at * h),
        2 => Offset((1 - at) * w, h),
        _ => Offset(0, (1 - at) * h),
      };
      final middle = Offset(w / 2, h / 2) - origin;
      final aim = math.atan2(middle.dy, middle.dx) + (rnd.nextDouble() - 0.5);
      final length = (0.35 + 0.45 * rnd.nextDouble()) * (w + h) / 2;
      final segments = <(Offset, Offset, double, int)>[];
      final runs = 2 + rnd.nextInt(2);
      for (var r = 0; r < runs; r++) {
        final spread = (r - (runs - 1) / 2) * (0.35 + 0.3 * rnd.nextDouble());
        final reach = r == runs ~/ 2 ? 1.0 : 0.45 + 0.4 * rnd.nextDouble();
        _crack(rnd, segments, origin, aim + spread, length * reach, 0, 0);
      }
      final chip = [
        for (var i = 0; i < 6; i++)
          (
            i * math.pi / 3 + rnd.nextDouble() * 0.6,
            0.6 + 0.4 * rnd.nextDouble()
          )
      ];
      final size = 2.5 + 3 * rnd.nextDouble();

      final starts = c / count * 0.6;
      final g = (grow - starts) / (1 - starts);
      if (g <= 0) continue;
      final reach = g * length;
      for (final (a, b, end, level) in segments) {
        final begin = end - (b - a).distance;
        if (begin >= reach) continue;
        final stop = end <= reach
            ? b
            : Offset.lerp(a, b, (reach - begin) / (end - begin))!;
        lines[level]
          ..moveTo(a.dx - 0.5, a.dy - 0.5)
          ..lineTo(stop.dx - 0.5, stop.dy - 0.5);
        glints[level]
          ..moveTo(a.dx + 0.5, a.dy + 0.5)
          ..lineTo(stop.dx + 0.5, stop.dy + 0.5);
      }
      chips.addPolygon([
        for (final (angle, r) in chip)
          origin + Offset(math.cos(angle), math.sin(angle)) * (size * r),
      ], true);
    }
    return [
      for (var l = 0; l < 3; l++) ...[
        (
          path: lines[l],
          lit: false,
          depth: 1.0 - 0.15 * l,
          width: 1.3 - 0.25 * l
        ),
        (
          path: glints[l],
          lit: true,
          depth: 1.0 - 0.15 * l,
          width: 0.9 - 0.2 * l
        ),
      ],
      (path: chips, lit: false, depth: 0.4, width: null),
      (path: chips, lit: true, depth: 0.8, width: 0.8),
    ];
  }

  /// One run of a crack into [into] — (from, to, how far along at the end,
  /// branch level) — from [from] at [angle] for [length], from [distance]
  /// along: as glass cracks, straight stretches with a sharp turn now and
  /// then, and a branch off to one side, two levels deep.
  static void _crack(math.Random rnd, List<(Offset, Offset, double, int)> into,
      Offset from, double angle, double length, double distance, int level) {
    var at = from, run = 0.0;
    while (run < length) {
      final step = 10 + rnd.nextDouble() * 16;
      final kink = rnd.nextDouble() < 0.18;
      angle += (rnd.nextDouble() - 0.5) * (kink ? 0.9 : 0.25);
      final next = at + Offset(math.cos(angle), math.sin(angle)) * step;
      run += step;
      into.add((at, next, distance + run, level));
      if (level < 2 && rnd.nextDouble() < 0.25) {
        final side = rnd.nextBool() ? 1 : -1;
        _crack(
            rnd,
            into,
            next,
            angle + side * (0.35 + rnd.nextDouble() * 0.5),
            (length - run) * (0.3 + rnd.nextDouble() * 0.35),
            distance + run,
            level + 1);
      }
      at = next;
    }
  }
}

/// [glass]'s wear on the piece of it at [rect], marked by [seed] (see
/// [GlassWear]).
void paintWear(Canvas canvas, Rect rect, Glass glass, int seed) {
  if (glass.wear <= 0) return;
  final wear = GlassWear.of(rect.size, glass.wear, seed);
  if (wear.marks.isEmpty) return;
  canvas
    ..save()
    ..translate(rect.left, rect.top);
  for (final m in wear.marks) {
    final c = m.lit ? glass.glint : glass.scratch;
    final paint = Paint()..color = c.withValues(alpha: c.a * m.depth);
    if (m.width case final width?) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
    }
    canvas.drawPath(m.path, paint);
  }
  canvas.restore();
}

/// A card's decoration: [plain] without glass; on glass, glass that keeps
/// its accent — the stripe down the left as a capsule inside the edge, or
/// the outline all round — and room for it. [seed]: what the card shows,
/// so that on matte glass each has scratches of its own.
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
