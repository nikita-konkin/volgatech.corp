import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Tappable footer for the Settings screen. Seven quick taps on the version
/// line reveal the Радиотехнический факультет crest — a small nod to the RTF.
class EasterEggFooter extends StatefulWidget {
  const EasterEggFooter({super.key});

  @override
  State<EasterEggFooter> createState() => _EasterEggFooterState();
}

class _EasterEggFooterState extends State<EasterEggFooter> {
  static const _needed = 7;
  // Read from the installed package, so it always matches pubspec's version.
  static final Future<PackageInfo> _info = PackageInfo.fromPlatform();
  int _taps = 0;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  void _onTap() {
    final now = DateTime.now();
    // Reset if the taps aren't reasonably quick (avoids accidental triggers).
    if (now.difference(_last) > const Duration(seconds: 2)) _taps = 0;
    _last = now;
    _taps++;
    final left = _needed - _taps;
    final messenger = ScaffoldMessenger.of(context);
    if (_taps >= _needed) {
      _taps = 0;
      messenger.clearSnackBars();
      showRtfEasterEgg(context);
    } else if (left <= 3) {
      messenger.clearSnackBars();
      messenger.showSnackBar(SnackBar(
        duration: const Duration(milliseconds: 700),
        content: Text('Ещё $left…'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 24),
      child: Center(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onTap,
          child: FutureBuilder<PackageInfo>(
            future: _info,
            builder: (context, snap) => Text(
                [
                  'Волгатех.Коллектив',
                  if (snap.data case final info?) 'v${info.version}',
                ].join(' · '),
                style: TextStyle(color: muted, fontSize: 13)),
          ),
        ),
      ),
    );
  }
}

/// Shows the faculty crest with a gentle scale/rotate reveal.
void showRtfEasterEgg(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'РТФ',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 450),
    pageBuilder: (_, __, ___) => const SizedBox.shrink(),
    transitionBuilder: (context, anim, __, child) {
      final curved = Curves.easeOutBack.transform(anim.value.clamp(0.0, 1.0));
      return Opacity(
        opacity: anim.value.clamp(0.0, 1.0),
        child: Center(
          child: Transform.rotate(
            angle: (1 - anim.value) * 0.5,
            child: Transform.scale(
              scale: 0.6 + 0.4 * curved,
              child: const _RtfCard(),
            ),
          ),
        ),
      );
    },
  );
}

class _RtfCard extends StatelessWidget {
  const _RtfCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset('assets/easter/rtf.webp',
                  width: 240, height: 240, fit: BoxFit.cover),
            ),
            const SizedBox(height: 16),
            const Text('Радиотехнический факультет',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            const Text('РТФ · ВолгаТех',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
