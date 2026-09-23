import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/foreign_memo.dart';
import '../core/memo_docx.dart';
import '../core/prefs.dart';
import '../core/ru_plural.dart';
import '../data/volgatech_api.dart';
import '../state/auth_controller.dart';
import '../state/memo_controller.dart';
import '../theme.dart';
import 'memo_header_page.dart';

const _docxMime =
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

/// «Иностранные группы»: the month's classes with foreign-student groups,
/// turned into the portal's «служебная записка» (.docx) to share.
class ForeignMemoPage extends StatelessWidget {
  const ForeignMemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthController>();
    return ChangeNotifierProvider(
      create: (_) {
        final c = MemoController(
          api: context.read<VolgatechApi>(),
          personId: auth.personId ?? 0,
          prefs: context.read<Prefs>(),
          profile: auth.profile,
          loadTemplate: () async =>
              (await rootBundle.load(kMemoTemplateAsset)).buffer.asUint8List(),
        );
        unawaited(c.load());
        return c;
      },
      child: const _MemoView(),
    );
  }
}

class _MemoView extends StatelessWidget {
  const _MemoView();

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final c = context.watch<MemoController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Иностранные группы'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note),
            tooltip: 'Шапка и подписи',
            onPressed: () => unawaited(_editHeader(context, c)),
          ),
        ],
        bottom: c.loading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: Column(
        children: [
          _MonthBar(
            label: _cap(c.monthLabel).toUpperCase(),
            onPrev: () => unawaited(c.prevMonth()),
            onNext: () => unawaited(c.nextMonth()),
          ),
          _Summary(controller: c, onEditHeader: () => _editHeader(context, c)),
          Expanded(child: _list(context, c)),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
          child: Row(
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Занятие'),
                onPressed:
                    c.loading ? null : () => unawaited(_addRow(context, c)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Сформировать .docx'),
                  onPressed: c.loading || c.memoRows.isEmpty
                      ? null
                      : () => unawaited(_share(context, c)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _list(BuildContext context, MemoController c) {
    final entries = c.entries;
    if (c.loading && entries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (c.error != null && entries.isEmpty) {
      return _Message(
        icon: Icons.wifi_off,
        text: c.error!,
        action: OutlinedButton(
            onPressed: () => unawaited(c.load()),
            child: const Text('Обновить')),
      );
    }
    if (entries.isEmpty) {
      return const _Message(
        icon: Icons.event_busy,
        text: 'В этом месяце нет занятий с иностранными группами '
            '(номер группы из трёх цифр, например ИСТ-110).',
      );
    }
    return RefreshIndicator(
      onRefresh: c.load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        itemCount: entries.length,
        itemBuilder: (context, i) => _EntryTile(
          entry: entries[i],
          onIncluded: (v) => unawaited(c.setIncluded(entries[i], v)),
          onRename: () => unawaited(_rename(context, c, entries[i])),
          onRemove: entries[i].row.manual
              ? () => unawaited(c.removeManual(entries[i].row))
              : null,
        ),
      ),
    );
  }

  static Future<void> _editHeader(BuildContext context, MemoController c) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider<MemoController>.value(
          value: c,
          child: const MemoHeaderPage(),
        ),
      ));

  static Future<void> _share(BuildContext context, MemoController c) async {
    final messenger = ScaffoldMessenger.of(context);
    if (c.header.missing.isNotEmpty) {
      messenger.showSnackBar(
          SnackBar(content: Text('Заполните: ${c.header.missing.join(', ')}')));
      await _editHeader(context, c);
      if (c.header.missing.isNotEmpty) return;
    }
    try {
      final bytes = await c.buildDocx();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${c.fileName}');
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: _docxMime)],
        subject: 'Служебная записка: занятия на иностранном языке, '
            '${c.monthLabel}',
      ));
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Не удалось сформировать документ: $e')));
    }
  }

  static Future<void> _rename(
      BuildContext context, MemoController c, MemoEntry e) async {
    final text = TextEditingController(text: e.discipline);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Название в записке'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('В расписании: ${e.row.discipline}',
                style: TextStyle(color: Brand.muted(context), fontSize: 13)),
            const SizedBox(height: 8),
            TextField(controller: text, autofocus: true, maxLines: null),
            const SizedBox(height: 6),
            Text('Применяется ко всем занятиям по этой дисциплине.',
                style: TextStyle(color: Brand.muted(context), fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(context, text.text),
              child: const Text('Сохранить')),
        ],
      ),
    );
    text.dispose();
    if (name != null) await c.renameDiscipline(e.row.discipline, name);
  }

  static Future<void> _addRow(BuildContext context, MemoController c) async {
    final row = await showDialog<MemoRow>(
      context: context,
      builder: (_) => _AddRowDialog(month: c.month, disciplines: c.disciplines),
    );
    if (row != null) await c.addManual(row);
  }
}

