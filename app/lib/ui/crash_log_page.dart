import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/crash_log.dart';
import '../core/ru_plural.dart';
import 'layout.dart';

/// «Отчёты об ошибках» in Settings: how many there were, and the way in.
class CrashLogTile extends StatelessWidget {
  const CrashLogTile({super.key});

  @override
  Widget build(BuildContext context) {
    final n = context.watch<CrashLog>().entries.length;
    return ListTile(
      leading: const Icon(Icons.bug_report_outlined),
      title: const Text('Отчёты об ошибках'),
      subtitle: Text(n == 0
          ? 'Ошибок не было'
          : '$n ${pluralRu(n, 'ошибка', 'ошибки', 'ошибок')} — посмотреть '
              'и отправить разработчику'),
      onTap: () => unawaited(Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const CrashLogPage()))),
    );
  }
}

/// The errors kept on the device, to read and to send — by the share menu on
/// a phone, or copied into a message in the browser.
class CrashLogPage extends StatelessWidget {
  const CrashLogPage({super.key});

  /// Android's share menu; a browser's is hit and miss (a desktop one opens
  /// the mail program instead), so there it is copying.
  static bool get canShare =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _copy(BuildContext context, CrashLog log) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: log.report()));
    messenger.showSnackBar(const SnackBar(
        content: Text('Отчёт скопирован — вставьте его в письмо или чат')));
  }

  Future<void> _clear(BuildContext context, CrashLog log) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить отчёты?'),
        content: const Text('Записи об ошибках удалятся с устройства.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Очистить')),
        ],
      ),
    );
    if (ok ?? false) await log.clear();
  }

  @override
  Widget build(BuildContext context) {
    final log = context.watch<CrashLog>();
    final entries = log.entries;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Отчёты об ошибках'),
        actions: [
          if (entries.isNotEmpty)
            IconButton(
              tooltip: 'Очистить',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => unawaited(_clear(context, log)),
            ),
        ],
      ),
      body: entries.isEmpty
          ? const Center(
              child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Ошибок не было', textAlign: TextAlign.center),
            ))
          : ListView(
              padding: readable(
                  context,
                  EdgeInsets.only(
                      bottom: 16 + MediaQuery.paddingOf(context).bottom)),
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child:
                      Text('Приложение записывает свои ошибки только здесь, на '
                          'устройстве. Отчёт уходит, только если вы сами его '
                          'отправите: в нём нет логина, почты и данных из '
                          'расписания — только что сломалось и где.'),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (canShare)
                        FilledButton.icon(
                          icon: const Icon(Icons.share_outlined),
                          label: const Text('Отправить'),
                          onPressed: () => unawaited(SharePlus.instance.share(
                              ShareParams(
                                  text: log.report(),
                                  subject: 'Отчёт об ошибках'))),
                        ),
                      (canShare ? OutlinedButton.icon : FilledButton.icon)(
                        icon: const Icon(Icons.copy_outlined),
                        label: const Text('Скопировать'),
                        onPressed: () => unawaited(_copy(context, log)),
                      ),
                    ],
                  ),
                ),
                for (final e in entries) _EntryTile(e),
              ],
            ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile(this.e);
  final CrashEntry e;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final at = MaterialLocalizations.of(context);
    final local = e.at.toLocal();
    final time = at.formatTimeOfDay(TimeOfDay.fromDateTime(local),
        alwaysUse24HourFormat: true);
    return ExpansionTile(
      title: Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text([
        '${at.formatShortDate(local)}, $time',
        if (e.version.isNotEmpty) 'версия ${e.version}',
        if (e.count > 1) '×${e.count}',
      ].join(' · ')),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        SelectableText(
          '${e.error}\n\n${e.stack}'.trim(),
          style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: muted),
        ),
      ],
    );
  }
}
