import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/updates.dart';
import '../state/updater.dart';

/// Checks for a new release when the app opens and when it comes back, and
/// keeps the update banner over whichever screen is open.
class UpdateWatcher extends StatefulWidget {
  const UpdateWatcher({super.key, required this.child});
  final Widget child;

  @override
  State<UpdateWatcher> createState() => _UpdateWatcherState();
}

class _UpdateWatcherState extends State<UpdateWatcher> {
  late final Updater _updater = context.read<Updater>();
  late final AppLifecycleListener _life;
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    _updater.addListener(_sync);
    _life = AppLifecycleListener(onResume: () => unawaited(_updater.check()));
    // Once the first screen is up: the check notifies, and the banner needs
    // a Scaffold to sit on.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => unawaited(_updater.check()));
  }

  @override
  void dispose() {
    _updater.removeListener(_sync);
    _life.dispose();
    super.dispose();
  }

  void _sync() {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    if (_updater.showBanner && !_shown) {
      _shown = true;
      final closed = messenger
          .showMaterialBanner(MaterialBanner(
            leading: const Icon(Icons.system_update),
            content: _BannerText(_updater),
            actions: [_BannerActions(_updater)],
          ))
          .closed;
      unawaited(closed.then((_) => _shown = false));
    } else if (!_updater.showBanner && _shown) {
      messenger.hideCurrentMaterialBanner();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _BannerText extends StatelessWidget {
  const _BannerText(this.u);
  final Updater u;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: u,
        builder: (context, _) {
          final r = u.release;
          if (r == null) return const SizedBox.shrink();
          final error = u.error;
          return switch (u.stage) {
            UpdateStage.downloading => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Загрузка версии ${r.version}… '
                      '${(u.progress * 100).round()} %'),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: u.progress,
                    // The theme's track is coral-ish; grey reads as «to go».
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withValues(alpha: 0.2),
                  ),
                ],
              ),
            UpdateStage.ready => Text(error == null
                ? 'Версия ${r.version} загружена — осталось установить'
                : 'Не удалось открыть установщик: $error'),
            UpdateStage.failed =>
              Text('Не удалось загрузить обновление: ${error ?? ''}'),
            _ => Text('Доступна версия ${r.version} · ${megabytes(r.size)}'),
          };
        },
      );
}

class _BannerActions extends StatelessWidget {
  const _BannerActions(this.u);
  final Updater u;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: u,
        builder: (context, _) {
          final later =
              TextButton(onPressed: u.hideBanner, child: const Text('Позже'));
          return Wrap(
              spacing: 8,
              children: switch (u.stage) {
                UpdateStage.downloading => [
                    TextButton(
                        onPressed: u.hideBanner, child: const Text('Скрыть')),
                  ],
                UpdateStage.ready => [
                    later,
                    FilledButton(
                        onPressed: () => unawaited(u.install()),
                        child: const Text('Установить')),
                  ],
                UpdateStage.failed => [
                    later,
                    FilledButton(
                        onPressed: () => unawaited(u.download()),
                        child: const Text('Повторить')),
                  ],
                _ => [
                    later,
                    FilledButton(
                        onPressed: () => unawaited(u.download()),
                        child: const Text('Обновить')),
                  ],
              });
        },
      );
}
