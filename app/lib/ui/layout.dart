import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// From this width the menu stays open beside the screens (home_shell.dart):
/// a computer, or a tablet on its side.
const kWideLayout = 1000.0;

/// Text and cards get no wider than this. On a wide screen the rest stays
/// empty on both sides instead of stretching every line across it.
const kReadableWidth = 760.0;

/// Stands in for [desktopBrowser] in tests, which never run in a browser.
@visibleForTesting
bool? debugDesktopBrowser;

/// A browser on a computer: a mouse and a keyboard rather than a finger, so
/// pull-to-refresh is out of reach and screens offer a button instead.
bool get desktopBrowser =>
    debugDesktopBrowser ??
    (kIsWeb &&
        switch (defaultTargetPlatform) {
          TargetPlatform.macOS ||
          TargetPlatform.windows ||
          TargetPlatform.linux =>
            true,
          _ => false,
        });

/// [base] widened on both sides so that what it pads stays at most [max]
/// wide, centred, however wide the screen. Lists take it as their padding,
/// so they still scroll from anywhere across the screen.
EdgeInsets readable(BuildContext context, EdgeInsets base,
    {double max = kReadableWidth}) {
  final extra = math.max(0.0, (MediaQuery.sizeOf(context).width - max) / 2);
  return base.copyWith(left: base.left + extra, right: base.right + extra);
}

/// [child] as wide as the screen up to [max], centred: for the parts of a
/// screen that don't scroll, such as bars and buttons.
class ReadableWidth extends StatelessWidget {
  const ReadableWidth(
      {super.key, required this.child, this.max = kReadableWidth});

  final Widget child;
  final double max;

  @override
  Widget build(BuildContext context) => Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: max),
          child: SizedBox(width: double.infinity, child: child),
        ),
      );
}

/// ← and → call [onPrevious] and [onNext] while the screen has the keyboard,
/// as the arrows on it do.
class ArrowKeys extends StatelessWidget {
  const ArrowKeys(
      {super.key,
      required this.onPrevious,
      required this.onNext,
      this.onHome,
      required this.child});

  final VoidCallback onPrevious;
  final VoidCallback onNext;

  /// Home: back to today.
  final VoidCallback? onHome;
  final Widget child;

  @override
  Widget build(BuildContext context) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowLeft): onPrevious,
          const SingleActivator(LogicalKeyboardKey.arrowRight): onNext,
          if (onHome case final home?)
            const SingleActivator(LogicalKeyboardKey.home): home,
        },
        child: Focus(autofocus: true, child: child),
      );
}

/// Back to today, shown once the screen has moved away from it.
class TodayButton extends StatelessWidget {
  const TodayButton({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Сегодня',
        icon: const Icon(Icons.today),
        onPressed: onPressed,
      );
}

/// A button that loads the screen again, for a computer: pulling a list
/// down to refresh it takes a finger.
class RefreshButton extends StatelessWidget {
  const RefreshButton({super.key, required this.onPressed});

  /// Null while loading.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Обновить',
        icon: const Icon(Icons.refresh),
        onPressed: onPressed,
      );
}
