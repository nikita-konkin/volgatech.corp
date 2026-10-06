import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// «Liquid Glass», the browser's optional look: panels you half see
/// through, on a soft coloured wallpaper. What it needs beyond ThemeData;
/// [Glass.off] (the default) changes nothing.
@immutable
class Glass extends ThemeExtension<Glass> {
  const Glass({
    required this.on,
    this.wallpaper = const [],
    this.glows = const [],
    this.panel = Colors.transparent,
    this.rim = Colors.transparent,
  });

  static const off = Glass(on: false);

  final bool on;

  /// The wallpaper, top left to bottom right of the window.
  final List<Color> wallpaper;

  /// Soft light over it: top right, then bottom left.
  final List<Color> glows;

  /// The menu and drawer: tinted glass over the wallpaper.
  final Color panel;

  /// The bright edge of a glass panel.
  final Color rim;

  static Glass of(BuildContext context) =>
      Theme.of(context).extension<Glass>() ?? off;

  static const light = Glass(
    on: true,
    wallpaper: [Color(0xFFD8E6FB), Color(0xFFEDE4FA), Color(0xFFFCE6DE)],
    glows: [Color(0x2E34517B), Color(0x29EE6C6C)],
    panel: Color(0x9EFFFFFF),
    rim: Color(0xB3FFFFFF),
  );

  static const dark = Glass(
    on: true,
    wallpaper: [Color(0xFF0F1B2E), Color(0xFF1B1530), Color(0xFF2A1720)],
    glows: [Color(0x247FA8E0), Color(0x1AEE6C6C)],
    panel: Color(0xA620242E),
    rim: Color(0x33FFFFFF),
  );

  /// Card and tile fill: the text on it must read on any part of the
  /// wallpaper (test/glass_test.dart).
  static const lightSurface = Color(0xA8FFFFFF);
  static const darkSurface = Color(0xA320242E);

  /// The top bar: Brand blue the wallpaper tints a little.
  static const lightBar = Color(0xD134517B);
  static const darkBar = Color(0xC7223A57);

  @override
  Glass copyWith({bool? on}) => Glass(
      on: on ?? this.on,
      wallpaper: wallpaper,
      glows: glows,
      panel: panel,
      rim: rim);

  @override
  Glass lerp(Glass? other, double t) => t < 0.5 || other == null ? this : other;
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

/// Every colour the wallpaper of [glass] shows somewhere: its stops, and
/// each with the glows at full strength over it.
List<Color> wallpaperColors(Glass glass) => [
      for (final c in glass.wallpaper) ...[
        c,
        for (final g in glass.glows) Color.alphaBlend(g, c),
      ],
    ];

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
    if (_glass.on && _glass.wallpaper.length > 1) {
      final at = localToGlobal(Offset.zero);
      final window = (offset - at) & _window;
      canvas.drawRect(
          box,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _glass.wallpaper,
            ).createShader(window));
      final spots = [const Alignment(0.8, -0.85), const Alignment(-0.8, 0.85)];
      for (var i = 0; i < _glass.glows.length && i < spots.length; i++) {
        canvas.drawRect(
            box,
            Paint()
              ..shader = RadialGradient(
                center: spots[i],
                radius: 0.75,
                colors: [_glass.glows[i], _glass.glows[i].withValues(alpha: 0)],
              ).createShader(window));
      }
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

/// A glass panel ([Glass.panel]) that blurs what is under it — only for
/// one that comes over the page, the drawer: on a plain wallpaper a blur
/// would cost the browser and show nothing.
class FrostedPanel extends StatelessWidget {
  const FrostedPanel({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final glass = Glass.of(context);
    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: glass.panel,
          border: BorderDirectional(end: BorderSide(color: glass.rim)),
        ),
        child: child,
      ),
    );
  }
}

/// Shadows under cards: none on glass, where they'd show through as a
/// grey haze.
List<BoxShadow> cardShadow(BuildContext context, List<BoxShadow> shadows) =>
    Glass.of(context).on ? const [] : shadows;
