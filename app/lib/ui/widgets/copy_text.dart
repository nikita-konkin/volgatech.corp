import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Puts [text] on the clipboard and says so at the bottom of the screen.
Future<void> copyText(BuildContext context, String text,
    {String message = 'Скопировано'}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  await Clipboard.setData(ClipboardData(text: text));
  unawaited(HapticFeedback.selectionClick());
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
}

/// [child], whose [text] is copied on a long press (or a right click, with a
/// mouse).
class CopyOnHold extends StatelessWidget {
  const CopyOnHold(
      {super.key,
      required this.text,
      this.message = 'Название скопировано',
      required this.child});

  final String text;
  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = text.trim();
    if (t.isEmpty) return child;
    void copy() => unawaited(copyText(context, t, message: message));
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: copy,
      onSecondaryTap: copy,
      child: child,
    );
  }
}
