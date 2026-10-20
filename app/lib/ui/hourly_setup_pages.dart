import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/hourly_docx.dart';
import '../core/hourly_load.dart';
import '../core/ru_plural.dart';
import '../state/hourly_controller.dart';
import '../theme.dart';
import 'layout.dart';

/// The semester's disciplines, to tick the ones with hourly-paid classes:
/// a whole discipline, or some of its groups.
class HourlyCoursesPage extends StatelessWidget {
  const HourlyCoursesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<HourlyController>();
    final courses = c.courses;
    final muted = Brand.muted(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Дисциплины')),
      body: c.loading && courses.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: readable(context, const EdgeInsets.only(bottom: 16)),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                  child: Text(
                      '${c.semester} · отметьте дисциплины с почасовой '
                      'нагрузкой',
                      style: TextStyle(color: muted, fontSize: 13)),
                ),
                if (courses.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('В расписании семестра нет занятий.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: muted)),
                  ),
                for (final course in courses) _CourseTile(course),
              ],
            ),
    );
  }
}

class _CourseTile extends StatelessWidget {
  const _CourseTile(this.course);
  final HourlyCourse course;

  @override
  Widget build(BuildContext context) {
    final c = context.read<HourlyController>();
    context.watch<HourlyController>();
    final groups = course.groups.keys.toList()..sort();
    final on = [for (final g in groups) c.isPicked(course.discipline, g)];
    final all = on.every((x) => x), none = !on.any((x) => x);
    void toggle(bool value) => unawaited(c.setPicked(course.discipline, value));
    if (groups.length == 1) {
      return CheckboxListTile(
        value: all,
        onChanged: (v) => toggle(v ?? false),
        title: Text(course.discipline),
        subtitle: Text('${groups.single} · ${course.typeSummary()}'),
        controlAffinity: ListTileControlAffinity.leading,
      );
    }
    return ExpansionTile(
      leading: Checkbox(
        tristate: true,
        value: all ? true : (none ? false : null),
        onChanged: (_) => toggle(!all),
      ),
      title: Text(course.discipline),
      subtitle: Text('${groups.join(', ')} · ${course.typeSummary()}'),
      children: [
        for (final g in groups)
          CheckboxListTile(
            contentPadding: const EdgeInsets.only(left: 56, right: 16),
            value: c.isPicked(course.discipline, g),
            onChanged: (v) => unawaited(
                c.setPicked(course.discipline, v ?? false, groups: [g])),
            title: Text(g),
            subtitle: Text(course.typeSummary(g)),
            controlAffinity: ListTileControlAffinity.leading,
          ),
      ],
    );
  }
}