class _MonthBar extends StatelessWidget {
  const _MonthBar(
      {required this.label, required this.onPrev, required this.onNext});
  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v < -250) onNext();
        if (v > 250) onPrev();
      },
      child: Container(
        color: Brand.blue,
        child: Row(
          children: [
            IconButton(
              icon:
                  const Icon(Icons.chevron_left, color: Colors.white, size: 30),
              tooltip: 'Предыдущий месяц',
              onPressed: onPrev,
            ),
            Expanded(
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right,
                  color: Colors.white, size: 30),
              tooltip: 'Следующий месяц',
              onPressed: onNext,
            ),
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.controller, required this.onEditHeader});
  final MemoController controller;
  final VoidCallback onEditHeader;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final h = c.header;
    final count = c.memoRows.length;
    final muted = Brand.muted(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              [h.teacherName, h.teacherPost]
                  .where((s) => s.isNotEmpty)
                  .join(', '),
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
              '$count ${pluralRu(count, 'занятие', 'занятия', 'занятий')} · '
              '${c.totalHours} ч.',
              style: TextStyle(color: muted, fontSize: 14)),
          if (h.missing.isNotEmpty)
            InkWell(
              onTap: onEditHeader,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 16, color: Brand.coral),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Заполните шапку: ${h.missing.join(', ')}',
                        style:
                            const TextStyle(color: Brand.coral, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.onIncluded,
    required this.onRename,
    required this.onRemove,
  });

  final MemoEntry entry;
  final ValueChanged<bool> onIncluded;
  final VoidCallback onRename;
  final VoidCallback? onRemove;

  static final _day = DateFormat('dd.MM, E', 'ru_RU');

  @override
  Widget build(BuildContext context) {
    final r = entry.row;
    final muted = Brand.muted(context);
    final off = !entry.included;
    return Opacity(
      opacity: off ? 0.45 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Brand.card(context),
          borderRadius: BorderRadius.circular(8),
          border: const Border(left: BorderSide(color: Brand.blue, width: 4)),
        ),
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
                        _day.format(r.date),
                        if (r.time.isNotEmpty) r.time,
                        r.groups.join(', '),
                      ].join(' · '),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    InkWell(
                      onTap: onRename,
                      child: Text(entry.discipline,
                          style: const TextStyle(fontSize: 14)),
                    ),
                    Text(
                      [r.type, if (r.manual) 'добавлено вручную'].join(' · '),
                      style: TextStyle(color: muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12, left: 6, right: 8),
              child: Text('${r.hours} ч.',
                  style: TextStyle(color: muted, fontSize: 13)),
            ),
            if (onRemove != null)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Удалить',
                onPressed: onRemove,
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

/// A class that is not in the schedule (a replacement, a moved lesson).
class _AddRowDialog extends StatefulWidget {
  const _AddRowDialog({required this.month, required this.disciplines});
  final DateTime month;
  final List<String> disciplines;

  @override
  State<_AddRowDialog> createState() => _AddRowDialogState();
}

class _AddRowDialogState extends State<_AddRowDialog> {
  static const _types = ['лекция', 'практическая', 'лабораторная'];
  static final _dmy = DateFormat('dd.MM.yyyy');

  late DateTime _date = widget.month;
  final _time = TextEditingController();
  final _group = TextEditingController();
  final _discipline = TextEditingController();
  String _type = _types.first;

  @override
  void initState() {
    super.initState();
    _discipline.addListener(_changed);
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    _discipline.removeListener(_changed);
    _time.dispose();
    _group.dispose();
    _discipline.dispose();
    super.dispose();
  }

  bool get _valid =>
      _group.text.trim().isNotEmpty && _discipline.text.trim().isNotEmpty;

  Future<void> _pickDate() async {
    final m = widget.month;
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: m,
      lastDate: DateTime(m.year, m.month + 1, 0),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Добавить занятие'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(_dmy.format(_date)),
              onTap: () => unawaited(_pickDate()),
            ),
            TextField(
              controller: _time,
              keyboardType: TextInputType.datetime,
              decoration: const InputDecoration(
                  labelText: 'Время начала', hintText: '08:00'),
            ),
            TextField(
              controller: _group,
              decoration: const InputDecoration(
                  labelText: 'Группа', hintText: 'ИСТ-110'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            // Pick one of the month's subjects or type another.
            DropdownMenu<String>(
              controller: _discipline,
              label: const Text('Дисциплина'),
              expandedInsets: EdgeInsets.zero,
              enableFilter: true,
              requestFocusOnTap: true,
              dropdownMenuEntries: [
                for (final d in widget.disciplines)
                  DropdownMenuEntry(value: d, label: d),
              ],
              onSelected: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Тип занятия'),
              items: [
                for (final t in _types)
                  DropdownMenuItem(value: t, child: Text(t)),
              ],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена')),
        FilledButton(
          onPressed: _valid
              ? () => Navigator.pop(
                    context,
                    MemoRow(
                      date: _date,
                      time: _time.text.trim(),
                      groups: [_group.text.trim()],
                      discipline: _discipline.text.trim(),
                      type: _type,
                      manual: true,
                    ),
                  )
              : null,
          child: const Text('Добавить'),
        ),
      ],
    );
  }
}
