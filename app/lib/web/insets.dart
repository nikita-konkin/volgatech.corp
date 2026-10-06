import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../ui/glass.dart';
import 'insets_stub.dart' if (dart.library.js_interop) 'insets_web.dart'
    as impl;

/// In a browser, the iPhone's safe area as Safari reports it — the notch or
/// Dynamic Island and the home indicator — given to the app the way a phone
/// gives it. Flutter's web engine leaves it at zero, so without this the app
/// would sit under the clock and the home indicator. Elsewhere: [child].
class BrowserInsets extends StatelessWidget {
  const BrowserInsets({super.key, required this.child, this.insets});
  final Widget child;

  /// In place of Safari's: for tests.
  final ValueListenable<EdgeInsets>? insets;

  @override
  Widget build(BuildContext context) {
    final source = insets ?? (kIsWeb ? impl.browserInsets() : null);
    if (source == null) return child;
    return ValueListenableBuilder<EdgeInsets>(
      valueListenable: source,
      builder: (context, insets, child) {
        final data = withBrowserInsets(MediaQuery.of(context), insets);
        // Turned sideways, the notch or Dynamic Island takes a side: the app
        // keeps clear of both sides, as Android does with a cutout, rather
        // than every screen padding its content for it.
        return Wallpaper(
          solid: Theme.of(context).scaffoldBackgroundColor,
          child: Padding(
            padding: EdgeInsets.only(
                left: data.padding.left, right: data.padding.right),
            child: MediaQuery(data: withoutSides(data), child: child!),
          ),
        );
      },
      child: child,
    );
  }
}

/// [data] with [insets] as its view padding; the padding loses at the bottom
/// what the keyboard covers, as on a phone.
MediaQueryData withBrowserInsets(MediaQueryData data, EdgeInsets insets) {
  final view = EdgeInsets.fromLTRB(
    math.max(data.viewPadding.left, insets.left),
    math.max(data.viewPadding.top, insets.top),
    math.max(data.viewPadding.right, insets.right),
    math.max(data.viewPadding.bottom, insets.bottom),
  );
  return data.copyWith(
    viewPadding: view,
    padding: view.copyWith(
        bottom: math.max(0.0, view.bottom - data.viewInsets.bottom)),
  );
}

/// [data] for an app laid out between its left and right padding.
MediaQueryData withoutSides(MediaQueryData data) =>
    data.removePadding(removeLeft: true, removeRight: true).copyWith(
        size: Size(math.max(0.0, data.size.width - data.padding.horizontal),
            data.size.height));

/// `?insets=59,0,34,0` (top, right, bottom, left): an iPhone's insets, to
/// try the layout in a desktop browser. Null when absent or malformed.
EdgeInsets? insetsFromQuery(String? value) {
  if (value == null) return null;
  final parts = value.split(',').map(double.tryParse).toList();
  if (parts.length != 4 || parts.any((p) => p == null || p < 0)) return null;
  return EdgeInsets.fromLTRB(parts[3]!, parts[0]!, parts[1]!, parts[2]!);
}
