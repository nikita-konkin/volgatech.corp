import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/portal_workload.dart';
import '../core/portal_workload_batch.dart';
import '../core/ru_plural.dart';
import 'layout.dart';

typedef WorkloadMonthHours = ({WorkloadBatchOption option, int hours});

class WorkloadBatchChecklist extends StatefulWidget {
  const WorkloadBatchChecklist(this.months, {super.key});

  final List<WorkloadMonthHours> months;

  @override
  State<WorkloadBatchChecklist> createState() => _WorkloadBatchChecklistState();
}

class _WorkloadBatchChecklistState extends State<WorkloadBatchChecklist> {
  late final _checked = {
    for (final month in widget.months)
      if (month.hours > 0) month.option.value,
  };

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Несколько месяцев'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final month in widget.months)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(month.option.label),
                  subtitle: Text('${month.hours} ч. по расписанию кафедры'),
                  value: _checked.contains(month.option.value),
                  onChanged: (checked) => setState(() {
                    if (checked == true) {
                      _checked.add(month.option.value);
                    } else {
                      _checked.remove(month.option.value);
                    }
                  }),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: _checked.isEmpty
                  ? null
                  : () => Navigator.pop(context, [
                        for (final month in widget.months)
                          if (_checked.contains(month.option.value))
                            month.option,
                      ]),
              child: const Text('Загрузить')),
        ],
      );
}

class WorkloadBatchReview extends StatefulWidget {
  const WorkloadBatchReview(this.batch, {super.key});

  final WorkloadBatch batch;

  @override
  State<WorkloadBatchReview> createState() => _WorkloadBatchReviewState();
}

class _WorkloadBatchReviewState extends State<WorkloadBatchReview> {
  late final _choices = <WorkloadLineIdentity, WorkloadCellIdentity?>{
    for (final entry in widget.batch.lines.entries)
      if (entry.value.suggested case final row?) entry.key: row,
  };

  @override
  Widget build(BuildContext context) {
    final changes = widget.batch.changes(_choices);
    final hours = workloadBatchTotal(changes);
    final seen = <WorkloadLineIdentity>{};
    return Scaffold(
      appBar: AppBar(title: const Text('Из расписания за несколько месяцев')),
      body: ListView(
        padding: readable(context, const EdgeInsets.all(16)),
        children: [
          if (widget.batch.lines.isNotEmpty)
            const Text(
                'Выбранная строка портала применяется во всех месяцах, где её поле свободно.'),
          for (final month in widget.batch.months) ...[
            const SizedBox(height: 16),
            Text(month.option.label,
                style: Theme.of(context).textTheme.titleLarge),
            if (month.hidden.isNotEmpty) WorkloadHiddenSummary(month.hidden),
            if (month.lines.isEmpty)
              const Text('Нет занятий по дисциплинам этой кафедры.'),
            for (final total in month.lines) ...[
              const Divider(height: 24),
              _line(month, total, seen.add(workloadLineIdentity(total))),
            ],
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: ReadableWidth(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: FilledButton(
              onPressed:
                  hours == 0 ? null : () => Navigator.pop(context, changes),
              child: Text('Продолжить · ${formatWorkloadHours(hours)} ч.'),
            ),
          ),
        ),
      ),
    );
  }

  Widget _line(WorkloadBatchMonth month, WorkloadTotal total, bool first) {
    final id = workloadLineIdentity(total);
    final options = widget.batch.lines[id]!;
    final choice = _choices[id];
    final hasChoice = _choices.containsKey(id);
    final kind = workloadColumnLabels[total.column];
    final style = Theme.of(context).textTheme;
    final discipline = workloadName(total.discipline);
    final disciplines =
        options.choices.map((row) => workloadName(row.discipline)).toSet();
    final showDiscipline =
        disciplines.length > 1 || !disciplines.contains(discipline);
    String label(WorkloadCellIdentity row) =>
        '${row.specialty} · ${row.appointment}'
        '${showDiscipline ? ' · ${row.discipline}' : ''}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(total.discipline, style: style.titleSmall),
        Text('$kind · ${total.groups.join(', ')} · ${total.hours} ч.'),
        Text(total.dates.toSet().map(DateFormat('dd.MM').format).join(', '),
            style: style.bodySmall),
        if (first && options.choices.isNotEmpty)
          DropdownButtonHideUnderline(
            child: DropdownButton<({WorkloadCellIdentity? row})>(
              isExpanded: true,
              itemHeight: null,
              value: hasChoice ? (row: choice) : null,
              hint: Text(
                disciplines.contains(discipline)
                    ? 'Выбрать строку портала'
                    : 'Сопоставить с другой дисциплиной',
              ),
              onChanged: (item) => setState(() => _choices[id] = item?.row),
              items: [
                const DropdownMenuItem(
                    value: (row: null), child: Text('Пропустить')),
                for (final row in options.choices)
                  DropdownMenuItem(
                    value: (row: row),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(label(row),
                          overflow: TextOverflow.ellipsis, maxLines: 3),
                    ),
                  ),
              ],
            ),
          ),
        if (options.choices.isEmpty)
          Text(options.sameDiscipline
              ? 'Нет свободного поля для сопоставления.'
              : 'В нагрузке портала нет доступного поля «$kind».')
        else if (choice != null && month.availableCell(choice) == null)
          const Text('В этом месяце выбранное поле недоступно.')
        else if (!first)
          Text(choice != null
              ? label(choice)
              : hasChoice
                  ? 'Пропустить'
                  : 'Строка портала ещё не выбрана.'),
      ],
    );
  }
}

class WorkloadHiddenSummary extends StatelessWidget {
  const WorkloadHiddenSummary(this.hidden, {super.key});

  final List<WorkloadTotal> hidden;

  @override
  Widget build(BuildContext context) {
    final names = {for (final total in hidden) total.discipline};
    final hours = hidden.fold(0, (sum, total) => sum + total.hours);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Скрыто ${names.length} '
            '${pluralRu(names.length, 'дисциплина', 'дисциплины', 'дисциплин')} '
            'других кафедр · $hours ч.'),
        Text(names.join(', '), style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