/// Topic plans of the picked disciplines: per lesson type, the topics in
/// order and how many classes each takes.
class HourlyTopicsPage extends StatelessWidget {
  const HourlyTopicsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<HourlyController>();
    final slots = c.planSlots.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final muted = Brand.muted(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Темы занятий'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Взять из прошлого отчёта',
            onPressed: () => unawaited(_import(context, c)),
          ),
        ],
      ),
      body: ListView(
        padding: readable(context, const EdgeInsets.fromLTRB(12, 8, 12, 24)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
            child: Text(
                'Темы идут по порядку с начала семестра: тема «× 4» — на '
                'четыре занятия подряд. Следующий отчёт продолжит с того '
                'места, где закончился предыдущий.',
                style: TextStyle(color: muted, fontSize: 13)),
          ),
          if (slots.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Сначала отметьте дисциплины.',
                  textAlign: TextAlign.center, style: TextStyle(color: muted)),
            ),
          for (final MapEntry(key: planKey, value: classes) in slots)
            _PlanCard(planKey: planKey, classes: classes),
        ],
      ),
    );
  }

  static Future<void> _import(BuildContext context, HourlyController c) async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await FilePicker.pickFiles(
        type: FileType.custom, allowedExtensions: ['docx'], withData: true);
    final bytes = picked?.files.firstOrNull?.bytes;
    if (bytes == null) return;
    try {
      final n = await c.importPlans(plansFromReport(bytes));
      messenger.showSnackBar(SnackBar(
          content: Text(n == 0
              ? 'В документе нет тем по дисциплинам этого семестра'
              : 'Темы взяты: $n ${pluralRu(n, 'план', 'плана', 'планов')}')));
    } on Object catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Не удалось прочитать документ: $e')));
    }
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.planKey, required this.classes});

  /// discipline|type
  final String planKey;

  /// How many classes of it in the semester.
  final int classes;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<HourlyController>();
    final plan = c.plan(planKey);
    final [discipline, type] = planKey.split('|');
    final muted = Brand.muted(context);
    final planned = planLength(plan);
    Future<void> save(List<PlanTopic> p) => c.savePlan(planKey, p);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(discipline,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            Text('$type · занятий в семестре: $classes · в плане: $planned',
                style: TextStyle(
                    color: planned < classes ? Brand.coral : muted,
                    fontSize: 13)),
            for (var i = 0; i < plan.length; i++)
              _TopicRow(
                number: i + 1,
                topic: plan[i],
                onRename: (t) =>
                    save([...plan]..[i] = plan[i].copyWith(title: t)),
                onCount: (n) =>
                    save([...plan]..[i] = plan[i].copyWith(count: n)),
                onDelete: () => save([...plan]..removeAt(i)),
              ),
            Wrap(
              spacing: 4,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Тема'),
                  onPressed: () async {
                    final t = await _askText(context, 'Новая тема', '');
                    if (t != null && t.trim().isNotEmpty) {
                      await save([...plan, PlanTopic(t.trim())]);
                    }
                  },
                ),
                TextButton.icon(
                  icon: const Icon(Icons.content_paste),
                  label: const Text('Вставить список'),
                  onPressed: () async {
                    final pasted = await _askList(context, plan);
                    if (pasted != null) await save(parsePlan(pasted));
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Future<String?> _askList(
      BuildContext context, List<PlanTopic> plan) async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => TextPrompt(
        title: 'Список тем',
        initial: [
          for (final t in plan)
            t.count > 1 ? '${t.title} ×${t.count}' : t.title,
        ].join('\n'),
        minLines: 6,
        maxLines: 14,
        decoration: const InputDecoration(
          hintText: 'Pandas для МО ×4\nСтатистика в задачах МО ×4',
          helperText:
              'По теме в строке; «×4» в конце — на четыре занятия подряд',
          helperMaxLines: 2,
        ),
      ),
    );
    return result?.$2;
  }
}

class _TopicRow extends StatelessWidget {
  const _TopicRow({
    required this.number,
    required this.topic,
    required this.onRename,
    required this.onCount,
    required this.onDelete,
  });

  final int number;
  final PlanTopic topic;
  final ValueChanged<String> onRename;
  final ValueChanged<int> onCount;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final muted = Brand.muted(context);
    return Row(
      children: [
        SizedBox(
            width: 24, child: Text('$number', style: TextStyle(color: muted))),
        Expanded(
          child: InkWell(
            onTap: () async {
              final t = await _askText(context, 'Тема', topic.title);
              if (t != null && t.trim().isNotEmpty) onRename(t.trim());
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(topic.title),
            ),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'На занятие меньше',
          icon: const Icon(Icons.remove, size: 18),
          onPressed: topic.count > 1 ? () => onCount(topic.count - 1) : null,
        ),
        Text('× ${topic.count}'),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'На занятие больше',
          icon: const Icon(Icons.add, size: 18),
          onPressed: topic.count < 99 ? () => onCount(topic.count + 1) : null,
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Удалить тему',
          icon: const Icon(Icons.delete_outline, size: 20),
          onPressed: onDelete,
        ),
      ],
    );
  }
}

Future<String?> _askText(
    BuildContext context, String title, String initial) async {
  final result = await showDialog<(String, String)>(
    context: context,
    builder: (_) => TextPrompt(title: title, initial: initial),
  );
  return result?.$2;
}

