import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_lock.dart';
import '../state/theme_controller.dart';
import '../state/updater.dart';
import 'easter_egg.dart';
import 'layout.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _toggleLock(BuildContext context, bool value) async {
    final lock = context.read<AppLock>();
    final messenger = ScaffoldMessenger.of(context);
    if (value) {
      final ok = await lock.enable();
      if (!ok) {
        messenger.showSnackBar(const SnackBar(
          content: Text(
              'Не удалось включить. Настройте отпечаток, Face ID или PIN в настройках устройства.'),
        ));
      }
    } else {
      await lock.disable();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    final lock = context.watch<AppLock>();
    final sides = readable(context, EdgeInsets.zero);
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        // On a phone the list keeps its own padding, clear of the home
        // indicator.
        padding: sides.horizontal == 0
            ? null
            : sides.copyWith(bottom: MediaQuery.paddingOf(context).bottom),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Тема оформления',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          RadioGroup<ThemeMode>(
            groupValue: theme.mode,
            onChanged: (m) => theme.setMode(m!),
            child: const Column(
              children: [
                RadioListTile<ThemeMode>(
                  title: Text('Системная'),
                  value: ThemeMode.system,
                ),
                RadioListTile<ThemeMode>(
                  title: Text('Светлая'),
                  value: ThemeMode.light,
                ),
                RadioListTile<ThemeMode>(
                  title: Text('Тёмная'),
                  value: ThemeMode.dark,
                ),
              ],
            ),
          ),
          // A browser can't ask for a fingerprint or Face ID.
          if (!kIsWeb) ...[
            const Divider(height: 1),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text('Безопасность',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            SwitchListTile(
              title: const Text('Блокировка при входе'),
              subtitle: const Text(
                  'Спрашивать отпечаток, Face ID или PIN при открытии приложения'),
              value: lock.enabled,
              onChanged: (v) => _toggleLock(context, v),
            ),
          ],
          if (context.read<Updater>().enabled) ...[
            const Divider(height: 1),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text('Обновления',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const _UpdateTile(),
          ],
          const EasterEggFooter(),
        ],
      ),
    );
  }
}

/// The installed version and, when there is one, the newer release.
class _UpdateTile extends StatelessWidget {
  const _UpdateTile();

  Future<void> _tap(BuildContext context, Updater u) async {
    switch (u.stage) {
      case UpdateStage.available || UpdateStage.failed:
        await u.download();
      case UpdateStage.ready:
        await u.install();
      case UpdateStage.downloading:
        break;
      case UpdateStage.none:
        final messenger = ScaffoldMessenger.of(context);
        final ok = await u.check(force: true);
        if (u.release != null) return; // the banner tells
        messenger.showSnackBar(SnackBar(
            content: Text(ok
                ? 'Установлена последняя версия'
                : 'Не удалось проверить: нет связи с GitHub')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = context.watch<Updater>();
    final r = u.release;
    final title = switch (u.stage) {
      _ when u.checking => 'Проверка…',
      UpdateStage.available => 'Доступна версия ${r?.version}',
      UpdateStage.downloading =>
        'Загрузка версии ${r?.version}… ${(u.progress * 100).round()} %',
      UpdateStage.ready => 'Версия ${r?.version} загружена — установить',
      UpdateStage.failed => 'Не удалось загрузить — повторить',
      UpdateStage.none => 'Проверить обновления',
    };
    return ListTile(
      leading: const Icon(Icons.system_update_outlined),
      title: Text(title),
      subtitle: Text('Установлена версия ${u.installedVersion ?? '…'}'),
      trailing: r == null
          ? null
          : IconButton(
              tooltip: 'Что нового',
              icon: const Icon(Icons.open_in_new),
              onPressed: () => unawaited(launchUrl(Uri.parse(r.pageUrl),
                  mode: LaunchMode.externalApplication)),
            ),
      onTap: u.checking ? null : () => unawaited(_tap(context, u)),
    );
  }
}
