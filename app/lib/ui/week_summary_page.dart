import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/week_summary.dart';
import '../models/schedule.dart';
import '../state/schedule_controller.dart';
import '../theme.dart';
import 'widgets/marquee_text.dart';

/// Whole-week overview (Пн–Вс): lessons per day, time span, gaps («окна»), and
/// tap-a-day to jump. Reads the already-loaded week from [ScheduleController] —
/// no extra network. Aggregation lives in `core/week_summary.dart` (unit-tested).
class WeekSummaryPage extends StatelessWidget {
  const WeekSummaryPage({super.key});

  static final _weekday = DateFormat('EEEE', 'ru_RU');
  static final _dayMonth = DateFormat('d MMM', 'ru_RU');
  static final _day = DateFormat('d', 'ru_RU');

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  static bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ScheduleController>();
    final days = c.weekDays;
    final accent = Brand.weekAccent(c.weekNumberForSelected, context);
    final weekType = c.weekTypeForSelected;
    final total = days.fold<int>(0, (s, d) => s + c.eventsOn(d).length);
    final range =
        '${_dayMonth.format(days.first)} – ${_dayMonth.format(days.last)}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Обзор недели'),
        bottom: c.loading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      // Swipe left → next week, right → previous week (like the day view).
      body: GestureDetector(
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v < -250) {
            c.nextWeek();
          } else if (v > 250) {
            c.prevWeek();
          }
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
          children: [
            _WeekHeader(
                range: range, total: total, weekType: weekType, accent: accent),
            const SizedBox(height: 8),
            for (final d in days)
              _DayCard(
                events: c.eventsOn(d),
                accent: accent,
                isToday: _isToday(d),
                weekdayLabel: _cap(_weekday.format(d)),
                dayNum: _day.format(d),
                onTap: () {
                  c.goToDay(d);
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader(
      {required this.range,
      required this.total,
      required this.weekType,
      required this.accent});
  final String range;
  final int total;
  final String? weekType;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Brand.card(context),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: accent, width: 5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(range,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                if (weekType != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                              color: accent, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text(weekType!,
                          style: TextStyle(
                              color: Brand.muted(context), fontSize: 13)),
                    ]),
                  ),
              ],
            ),
          ),
          Text(russianPairs(total),
              style: TextStyle(
                  color: accent, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.events,
    required this.accent,
    required this.isToday,
    required this.weekdayLabel,
    required this.dayNum,
    required this.onTap,
  });

  final List<ScheduleEvent> events;
  final Color accent;
  final bool isToday;
  final String weekdayLabel;
  final String dayNum;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = Brand.muted(context);
    final stats = DayStats.from(events);
    final footer = [
      if (stats.span.isNotEmpty) stats.span,
      if (stats.gapMinutes > 0) 'окна ${humanDuration(stats.gapMinutes)}',
    ].join('  ·  ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Brand.card(context),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isToday ? accent : Colors.transparent, width: 2),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0F000000), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(weekdayLabel,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: isToday ? accent : null)),
                  const SizedBox(width: 6),
                  Text(dayNum, style: TextStyle(color: muted, fontSize: 14)),
                  if (isToday)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text('сегодня',
                          style: TextStyle(
                              color: accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w500)),
                    ),
                  const Spacer(),
                  if (!stats.isEmpty)
                    Text(russianPairs(stats.count),
                        style: TextStyle(
                            color: muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
              if (stats.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Нет занятий',
                      style: TextStyle(color: muted, fontSize: 14)),
                )
              else ...[
                const SizedBox(height: 8),
                for (final e in events)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 44,
                          child: Text(
                            (e.timeBegin != null && e.timeBegin!.length >= 5)
                                ? e.timeBegin!.substring(0, 5)
                                : '',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                        Expanded(
                          child: MarqueeText(e.description ?? '',
                              style: const TextStyle(fontSize: 13)),
                        ),
                        const SizedBox(width: 6),
                        if ((e.room ?? '').isNotEmpty)
                          Text(e.room!,
                              style: TextStyle(
                                  color: Brand.room(context), fontSize: 13)),
                      ],
                    ),
                  ),
                if (footer.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(footer,
                        style: TextStyle(color: muted, fontSize: 12)),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
