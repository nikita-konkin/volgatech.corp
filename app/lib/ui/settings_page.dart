import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_lock.dart';
import '../core/lesson_reminders.dart';
import '../mail/mail_alerts.dart';
import '../state/theme_controller.dart';
import '../state/updater.dart';
import '../web/a11y.dart';
import 'crash_log_page.dart';
import 'easter_egg.dart';
import 'glass.dart';
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
          _Section(
            title: 'Тема оформления',
            first: true,
            children: [
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
              if (kIsWeb) const _GlassTile(),
            ],
          ),
          // A browser can't ask for a fingerprint or Face ID.
          if (!kIsWeb)
            _Section(
              title: 'Безопасность',
              children: [
                SwitchListTile(
                  title: const Text('Блокировка при входе'),
                  subtitle: const Text(
                      'Спрашивать отпечаток, Face ID или PIN при открытии приложения'),
                  value: lock.enabled,
                  onChanged: (v) => _toggleLock(context, v),
                ),
              ],
            ),
          if (LessonReminders.supported)
            _Section(
              title: 'Уведомления',
              children: [
                const _LessonReminderTile(),
                if (MailAlerts.supported) const _MailAlertTile(),
              ],
            ),
          if (context.read<Updater>().enabled)
            const _Section(title: 'Обновления', children: [_UpdateTile()]),
          const _Section(title: 'Ошибки', children: [CrashLogTile()]),
          const EasterEggFooter(),
        ],
      ),
    );
  }
}

/// A titled group of settings, after a line; on glass, a card of its own.
class _Section extends StatelessWidget {
  const _Section(
      {required this.title, required this.children, this.first = false});

  final String title;
  final List<Widget> children;

  /// At the top: no line above it.
  final bool first;

  @override
  Widget build(BuildContext context) {
    final glass = Glass.of(context);
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
    if (!glass.on) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!first) const Divider(height: 1),
          header,
          ...children,
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: DecoratedBox(
        decoration: GlassDecoration(glass, seed: title.hashCode),
        child: Material(
          type: MaterialType.transparency,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [header, ...children],
            ),
          ),
        ),
      ),
    );
  }
}

/// «Liquid Glass», in the browser: on top of light or dark.
class _GlassTile extends StatelessWidget {
  const _GlassTile();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    final solid = MediaQuery.highContrastOf(context) || prefersSolidSurfaces();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          title: const Text('Liquid Glass'),
          subtitle: Text(solid
              ? 'Полупрозрачные панели на цветном фоне. Сейчас не действует: '
                  'в системе включено «Уменьшить прозрачность» или «Увеличить '
                  'контраст»'
              : 'Полупрозрачные панели на цветном фоне'),
          value: theme.glass,
          onChanged: theme.setGlass,
        ),
        // Clear glass, or matte: frosted and lightly scuffed.
        if (theme.glass)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('Прозрачное')),
                ButtonSegment(value: true, label: Text('Матовое')),
              ],
              selected: {theme.scuffed},
              onSelectionChanged: (s) => theme.setScuffed(s.first),
            ),
          ),
        // How strong: clear glass from nearly solid panels to the full
        // effect; matte glass from clear of frost to frosted over.
        if (theme.glass)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
            child: Row(
              children: [
                const Text('Сила эффекта'),
                Expanded(
                  child: Slider(
                    value: theme.scuffed ? theme.frost : theme.strength,
                    divisions: 20,
                    label:
                        '${((theme.scuffed ? theme.frost : theme.strength) * 100).round()} %',
                    semanticFormatterCallback: (v) =>
                        'Сила эффекта ${(v * 100).round()} процентов',
                    onChanged: (v) => theme.scuffed
                        ? theme.setFrost(v, save: false)
                        : theme.setStrength(v, save: false),
                    onChangeEnd: (v) => theme.scuffed
                        ? theme.setFrost(v)
                        : theme.setStrength(v),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// How long before a lesson to remind of it, if at all.
class _LessonReminderTile extends StatelessWidget {
  const _LessonReminderTile();

  static const _choices = {
    0: 'Не напоминать',
    10: 'За 10 минут',
    15: 'За 15 минут',
    30: 'За 30 минут',
  };

  Future<void> _set(BuildContext context, int minutes) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await context.read<LessonReminders>().setMinutes(minutes);
    if (!ok) {
      messenger.showSnackBar(const SnackBar(
        content: Text(
            'Уведомления запрещены. Разрешите их приложению в настройках телефона.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final minutes = context.watch<LessonReminders>().minutes;
    return ListTile(
      title: const Text('Перед занятием'),
      subtitle: const Text(
          'Уведомление с предметом и аудиторией. Расписание на 1–2 недели вперёд — откройте его хотя бы раз в неделю'),
      trailing: DropdownButton<int>(
        value: _choices.containsKey(minutes) ? minutes : 0,
        underline: const SizedBox.shrink(),
        items: [
          for (final MapEntry(key: m, value: label) in _choices.entries)
            DropdownMenuItem(value: m, child: Text(label)),
        ],
        onChanged: (m) => _set(context, m!),
      ),
    );
  }
}

/// New mail in «Входящие» as notifications.
class _MailAlertTile extends StatelessWidget {
  const _MailAlertTile();

  Future<void> _set(BuildContext context, bool on) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await context.read<MailAlerts>().setEnabled(on);
    if (!ok) {
      messenger.showSnackBar(const SnackBar(
        content: Text(
            'Уведомления запрещены. Разрешите их приложению в настройках телефона.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: const Text('Новые письма'),
      subtitle: const Text(
          'Проверять «Входящие» раз в 15 минут, даже когда приложение закрыто'),
      value: context.watch<MailAlerts>().enabled,
      onChanged: (v) => _set(context, v),
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
