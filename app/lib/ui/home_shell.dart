import 'package:flutter/material.dart';

import 'app_drawer.dart';
import 'exams_page.dart';
import 'foreign_memo_page.dart';
import 'glass.dart';
import 'layout.dart';
import 'profile_page.dart';
import 'schedule_page.dart';
import 'settings_page.dart';

/// The screens the menu opens.
enum Section { schedule, exams, foreign, profile, settings }

Widget sectionPage(Section section) => switch (section) {
      Section.schedule => const SchedulePage(),
      Section.exams => const ExamsPage(),
      Section.foreign => const ForeignMemoPage(),
      Section.profile => const ProfilePage(),
      Section.settings => const SettingsPage(),
    };

/// The signed-in app. On a phone: the schedule, with the menu in a drawer
/// that opens the other screens over it. From [kWideLayout] on: the menu
/// stays open on the left and opens each screen beside it, and every screen
/// is kept as it was left.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= kWideLayout
          ? const _WideShell()
          : const SchedulePage();
}

/// Present above the screens when the menu is open beside them: the menu
/// then switches screens instead of pushing them, and the screens show no
/// menu button.
class NavShell extends InheritedWidget {
  const NavShell(
      {super.key,
      required this.section,
      required this.select,
      required super.child});

  final Section section;
  final void Function(Section) select;

  static NavShell? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<NavShell>();

  @override
  bool updateShouldNotify(NavShell oldWidget) => oldWidget.section != section;
}

class _WideShell extends StatefulWidget {
  const _WideShell();

  @override
  State<_WideShell> createState() => _WideShellState();
}

class _WideShellState extends State<_WideShell> {
  static const _menuWidth = 300.0;

  Section _section = Section.schedule;
  final _opened = {Section.schedule};
  final _navigators = {
    for (final s in Section.values) s: GlobalKey<NavigatorState>(),
  };
  // Each screen's keyboard focus, back where it was when it is reopened.
  final _focus = {
    for (final s in Section.values)
      s: FocusScopeNode(debugLabel: 'Section ${s.name}'),
  };

  @override
  void dispose() {
    for (final node in _focus.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _select(Section section) {
    if (section == _section) {
      // Back to the screen itself, from whatever it opened.
      _navigators[section]!.currentState?.popUntil((r) => r.isFirst);
      return;
    }
    setState(() {
      _section = section;
      _opened.add(section);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _section == section) _focus[section]!.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final glass = Glass.of(context);
    return NavShell(
      section: _section,
      select: _select,
      child: Row(
        children: [
          SizedBox(
            width: _menuWidth,
            child: Material(
              // On glass: a tinted pane over the page's wallpaper.
              color: glass.on
                  ? glass.panel
                  : Theme.of(context).colorScheme.surfaceContainerLow,
              child: const NavMenu(),
            ),
          ),
          VerticalDivider(
              width: 1, thickness: 1, color: glass.on ? glass.rim : null),
          Expanded(
            // The screens measure themselves against this side, not the
            // whole window.
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  size: Size(size.width - _menuWidth - 1, size.height)),
              child: IndexedStack(
                index: _section.index,
                children: [
                  for (final s in Section.values)
                    if (_opened.contains(s))
                      _Pane(
                          section: s,
                          active: s == _section,
                          navigator: _navigators[s]!,
                          focus: _focus[s]!)
                    else
                      const SizedBox.shrink(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One screen, with its own history: what it opens stays beside the menu,
/// and the back button closes that first. A hidden one neither animates nor
/// takes the keyboard.
class _Pane extends StatelessWidget {
  const _Pane(
      {required this.section,
      required this.active,
      required this.navigator,
      required this.focus});

  final Section section;
  final bool active;
  final GlobalKey<NavigatorState> navigator;
  final FocusScopeNode focus;

  @override
  Widget build(BuildContext context) => ExcludeFocus(
        excluding: !active,
        child: TickerMode(
          enabled: active,
          child: NavigatorPopHandler<Object?>(
            enabled: active,
            onPopWithResult: (_) => navigator.currentState?.maybePop(),
            child: FocusScope(
              node: focus,
              child: HeroControllerScope.none(
                child: Navigator(
                  key: navigator,
                  onGenerateRoute: (_) => MaterialPageRoute<void>(
                      builder: (_) => sectionPage(section)),
                ),
              ),
            ),
          ),
        ),
      );
}
