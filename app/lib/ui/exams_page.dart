import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/cache.dart';
import '../data/volgatech_api.dart';
import '../models/exams.dart';
import '../state/auth_controller.dart';
import '../state/exams_controller.dart';
import '../theme.dart';
import 'offline_banner.dart';

class ExamsPage extends StatelessWidget {
  const ExamsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final api = context.read<VolgatechApi>();
    final cache = context.read<JsonCache>();
    final personId = context.read<AuthController>().personId ?? 0;
    return ChangeNotifierProvider(
      create: (_) {
        final c = ExamsController(api, personId, cache);
        unawaited(c.init());
        return c;
      },
      child: const _ExamsView(),
    );
  }
}

class _ExamsView extends StatelessWidget {
  const _ExamsView();

  static final _dateHeader = DateFormat('d MMMM y, EEEE', 'ru_RU');

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ExamsController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Расписание экзаменов')),
      body: Column(
        children: [
          if (c.fromCache) OfflineBanner(savedAt: c.cacheSavedAt),
          _yearPicker(context, c),
          Expanded(child: _body(context, c)),
        ],
      ),
    );
  }

  Widget _yearPicker(BuildContext context, ExamsController c) {
    if (c.years.isEmpty) return const SizedBox.shrink();
    return Container(
      color: Brand.coral,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const Text('Учебный год:',
              style: TextStyle(color: Colors.white, fontSize: 15)),
          const SizedBox(width: 12),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: c.selectedYear?.value,
              dropdownColor: Colors.white,
              iconEnabledColor: Colors.white,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16),
              selectedItemBuilder: (_) => c.years
                  .map((y) => Align(
                        alignment: Alignment.centerLeft,
                        child: Text(y.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                      ))
                  .toList(),
              items: c.years
                  .map((y) => DropdownMenuItem(
                        value: y.value,
                        child: Text(y.name,
                            style: const TextStyle(color: Colors.black87)),
                      ))
                  .toList(),
              onChanged: (v) {
                final y = c.years.firstWhere((e) => e.value == v);
                unawaited(c.selectYear(y));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, ExamsController c) {
    if ((c.loadingYears || c.loadingExams) && c.exams.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (c.error != null && c.exams.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off, size: 48, color: Brand.muted(context)),
              const SizedBox(height: 12),
              Text(c.error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Brand.muted(context))),
              const SizedBox(height: 16),
              OutlinedButton(
                  onPressed: c.refresh, child: const Text('Обновить')),
            ],
          ),
        ),
      );
    }
    if (c.exams.isEmpty) {
      return RefreshIndicator(
        onRefresh: c.refresh,
        child: ListView(children: [
          const SizedBox(height: 80),
          Center(
              child: Text('Нет экзаменов',
                  style: TextStyle(color: Brand.muted(context), fontSize: 16))),
        ]),
      );
    }

    // Group by calendar date.
    final sorted = [...c.exams]..sort((a, b) =>
        (a.examDate ?? DateTime(2100)).compareTo(b.examDate ?? DateTime(2100)));
    final groups = <String, List<Exam>>{};
    for (final e in sorted) {
      final d = e.examDate;
      final key = d != null ? '${d.year}-${d.month}-${d.day}' : '—';
      groups.putIfAbsent(key, () => []).add(e);
    }

    return RefreshIndicator(
      onRefresh: c.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        children: [
          for (final entry in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
              child: Text(
                entry.value.first.examDate != null
                    ? _cap(_dateHeader.format(entry.value.first.examDate!))
                    : 'Дата не указана',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Brand.room(context)),
              ),
            ),
            ...entry.value.map((e) => _ExamCard(e)),
          ],
        ],
      ),
    );
  }
}

class _ExamCard extends StatelessWidget {
  const _ExamCard(this.e);
  final Exam e;

  @override
  Widget build(BuildContext context) {
    final time =
        e.examDate != null ? DateFormat('HH:mm').format(e.examDate!) : '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Brand.card(context),
        borderRadius: BorderRadius.circular(8),
        border: const Border(left: BorderSide(color: Brand.coral, width: 5)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x11000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (time.isNotEmpty)
                Text(time,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(e.roomLabel,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Brand.room(context))),
            ],
          ),
          const SizedBox(height: 6),
          Text(e.subjectName ?? '',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          if ((e.groupName ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(e.groupName!,
                  style: TextStyle(fontSize: 14, color: Brand.muted(context))),
            ),
        ],
      ),
    );
  }
}
