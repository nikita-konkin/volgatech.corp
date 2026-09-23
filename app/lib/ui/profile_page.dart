import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/ru_plural.dart';
import '../models/profile.dart';
import '../state/auth_controller.dart';
import '../theme.dart';
import 'widgets/person_avatar.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    // Refresh the full profile when opening (best-effort).
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => context.read<AuthController>().refreshProfile());
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final p = auth.profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: p == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => context.read<AuthController>().refreshProfile(),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Center(
                    child: PersonAvatar(
                      photoName: p.fileName,
                      radius: 56,
                      backgroundColor: Brand.blue,
                      iconColor: Colors.white,
                      iconSize: 56,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    p.personFIO ?? '—',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  if (p.birthday != null) ...[
                    _sectionTitle('Личная информация'),
                    _row(context, 'Дата рождения', _birthday(p.birthday!)),
                    const SizedBox(height: 12),
                  ],
                  if (p.salaries.isNotEmpty) ...[
                    _sectionTitle('Должность'),
                    if (p.rateTotalPercent > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Суммарная нагрузка: ${_num(p.rateTotalPercent)}%'
                          ' · ${_num(p.rateTotalPercent / 100)} ст.'
                          '${p.hasHourly ? ' + ≈${_num(p.hourlyHoursTotal.roundToDouble())} ч. почасовой' : ''}',
                          style: TextStyle(
                              fontSize: 13, color: Brand.muted(context)),
                        ),
                      ),
                    ...p.salariesMainFirst.map((s) => _row(
                          context,
                          s.postName ?? '—',
                          s.departmentName ?? '',
                          badge: s.isMainJob ? 'основное' : null,
                          meta: _postMeta(s),
                        )),
                  ],
                  if (p.experiences.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _sectionTitle('Стаж'),
                    ...p.experiences.map((e) => _row(
                          context,
                          e.typeName ?? '—',
                          humanYearsMonths(e.year, e.month),
                        )),
                  ],
                ],
              ),
            ),
    );
  }

  static final _dayMonth = DateFormat('dd MMMM', 'ru_RU');
  static String _birthday(DateTime d) => _dayMonth.format(d); // "05 февраля"

  static final _dmy = DateFormat('dd.MM.yyyy', 'ru_RU');

  /// "Ставка 100% · с 05.03.2026" (rate) or "Почасовая · ≈253 ч. · с …" (hourly).
  /// Hourly appointments never show a percentage — their number isn't a ставка;
  /// instead we show the approximate annual hours (salary% × norm).
  static String? _postMeta(SalaryEntry s) {
    final parts = <String>[
      if (s.isHourly) ...[
        'Почасовая',
        if ((s.hourlyHours ?? 0) >= 1)
          '≈${_num(s.hourlyHours!.roundToDouble())} ч.',
      ] else if (s.salary != null)
        'Ставка ${_num(s.salary!)}%',
      if (s.dateBegin != null) 'с ${_dmy.format(s.dateBegin!)}',
    ];
    return parts.isEmpty ? null : parts.join('  ·  ');
  }

  /// Trim a trailing ".0": 100.0 -> "100", 84.35 -> "84.35".
  static String _num(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: Brand.coral)),
      );

  Widget _row(BuildContext context, String title, String value,
          {String? badge, String? meta}) =>
      Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Brand.card(context),
          borderRadius: BorderRadius.circular(8),
          border: const Border(left: BorderSide(color: Brand.coral, width: 5)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
                if (badge != null)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Brand.coral.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(badge,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Brand.coral)),
                  ),
              ],
            ),
            if (value.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(value,
                    style:
                        TextStyle(fontSize: 14, color: Brand.muted(context))),
              ),
            if (meta != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(meta,
                    style:
                        TextStyle(fontSize: 12, color: Brand.muted(context))),
              ),
          ],
        ),
      );
}
