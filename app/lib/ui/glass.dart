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
    this.scuffs = 0,
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
  /// wallpaper and the glass, and the faint [scuffs] on the glass (0: none,
  /// 1: as drawn).
  final double grain;
  final double scuffs;

  bool get scuffed => grain > 0 || scuffs > 0;

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
      scuffs: scuffs * t,
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
    scuffs: 1,
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
    scuffs: 0.4,
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

  @override
  Glass copyWith({bool? on}) => Glass(
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
        scuffs: scuffs,
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
/// [outline] all round, marks it as a plain card's border did.
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
      other.inset == inset;

  @override
  int get hashCode => Object.hash(glass, fill, gradient, radius, accent,
      accentWidth, outline, shadows, sheen, rimmed, highlight, inset);
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
    // Matte glass: frosted and lightly scuffed, the texture moving with it.
    if (g.scuffed && d.sheen) {
      canvas
        ..save()
        ..clipRRect(shape);
      paintTexture(canvas, rect, GlassTexture.grain, rect.topLeft, g.grain);
      paintTexture(canvas, rect, GlassTexture.scuffs, rect.topLeft, g.scuffs);
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

/// The tiles of matte glass's texture, drawn once: [grain], fine specks
/// of light and shade as frosting has (laid at half a logical pixel each:
/// a device pixel on most screens), and [scuffs], faint scratches running
/// mostly one way. Null where the renderer can't draw them.
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

  static final ui.Image? scuffs = _draw(256, (canvas, rnd) {
    final paint = Paint()
      ..strokeWidth = 0.6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 70; i++) {
      final from = Offset(rnd.nextDouble() * 256, rnd.nextDouble() * 256);
      final angle = -0.45 + (rnd.nextDouble() - 0.5) * 0.3;
      final length = 6 + rnd.nextDouble() * 34;
      final to = from + Offset(math.cos(angle), math.sin(angle)) * length;
      paint.color = rnd.nextInt(3) == 0
          ? const Color(0x0F000000)
          : Color.fromRGBO(255, 255, 255, 0.08 + rnd.nextDouble() * 0.08);
      // Across the tile's edge too, so the tiles meet without a seam.
      for (final dx in const [-256.0, 0.0, 256.0]) {
        for (final dy in const [-256.0, 0.0, 256.0]) {
          final shift = Offset(dx, dy);
          canvas.drawLine(from + shift, to + shift, paint);
        }
      }
    }
  });

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

/// A card's decoration: [plain] without glass; on glass, glass that keeps
/// its accent — the stripe down the left as a capsule inside the edge, or
/// the outline all round — and room for it.
Decoration cardDecoration(BuildContext context, BoxDecoration plain) {
  final glass = Glass.of(context);
  if (!glass.on) return plain;
  final border = plain.border;
  final inset =
      border?.dimensions.resolve(TextDirection.ltr) ?? EdgeInsets.zero;
  if (border is Border && !border.isUniform && border.left.width > 0) {
    return GlassDecoration(glass,
        accent: Glass.tone(border.left.color),
        accentWidth: 4,
        inset: inset.copyWith(left: 18));
  }
  return GlassDecoration(glass,
      outline: border is Border ? border.top : null, inset: inset);
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
