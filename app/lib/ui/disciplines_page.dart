import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/hourly_load.dart';
import '../core/ru_plural.dart';
import '../data/volgatech_api.dart';
import '../state/auth_controller.dart';
import '../state/disciplines_controller.dart';
import '../theme.dart';
import 'glass.dart';
import 'layout.dart';
import 'widgets/copy_text.dart';

/// «Дисциплины»: what the schedule has this semester, each name ready to
/// copy, or all of them at once.
class DisciplinesPage extends StatelessWidget {
  const DisciplinesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        final c = DisciplinesController(context.read<VolgatechApi>(),
            context.read<AuthController>().personId ?? 0);
        unawaited(c.load());
        return c;
      },
      child: const _DisciplinesView(),
    );
  }
}

class _DisciplinesView extends StatelessWidget {
  const _DisciplinesView();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<DisciplinesController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Дисциплины'),
        actions: [
          if (desktopBrowser)
            RefreshButton(
                onPressed:
                    c.loading ? null : () => unawaited(c.load(force: true))),
          IconButton(
            icon: const Icon(Icons.copy_all),
            tooltip: 'Копировать все названия',
            onPressed: c.courses.isEmpty
                ? null
                : () => unawaited(copyText(context, c.namesText,
                    message: 'Скопировано: ${c.courses.length} '
                        '${pluralRu(c.courses.length, 'дисциплина', 'дисциплины', 'дисциплин')}')),
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
            _SemesterBar(
              label: c.label.toUpperCase(),
              onPrev: () => unawaited(c.shift(-1)),
              onNext: () => unawaited(c.shift(1)),
            ),
            Expanded(child: _list(context, c)),
          ],
        ),
      ),
    );
  }

  Widget _list(BuildContext context, DisciplinesController c) {
    final courses = c.courses;
    final muted = Brand.muted(context);
    if (c.loading && !c.loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (c.error != null && !c.loaded) {
      return _Message(
        icon: Icons.wifi_off,
        text: c.error!,
        action: OutlinedButton(
            onPressed: () => unawaited(c.load(force: true)),
            child: const Text('Обновить')),
      );
    }
    if (courses.isEmpty) {
      return const _Message(
          icon: Icons.event_busy, text: 'В расписании семестра нет занятий');
    }
    return RefreshIndicator(
      onRefresh: () => c.load(force: true),
      child: ListView.builder(
        padding: readable(context, const EdgeInsets.fromLTRB(4, 8, 4, 16)),
        itemCount: courses.length + 1,
        itemBuilder: (_, i) {
          if (i == 0) {
            final n = courses.length;
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Text(
                '$n ${pluralRu(n, 'дисциплина', 'дисциплины', 'дисциплин')} · '
                'удерживайте, чтобы скопировать',
                style: TextStyle(color: muted, fontSize: 13),
              ),
            );
          }
          return _CourseTile(courses[i - 1]);
        },
      ),
    );
  }
}

class _CourseTile extends StatelessWidget {
  const _CourseTile(this.course);
  final HourlyCourse course;

  @override
  Widget build(BuildContext context) {
    final groups = course.groups.keys.toList()..sort();
    void copy() => unawaited(
        copyText(context, course.discipline, message: 'Название скопировано'));
    return ListTile(
      title: Text(course.discipline,
          style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text([
        if (groups.isNotEmpty) groups.join(', '),
        course.typeSummary(),
      ].join('\n')),
      isThreeLine: groups.isNotEmpty,
      onLongPress: copy,
      trailing: IconButton(
        icon: const Icon(Icons.copy, size: 20),
        tooltip: 'Копировать название',
        onPressed: copy,
      ),
    );
  }
}

class _SemesterBar extends StatelessWidget {
  const _SemesterBar(
      {required this.label, required this.onPrev, required this.onNext});
  final String label;
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
            tooltip: 'Предыдущий семестр',
            onPressed: onPrev,
          ),
          Expanded(
            child: Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ),
          IconButton(
            icon:
                const Icon(Icons.chevron_right, color: Colors.white, size: 30),
            tooltip: 'Следующий семестр',
            onPressed: onNext,
          ),
        ],
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
