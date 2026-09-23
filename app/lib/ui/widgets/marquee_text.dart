import 'package:flutter/material.dart';

/// Single-line text that **auto-scrolls when it doesn't fit**. If [text] fits
/// the available width it renders as a plain line; if it overflows it gently
/// ping-pongs left↔right so the whole label can be read. No package, and it
/// stays idle (no animation) whenever the text fits — cheap on old devices.
class MarqueeText extends StatefulWidget {
  const MarqueeText(this.text, {this.style, super.key});
  final String text;
  final TextStyle? style;

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> {
  final _sc = ScrollController();
  bool _running = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStart());
  }

  @override
  void didUpdateWidget(covariant MarqueeText old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStart());
    }
  }

  Future<void> _maybeStart() async {
    if (_running || !mounted || !_sc.hasClients) return;
    if (_sc.position.maxScrollExtent <= 0) return; // fits — nothing to scroll
    _running = true;
    while (mounted && _sc.hasClients && _sc.position.maxScrollExtent > 0) {
      final extent = _sc.position.maxScrollExtent;
      final ms = (extent / 45 * 1000).clamp(1500, 12000).toInt(); // ~45 px/s
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (!mounted || !_sc.hasClients) break;
      await _sc.animateTo(extent,
          duration: Duration(milliseconds: ms), curve: Curves.linear);
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (!mounted || !_sc.hasClients) break;
      await _sc.animateTo(0,
          duration: Duration(milliseconds: ms), curve: Curves.linear);
    }
    _running = false;
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Own layer: while the text scrolls only this line repaints, not the
    // whole card / list around it.
    return RepaintBoundary(
      child: SingleChildScrollView(
        controller: _sc,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Text(widget.text,
            maxLines: 1, softWrap: false, style: widget.style),
      ),
    );
  }
}
