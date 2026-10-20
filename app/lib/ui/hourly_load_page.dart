import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/hourly_docx.dart';
import '../core/prefs.dart';
import '../core/ru_plural.dart';
import '../data/volgatech_api.dart';
import '../state/auth_controller.dart';
import '../state/hourly_controller.dart';
import '../theme.dart';
import 'glass.dart';
import 'hourly_setup_pages.dart';
import 'layout.dart';

const _docxMime =
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

/// «Почасовая нагрузка»: the classes of the picked disciplines over the
/// months chosen, turned into «Приложение к форме 28» (.docx) to share.
class HourlyLoadPage extends StatelessWidget {
  const HourlyLoadPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthController>();
    return ChangeNotifierProvider(
      create: (_) {
        final c = HourlyController(
          api: context.read<VolgatechApi>(),
          personId: auth.personId ?? 0,
          prefs: context.read<Prefs>(),
          profile: auth.profile,
          loadTemplate: () async =>
              (await rootBundle.load(kHourlyTemplateAsset))
                  .buffer
                  .asUint8List(),
        );
        unawaited(c.load());
        return c;
      },
      child: const _HourlyView(),
    );
  }
}

class _HourlyView extends StatelessWidget {
  const _HourlyView();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<HourlyController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Почасовая нагрузка'),
        actions: [
          if (desktopBrowser)
            RefreshButton(
                onPressed:
                    c.loading ? null : () => unawaited(c.load(force: true))),
          IconButton(
            icon: const Icon(Icons.checklist),
            tooltip: 'Дисциплины',
            onPressed: () => _open(context, c, const HourlyCoursesPage()),
          ),
          IconButton(
            icon: const Icon(Icons.format_list_numbered),
            tooltip: 'Темы занятий',
            onPressed: () => _open(context, c, const HourlyTopicsPage()),
          ),
          IconButton(
            icon: const Icon(Icons.edit_note),
            tooltip: 'Шапка и подпись',
            onPressed: () => _open(context, c, const HourlyHeaderPage()),
          ),
        ],
        bottom: c.loading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: ArrowKeys(
        onPrevious: () => unawaited(c.shift(-1)),
        onNext: () => unawaited(c.shift(1)),
        child: Column(
          children: [
            _PeriodBar(
              label: c.periodLabel.toUpperCase(),
              onTap: () => unawaited(_pickMonths(context, c)),
              onPrev: () => unawaited(c.shift(-1)),
              onNext: () => unawaited(c.shift(1)),
            ),
            ReadableWidth(child: _Summary(c)),
            Expanded(child: _list(context, c)),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: ReadableWidth(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: FilledButton.icon(
              icon: const Icon(Icons.description_outlined),
              label: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Сформировать .docx', maxLines: 1)),
              onPressed: c.loading || c.rows.isEmpty
                  ? null
                  : () => unawaited(_share(context, c)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _list(BuildContext context, HourlyController c) {
    final entries = c.entries;
    if (c.loading && entries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (c.error != null && entries.isEmpty) {
      return _Message(
        icon: Icons.wifi_off,
        text: c.error!,
        action: OutlinedButton(
            onPressed: () => unawaited(c.load(force: true)),
            child: const Text('Обновить')),
      );
    }
    if (!c.anyPicked) {
      return _Message(
        icon: Icons.checklist,
        text: 'Отметьте дисциплины с почасовой нагрузкой — '
            'их занятия попадут в отчёт.',
        action: FilledButton.tonal(
            onPressed: () => _open(context, c, const HourlyCoursesPage()),
            child: const Text('Выбрать дисциплины')),
      );
    }
    if (entries.isEmpty) {
      return const _Message(
        icon: Icons.event_busy,
        text: 'В эти месяцы нет занятий по выбранным дисциплинам.',
      );
    }
    return RefreshIndicator(
      onRefresh: () => c.load(force: true),
      child: ListView.builder(
        padding: readable(context, const EdgeInsets.fromLTRB(12, 4, 12, 16)),
        itemCount: entries.length,
        itemBuilder: (context, i) => _EntryTile(
          entry: entries[i],
          showTopic: c.fillTopics,
          onIncluded: (v) => unawaited(c.setIncluded(entries[i], v)),
          onTopic: () => unawaited(_editTopic(context, c, entries[i])),
        ),
      ),
    );
  }

  static Future<void> _open(
          BuildContext context, HourlyController c, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider<HourlyController>.value(
            value: c, child: page),
      ));

  static Future<void> _pickMonths(
      BuildContext context, HourlyController c) async {
    final picked = await showDialog<List<DateTime>>(
      context: context,
      builder: (_) => _MonthsDialog(initial: c.months),
    );
    if (picked != null) await c.setMonths(picked);
  }

  static Future<void> _share(BuildContext context, HourlyController c) async {
    final messenger = ScaffoldMessenger.of(context);
    if (c.header.missing.isNotEmpty) {
      messenger.showSnackBar(
          SnackBar(content: Text('Заполните: ${c.header.missing.join(', ')}')));
      await _open(context, c, const HourlyHeaderPage());
      if (c.header.missing.isNotEmpty) return;
    }
    try {
      final bytes = await c.buildDocx();
      final XFile doc;
      if (kIsWeb) {
        // No files in a browser: Safari's share sheet takes it from memory,
        // other browsers download it.
        doc = XFile.fromData(bytes, name: c.fileName, mimeType: _docxMime);
      } else {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/${c.fileName}');
        await file.writeAsBytes(bytes, flush: true);
        doc = XFile(file.path, mimeType: _docxMime);
      }
      await SharePlus.instance.share(ShareParams(
        files: [doc],
        fileNameOverrides: [c.fileName],
        subject: 'Отчет по видам выполненных работ, ${c.periodLabel}',
      ));
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Не удалось сформировать документ: $e')));
    }
  }

  static Future<void> _editTopic(
      BuildContext context, HourlyController c, HourlyEntry e) async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (context) => TextPrompt(
        title: 'Тема занятия',
        initial: e.topic,
        note: Text(
            '${DateFormat('dd.MM.yy').format(e.lesson.date)} · '
            '${e.lesson.type} · ${e.lesson.discipline}',
            style: TextStyle(color: Brand.muted(context), fontSize: 13)),
        choices: [
          if (e.edited) ('Как в плане', 'reset'),
          if (e.planItem != null) ('Во всех занятиях темы', 'plan'),
          ('Только здесь', 'one'),
        ],
      ),
    );
    switch (result) {
      case ('one', final text):
        await c.setTopic(e, text);
      case ('plan', final text):
        await c.renamePlanTopic(e, text);
      case ('reset', _):
        await c.setTopic(e, null);
    }
  }
}

class _PeriodBar extends StatelessWidget {
  const _PeriodBar(
      {required this.label,
      required this.onTap,
      required this.onPrev,
      required this.onNext});
  final String label;
  final VoidCallback onTap;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return AccentBar(
      color: Brand.blue,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white, size: 30),
            tooltip: 'На месяц раньше',
            onPressed: onPrev,
          ),
          Expanded(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon:
                const Icon(Icons.chevron_right, color: Colors.white, size: 30),
            tooltip: 'На месяц позже',
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

/// Months to report, any of them: a year at a time, tapped on or off.
class _MonthsDialog extends StatefulWidget {
  const _MonthsDialog({required this.initial});
  final List<DateTime> initial;

  @override
  State<_MonthsDialog> createState() => _MonthsDialogState();
}

class _MonthsDialogState extends State<_MonthsDialog> {
  late final Set<DateTime> _on = {...widget.initial};
  late int _year = widget.initial.last.year;

  static final _name = DateFormat('LLL', 'ru_RU');

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          IconButton(
              tooltip: 'Предыдущий год',
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(() => _year--)),
          Expanded(child: Text('$_year', textAlign: TextAlign.center)),
          IconButton(
              tooltip: 'Следующий год',
              icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(() => _year++)),
        ],
      ),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var row = 0; row < 4; row++)
              Row(
                children: [
                  for (var m = row * 3 + 1; m <= row * 3 + 3; m++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: FilterChip(
                          label: SizedBox(
                              width: double.infinity,
                              child: Text(_name.format(DateTime(_year, m)),
                                  textAlign: TextAlign.center)),
                          showCheckmark: false,
                          selected: _on.contains(DateTime(_year, m)),
                          onSelected: (v) => setState(() => v
                              ? _on.add(DateTime(_year, m))
                              : _on.remove(DateTime(_year, m))),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена')),
        FilledButton(
            onPressed: _on.isEmpty
                ? null
                : () => Navigator.pop(context, _on.toList()..sort()),
            child: const Text('Готово')),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary(this.c);
  final HourlyController c;

  @override
  Widget build(BuildContext context) {
    final h = c.header;
    final count = c.rows.length;
    final muted = Brand.muted(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              [h.teacherPost, h.teacherName]
                  .where((s) => s.isNotEmpty)
                  .join(' '),
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
              '$count ${pluralRu(count, 'занятие', 'занятия', 'занятий')} · '
              '${c.totalHours} ч.',
              style: TextStyle(color: muted, fontSize: 14)),
          if (h.missing.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Brand.coral),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Заполните шапку: ${h.missing.join(', ')}',
                        style:
                            const TextStyle(color: Brand.coral, fontSize: 13)),
                  ),
                ],
              ),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Заполнять темы занятий'),
            subtitle: Text(c.fillTopics
                ? 'По тематическому плану'
                : 'Колонка останется пустой — заполните её в документе'),
            value: c.fillTopics,
            onChanged: (v) => unawaited(c.setFillTopics(v)),
          ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.showTopic,
    required this.onIncluded,
    required this.onTopic,
  });

  final HourlyEntry entry;
  final bool showTopic;
  final ValueChanged<bool> onIncluded;
  final VoidCallback onTopic;

  static final _day = DateFormat('dd.MM, E', 'ru_RU');

  @override
  Widget build(BuildContext context) {
    final l = entry.lesson;
    final muted = Brand.muted(context);
    final off = !entry.included;
    return Opacity(
      opacity: off ? 0.45 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: cardDecoration(
            context,
            BoxDecoration(
              color: Brand.card(context),
              borderRadius: BorderRadius.circular(8),
              border:
                  const Border(left: BorderSide(color: Brand.blue, width: 4)),
            ),
            seed: l.key),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: entry.included,
              onChanged: (v) => onIncluded(v ?? false),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [
                        _day.format(l.date),
                        if (l.time.isNotEmpty) l.time,
                        entry.groups.join(', '),
                      ].join(' · '),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text('${l.type} · ${l.discipline}',
                        style: TextStyle(color: muted, fontSize: 13)),
                    if (showTopic)
                      InkWell(
                        onTap: off ? null : onTopic,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  entry.topic.isEmpty
                                      ? 'Тема не указана'
                                      : entry.topic,
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: entry.topic.isEmpty
                                          ? Brand.coral
                                          : null,
                                      fontStyle: entry.edited
                                          ? FontStyle.italic
                                          : null),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.edit_outlined, size: 14, color: muted),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12, left: 6, right: 12),
              child: Text('${l.hours} ч.',
                  style: TextStyle(color: muted, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Brand.muted(context)),
            const SizedBox(height: 12),
            Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(color: Brand.muted(context))),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
