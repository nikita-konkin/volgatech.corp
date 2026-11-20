import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/hourly_load.dart';
import '../core/portal_workload.dart';
import '../data/volgatech_api.dart';
import 'layout.dart';

/// Monthly timetable hours and the browser workflow for the portal form
final class PortalWorkloadWebPage extends StatefulWidget {
  const PortalWorkloadWebPage({
    super.key,
    required this.api,
    required this.personId,
  });

  final VolgatechApi api;
  final int? personId;

  @override
  State<PortalWorkloadWebPage> createState() => _PortalWorkloadWebPageState();
}

/// Selected month and the timetable request shown for it
final class _PortalWorkloadWebPageState extends State<PortalWorkloadWebPage> {
  DateTime get _today => DateTime.now().toUtc().add(const Duration(hours: 3));
  late DateTime _month = workloadMonth(_today);
  late Future<List<WorkloadTotal>> _totals = _load(_month);

  Future<List<WorkloadTotal>> _load(DateTime month) async {
    final personId = widget.personId;
    final today = _today;
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    if (personId == null || yesterday.isBefore(month)) return [];
    final end = DateTime(month.year, month.month + 1, 0);
    final days = await widget.api.getSchedule(
        personId, month, yesterday.isBefore(end) ? yesterday : end);
    return monthlyWorkload(hourlyClassesFrom(days), month, today);
  }

  void _select(DateTime month) {
    setState(() {
      _month = month;
      _totals = _load(month);
    });
  }

  void _notice(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copy(List<WorkloadTotal> totals) async {
    try {
      await Clipboard.setData(ClipboardData(
        text: workloadPortalPayload(_month, totals),
      ));
      _notice('Данные для портала скопированы');
    } on PlatformException {
      _notice('Не удалось скопировать данные для портала');
    }
  }

  Future<void> _open(Uri uri) async {
    try {
      if (await launchUrl(uri, webOnlyWindowName: '_blank')) return;
    } on PlatformException {
      _notice('Не удалось открыть страницу');
      return;
    }
    _notice('Не удалось открыть страницу');
  }

  @override
  Widget build(BuildContext context) {
    final today = _today;
    final latest = DateTime(today.year, today.month);
    final next = DateTime(_month.year, _month.month + 1);
    final previous = DateTime(_month.year, _month.month - 1);
    return Scaffold(
      appBar: AppBar(title: const Text('Учебная нагрузка')),
      body: FutureBuilder<List<WorkloadTotal>>(
        future: _totals,
        builder: (context, snapshot) {
          final loaded = snapshot.connectionState == ConnectionState.done;
          final totals = loaded
              ? snapshot.data ?? const <WorkloadTotal>[]
              : const <WorkloadTotal>[];
          return ListView(
            padding: readable(context, const EdgeInsets.all(16)),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    tooltip: 'Предыдущий месяц',
                    onPressed: () => _select(previous),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text(MaterialLocalizations.of(context)
                      .formatMonthYear(_month)),
                  IconButton(
                    tooltip: 'Следующий месяц',
                    onPressed:
                        next.isAfter(latest) ? null : () => _select(next),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed:
                        totals.isEmpty ? null : () => unawaited(_copy(totals)),
                    child: const Text('Подготовить для портала'),
                  ),
                  OutlinedButton(
                    onPressed: () => unawaited(_open(
                        Uri.https('portal.volgatech.net', '/my/person.aspx'))),
                    child: const Text('Открыть портал'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Скопируйте часы, откройте месячную форму в режиме редактирования и запустите закладку «Заполнить из Волгатех»',
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () =>
                      unawaited(_open(Uri.base.resolve('bookmark.html'))),
                  child: const Text('Как добавить закладку'),
                ),
              ),
              const Divider(),
              if (!loaded)
                const LinearProgressIndicator()
              else if (snapshot.hasError) ...[
                const Text('Не удалось загрузить часы из расписания'),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => _select(_month),
                    child: const Text('Повторить'),
                  ),
                ),
              ] else if (totals.isEmpty)
                const Text('В расписании за прошедшие дни месяца нет занятий')
              else
                for (final total in totals)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(total.discipline),
                    subtitle: Text(
                      '${workloadColumnLabels[total.column]} · ${total.groups.join(', ')} · ${total.hours} ч.',
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}
