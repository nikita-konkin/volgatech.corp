import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'insets.dart' show insetsFromQuery;

ValueNotifier<EdgeInsets>? _insets;

/// Safari's `env(safe-area-inset-*)`, read off `#safe-area-probe` in
/// index.html, and read again when the window turns or resizes.
ValueListenable<EdgeInsets> browserInsets() {
  final existing = _insets;
  if (existing != null) return existing;
  final insets = _insets = ValueNotifier(_read());
  void update() => insets.value = _read();
  final onChange = ((web.Event _) {
    update();
    // Safari settles the new insets a moment after turning.
    Timer(const Duration(milliseconds: 350), update);
  }).toJS;
  web.window.addEventListener('resize', onChange);
  web.window.addEventListener('orientationchange', onChange);
  web.window.visualViewport?.addEventListener('resize', onChange);
  return insets;
}

EdgeInsets _read() {
  final tried = insetsFromQuery(Uri.base.queryParameters['insets']);
  if (tried != null) return tried;
  final probe = web.document.getElementById('safe-area-probe');
  if (probe == null) return EdgeInsets.zero;
  final style = web.window.getComputedStyle(probe);
  double px(String value) =>
      double.tryParse(value.replaceAll('px', '').trim()) ?? 0;
  return EdgeInsets.fromLTRB(px(style.paddingLeft), px(style.paddingTop),
      px(style.paddingRight), px(style.paddingBottom));
}