/// A dialog around one text field. Pops with the chosen [choices] value and
/// the text, or null on «Отмена». Owns its controller, so the field
/// outlives the closing animation.
class TextPrompt extends StatefulWidget {
  const TextPrompt({
    super.key,
    required this.title,
    this.initial = '',
    this.note,
    this.decoration,
    this.minLines,
    this.maxLines,
    this.choices = const [('Сохранить', 'save')],
  });

  final String title;
  final String initial;

  /// Shown above the field.
  final Widget? note;
  final InputDecoration? decoration;
  final int? minLines;
  final int? maxLines;

  /// The buttons after «Отмена»: label and what to pop with; the last one
  /// is the main one.
  final List<(String, String)> choices;

  @override
  State<TextPrompt> createState() => _TextPromptState();
}

class _TextPromptState extends State<TextPrompt> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _pop(String choice) => Navigator.pop(context, (choice, _text.text));

  @override
  Widget build(BuildContext context) {
    final many = (widget.maxLines ?? 2) > 1;
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: many ? 480 : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.note case final note?) ...[
              note,
              const SizedBox(height: 8),
            ],
            TextField(
              controller: _text,
              autofocus: true,
              minLines: widget.minLines,
              maxLines: widget.maxLines,
              decoration: widget.decoration,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: widget.maxLines == 1
                  ? (_) => _pop(widget.choices.last.$2)
                  : null,
            ),
          ],
        ),
      ),
      actionsOverflowButtonSpacing: 4,
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена')),
        for (final (label, value)
            in widget.choices.take(widget.choices.length - 1))
          TextButton(onPressed: () => _pop(value), child: Text(label)),
        FilledButton(
            onPressed: () => _pop(widget.choices.last.$2),
            child: Text(widget.choices.last.$1)),
      ],
    );
  }
}

/// The teacher line and the signature. Filled once and remembered.
class HourlyHeaderPage extends StatefulWidget {
  const HourlyHeaderPage({super.key});

  @override
  State<HourlyHeaderPage> createState() => _HourlyHeaderPageState();
}

class _HourlyHeaderPageState extends State<HourlyHeaderPage> {
  late final HourlyHeader _initial = context.read<HourlyController>().header;
  late final _teacherPost = TextEditingController(text: _initial.teacherPost);
  late final _teacherName = TextEditingController(text: _initial.teacherName);
  late final _signerPost = TextEditingController(text: _initial.signerPost);
  late final _signerName = TextEditingController(text: _initial.signerName);

  @override
  void dispose() {
    for (final c in [_teacherPost, _teacherName, _signerPost, _signerName]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    String t(TextEditingController c) => c.text.trim();
    final navigator = Navigator.of(context);
    await context.read<HourlyController>().saveHeader(HourlyHeader(
          teacherPost: t(_teacherPost),
          teacherName: t(_teacherName),
          signerPost: t(_signerPost),
          signerName: t(_signerName),
        ));
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final muted = Brand.muted(context);
    Widget field(TextEditingController c, String label, {String? hint}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: c,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: label, hintText: hint),
          ),
        );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Шапка и подпись'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Сохранить')),
        ],
      ),
      body: ListView(
        padding: readable(context, const EdgeInsets.fromLTRB(16, 16, 16, 24)),
        children: [
          Text('Преподаватель', style: TextStyle(color: muted)),
          const SizedBox(height: 8),
          field(_teacherPost, 'Должность', hint: 'ст. преподаватель'),
          field(_teacherName, 'ФИО', hint: 'Фамилия Имя Отчество'),
          const SizedBox(height: 8),
          Text('Подпись под таблицей', style: TextStyle(color: muted)),
          const SizedBox(height: 8),
          field(_signerPost, 'Должность', hint: 'Зав. кафедрой ПиП ЭВС'),
          field(_signerName, 'И.О. Фамилия', hint: 'А.Б. Иванова'),
        ],
      ),
    );
  }
}
