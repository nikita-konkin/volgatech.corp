import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/cache.dart';
import '../core/lesson_grouping.dart';
import '../core/ru_plural.dart';
import '../data/volgatech_api.dart';
import '../models/schedule.dart';
import '../state/auth_controller.dart';
import '../state/schedule_controller.dart';
import '../theme.dart';
import 'app_drawer.dart';
import 'offline_banner.dart';
import 'week_summary_page.dart';

class SchedulePage extends StatelessWidget {
  const SchedulePage({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<VolgatechApi>();
    final cache = context.read<JsonCache>();
    final personId = context.read<AuthController>().personId ?? 0;
    return ChangeNotifierProvider(
      create: (_) {
        final c = ScheduleController(api, personId, cache);
        unawaited(c.ensureLoaded());
        return c;
      },
      child: const _ScheduleView(),
    );
  }
}

class _ScheduleView extends StatelessWidget {
  const _ScheduleView();

  static final _dayMonth = DateFormat('d MMMM', 'ru_RU');
  static final _full = DateFormat('d MMMM y', 'ru_RU');
  static final _weekday = DateFormat('EEEE', 'ru_RU');

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ScheduleController>();
    // Week type/number resolved across the loaded week so the accent is stable
    // even on days with no lessons.
    final weekType = c.weekTypeForSelected;
    final weekNumber = c.weekNumberForSelected;
    // The week's colour (red = week 1, blue = week 2, grey when unknown).
    final accent = Brand.weekAccent(weekNumber, context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Расписание занятий'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_view_week),
            tooltip: 'Обзор недели',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ChangeNotifierProvider<ScheduleController>.value(
                    value: c,
                    child: const WeekSummaryPage(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      drawer: const AppDrawer(),
      body: Column(
        children: [
          if (c.fromCache) OfflineBanner(savedAt: c.cacheSavedAt),
          Container(
            color: accent,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left,
                      color: Colors.white, size: 30),
                  onPressed: c.prevDay,
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      _dayMonth.format(c.selectedDay).toUpperCase(),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right,
                      color: Colors.white, size: 30),
                  onPressed: c.nextDay,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${_full.format(c.selectedDay)} - ${_cap(_weekday.format(c.selectedDay))}',
            style: TextStyle(color: Brand.muted(context), fontSize: 15),
          ),
          if (weekType != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child:
                  _WeekTypeChip(name: weekType, number: weekNumber, dot: accent),
            ),
          const SizedBox(height: 8),
          Expanded(child: _body(context, c, accent)),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, ScheduleController c, Color accent) {
    // Horizontal swipe pages between days (left = next, right = previous),
    // matching the arrow buttons.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v < -250) {
          unawaited(c.nextDay());
        } else if (v > 250) {
          unawaited(c.prevDay());
        }
      },
      child: _content(context, c, accent),
    );
  }

  Widget _content(BuildContext context, ScheduleController c, Color accent) {
    final events = c.eventsForSelected;
    if (c.loading && events.isEmpty) {
      return const _ScheduleSkeleton();
    }
    if (c.error != null && events.isEmpty) {
      return _ErrorState(message: c.error!, onRetry: c.refresh);
    }
    if (events.isEmpty) {
      return RefreshIndicator(
        onRefresh: c.refresh,
        child: ListView(
          children: [
            const SizedBox(height: 80),
            Center(
              child: Text('Нет занятий',
                  style: TextStyle(color: Brand.muted(context), fontSize: 16)),
            ),
          ],
        ),
      );
    }
    // Merge lessons that share a time + room + subject (two groups together).
    final slots = groupParallelLessons(events);
    return RefreshIndicator(
      onRefresh: c.refresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        itemCount: slots.length,
        itemBuilder: (_, i) => _LessonCard(slots[i], accent: accent),
      ),
    );
  }
}

class _WeekTypeChip extends StatelessWidget {
  const _WeekTypeChip({required this.name, this.number, required this.dot});
  final String name;
  final int? number;
  final Color dot;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(
          number != null ? '$name · неделя $number' : name,
          style: TextStyle(color: Brand.muted(context), fontSize: 13),
        ),
      ],
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard(this.slot, {required this.accent});
  final LessonSlot slot;
  final Color accent;

  ScheduleEvent get e => slot.lead;

  IconData get _icon {
    switch (e.typeWorkName) {
      case 'Лекции':
        return Icons.menu_book_outlined; // open book — theory
      case 'Практические':
        return Icons.edit_outlined; // pencil — exercises / seminar
      case 'Лабораторные':
        return Icons.biotech_outlined; // microscope — lab work
      default:
        return Icons.event_note_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Brand.card(context),
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: accent, width: 5)),
        boxShadow: const [
          BoxShadow(color: Color(0x11000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(e.timeRange,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(e.roomLabel,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Brand.room(context))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_icon, size: 20, color: Brand.room(context)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.description ?? '',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500)),
                    _groups(context),
                    if ((e.fio ?? '').isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(e.fio!,
                            style: TextStyle(
                                fontSize: 13, color: Brand.muted(context))),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// One group → a plain line; several groups sharing this room/time → a
  /// «N групп» badge above the group chips, so it reads as one shared session.
  Widget _groups(BuildContext context) {
    final groups = slot.groups;
    if (groups.isEmpty) return const SizedBox.shrink();
    if (groups.length == 1) {
      return Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(groups.first,
            style: TextStyle(fontSize: 14, color: Brand.muted(context))),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.groups_outlined, size: 16, color: accent),
              const SizedBox(width: 4),
              Text(
                '${groups.length} ${pluralRu(groups.length, 'группа', 'группы', 'групп')} вместе',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: accent),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final g in groups)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(g,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off, size: 48, color: Brand.muted(context)),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Brand.muted(context))),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Обновить')),
          ],
        ),
      ),
    );
  }
}

/// Shimmering placeholder cards shown while the first week loads — calmer than a
/// bare spinner and hints at the list shape. No plugin: a moving gradient.
class _ScheduleSkeleton extends StatefulWidget {
  const _ScheduleSkeleton();

  @override
  State<_ScheduleSkeleton> createState() => _ScheduleSkeletonState();
}

class _ScheduleSkeletonState extends State<_ScheduleSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? const Color(0xFF2A2A2A) : const Color(0xFFE4E4E4);
    final hi = dark ? const Color(0xFF3A3A3A) : const Color(0xFFF2F2F2);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      itemCount: 5,
      itemBuilder: (_, __) => AnimatedBuilder(
        animation: _ac,
        builder: (context, _) {
          final t = _ac.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: 92,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(
                begin: Alignment(-1 - 2 * (1 - t), 0),
                end: Alignment(1 - 2 * (1 - t), 0),
                colors: [base, hi, base],
                stops: const [0.35, 0.5, 0.65],
              ),
            ),
          );
        },
      ),
    );
  }
}
