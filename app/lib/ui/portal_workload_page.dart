import 'dart:async';

import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/hourly_load.dart';
import '../core/portal_workload.dart';
import '../core/portal_workload_batch.dart';
import '../core/portal_workload_save_progress.dart';
import '../data/portal_timetable_store.dart';
import '../data/portal_workload_client.dart';
import '../data/volgatech_api.dart';
import '../state/auth_controller.dart';
import 'layout.dart';
import 'portal_sign_in.dart';
import 'portal_workload_batch_review.dart';

const _departmentKey = 'portal_workload_department';

DateTime _moscowNow() => DateTime.now().toUtc().add(const Duration(hours: 3));

class PortalWorkloadPage extends StatefulWidget {
  const PortalWorkloadPage({super.key});

  @override
  State<PortalWorkloadPage> createState() => _PortalWorkloadPageState();
}

class _PortalWorkloadPageState extends State<PortalWorkloadPage> {
  late final PortalWorkloadClient _portal;
  PortalWorkloadReport? _report;
  Map<String, String> _selection = {};
  final _values = <String, String>{};
  String _semester = workloadSemesterLabels.first;
  int _revision = 0;
  bool _busy = false;
  bool _saving = false;
  double _saveProgress = 0;
  bool _signInRequired = false;
  bool _showLogin = false;
  bool _authDialog = false;
  bool _batchNeedsReload = false;
  String? _error;
  String? _batchProgress;

  @override
  void initState() {
    super.initState();
    _portal = PortalWorkloadClient(
      onSignedIn: () {
        if (!mounted || !_showLogin) return;
        setState(() => _showLogin = false);
        unawaited(_load());
      },
      onAuthRequest: (request) => unawaited(_authenticate(request)),
      onLoginFailure: _loginFailed,
    );
    unawaited(_load());
  }

  Future<void> _openLogin() async {
    setState(() => _showLogin = true);
    try {
      await _portal.openLogin(resume: true);
    } on PlatformException {
      _loginFailed(const PortalWorkloadFailure(
          'Не удалось открыть страницу входа.',
          signIn: true));
    }
  }

  void _loginFailed(PortalWorkloadFailure error) {
    _portal.cancelLogin();
    if (!mounted || !_showLogin) return;
    setState(() => _showLogin = false);
    _handle(error);
  }

  Future<void> _authenticate(HttpAuthRequest request) async {
    if (!mounted || !_showLogin || _authDialog) {
      request.onCancel();
      return;
    }
    _authDialog = true;
    var login = '';
    var password = '';
    final credential = await showDialog<WebViewCredential>(
      context: context,
      builder: (dialog) {
        void submit() {
          if (login.trim().isEmpty || password.isEmpty) return;
          Navigator.pop(dialog,
              WebViewCredential(user: login.trim(), password: password));
        }

        return AlertDialog(
          title: const Text('Вход на portal.volgatech.net'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                autofocus: true,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Логин'),
                onChanged: (value) => login = value,
              ),
              TextField(
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Пароль'),
                onChanged: (value) => password = value,
                onSubmitted: (_) => submit(),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialog),
                child: const Text('Отмена')),
            FilledButton(onPressed: submit, child: const Text('Войти')),
          ],
        );
      },
    );
    _authDialog = false;
    if (credential == null || !mounted || !_showLogin) {
      request.onCancel();
    } else {
      request.onProceed(credential);
    }
  }

  void _setReport(PortalWorkloadReport report, {Set<String>? submitted}) {
    final previous = _report;
    _report = report;
    _selection = report.selection;
    if (submitted == null) {
      final month = report.month;
      if (month != null && month != previous?.month) {
        _semester = workloadSemesterForMonth(month);
      }
      _values.clear();
    } else {
      final before = {
        for (final cell in previous!.cells) cell.key: cell.amount
      };
      final after = {for (final cell in report.cells) cell.key: cell.amount};
      _values.removeWhere(
          (key, _) => submitted.contains(key) || before[key] != after[key]);
    }
    _revision++;
  }

  Future<void> _load(
      {Map<String, String>? selection, bool fresh = false}) async {
    final auth = context.read<AuthController>();
    final api = context.read<VolgatechApi>();
    final personId = auth.personId;
    setState(() {
      _busy = true;
      _signInRequired = false;
      _error = null;
      if (selection != null) _selection = selection;
    });
    try {
      var report = await _portal.load(selection: _selection, fresh: fresh);
      final name = auth.profile?.fullName ??
          (personId == null
              ? null
              : (await api.getPersonInfo(personId)).fullName);
      final portalName = report.filters['person']!.selected.label;
      if (!mounted || auth.personId != personId) return;
      if (name == null ||
          portalName.isEmpty ||
          workloadName(portalName) != workloadName(name)) {
        throw const PortalWorkloadFailure(
            'Преподаватель на портале не совпадает с профилем приложения.');
      }
      final preferences = await SharedPreferences.getInstance();
      if (_report == null && selection == null) {
        final wanted = workloadSelection(report, workloadMonth(_moscowNow()),
            department: preferences.getString(_departmentKey));
        if (!mapEquals(wanted, report.selection)) {
          report = await _portal.load(selection: wanted);
        }
      }
      if (!mounted || auth.personId != personId) return;
      await preferences.setString(
          _departmentKey, report.selection['department']!);
      if (!mounted || auth.personId != personId) return;
      if (personId != null) {
        final timetable = context.read<PortalTimetableStore>();
        unawaited(timetable.refresh(personId, _portal.readTimetable));
      }
      final loaded = report;
      setState(() {
        final preserve = _batchNeedsReload && loaded.scope == _report?.scope;
        _setReport(loaded, submitted: preserve ? const {} : null);
        _batchNeedsReload = false;
      });
    } on PortalWorkloadFailure catch (error) {
      _handle(error);
    } on Exception {
      _handle(const PortalWorkloadFailure(
          'Не удалось загрузить учебную нагрузку.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _handle(PortalWorkloadFailure error) {
    if (!mounted) return;
    setState(() {
      _error =
          error == PortalWorkloadFailure.signInRequired ? null : error.message;
      _signInRequired = error.signIn;
    });
  }

  void _notice(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Map<String, int> _changes(Iterable<PortalWorkloadCell> cells) => {
        for (final cell in cells)
          if (_values[cell.key] case final text?)
            if (parseWorkloadHours(text) case final amount?)
              if (amount != cell.amount) cell.key: amount,
      };

  bool get _hasEdits {
    final report = _report;
    return report != null &&
        (_changes(report.cells).isNotEmpty ||
            _values.values.any((value) => parseWorkloadHours(value) == null));
  }

  Future<bool> _confirm(String title, String text, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(child: Text(text)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: const Text('Отмена')),
            FilledButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: Text(action)),
          ],
        ),
      ) ??
      false;

  Future<void> _changePeriod([String? filter, String? value]) async {
    if (_busy) return;
    if (_hasEdits &&
        !await _confirm('Сменить период?',
            'Изменения в форме ещё не сохранены.', 'Продолжить')) {
      return;
    }
    if (!mounted) return;
    final selection = {...?_report?.selection};
    if (filter != null && value != null) {
      selection[filter] = value;
      if (filter == 'year' || filter == 'department') selection.remove('month');
      if (filter == 'department') selection.remove('year');
    }
    await _load(selection: selection, fresh: filter == null);
  }

  Future<void> _autofill(
      PortalWorkloadReport report, List<PortalWorkloadCell> cells) async {
    final auth = context.read<AuthController>();
    final api = context.read<VolgatechApi>();
    final personId = auth.personId;
    final month = report.month;
    if (personId == null || month == null) return;
    final today = _moscowNow();
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    if (yesterday.isBefore(month)) {
      _notice('В выбранном месяце ещё нет прошедших дней.');
      return;
    }
    final end = DateTime(month.year, month.month + 1, 0);
    setState(() => _busy = true);
    try {
      final days = await api.getSchedule(
          personId, month, yesterday.isBefore(end) ? yesterday : end);
      if (!mounted || auth.personId != personId) return;
      final timetable = context.read<PortalTimetableStore>().read(personId);
      final classes = hourlyClassesFrom(days, studyForm: timetable.formFor);
      final split =
          departmentWorkload(monthlyWorkload(classes, month, today), cells);
      final totals = split.shown;
      if (totals.isEmpty) {
        _notice(split.hidden.isEmpty
            ? 'В расписании за прошедшие дни месяца нет занятий для заполнения.'
            : 'В расписании за прошедшие дни месяца нет занятий по дисциплинам этой кафедры.');
        return;
      }
      final occupied = {
        for (final cell in cells)
          if (parseWorkloadHours(_values[cell.key] ?? '') != 0) cell.key,
      };
      final changes = await Navigator.of(context).push<Map<String, int>>(
        MaterialPageRoute(
          builder: (_) => _WorkloadReview(
            totals,
            [
              for (final total in totals)
                workloadTargets(total, cells, month, occupied: occupied),
            ],
            occupied,
            split.hidden,
          ),
        ),
      );
      if (!mounted || changes == null || auth.personId != personId) return;
      setState(() {
        _revision++;
        _values.addAll(
            changes.map((key, value) => MapEntry(key, value.toString())));
      });
    } on ApiException catch (error) {
      _notice(error.message);
    } on Exception {
      _notice('Не удалось загрузить часы из расписания.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openBatch(PortalWorkloadReport original) async {
    final auth = context.read<AuthController>();
    final api = context.read<VolgatechApi>();
    final personId = auth.personId;
    final month = original.month;
    if (_busy || personId == null) return;
    if (month == null) {
      _notice('Не удалось определить выбранный месяц.');
      return;
    }
    if (_hasEdits &&
        !await _confirm(
            'Перейти к заполнению нескольких месяцев?',
            'Изменения в открытой форме ещё не сохранены. Для нескольких месяцев будут предложены часы из расписания.',
            'Продолжить')) {
      return;
    }
    if (!mounted || auth.personId != personId || _busy) return;
    final today = _moscowNow();
    final options =
        workloadBatchMonths(month, today, original.filters['month']!.options);
    if (options.isEmpty) {
      _notice('В этом семестре нет доступных месяцев с прошедшими днями.');
      return;
    }
    final last = options.last.month;
    final end = DateTime(last.year, last.month + 1, 0);
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final typed = {
      for (final cell in original.cells)
        if (_values.containsKey(cell.key)) workloadCellIdentity(cell),
    };
    setState(() {
      _busy = true;
      _error = null;
      _batchProgress = 'Загружаем расписание…';
    });
    final reports = <String, PortalWorkloadReport>{};
    var restore = false;
    String? result;
    try {
      final days = await api.getSchedule(personId, options.first.month,
          yesterday.isBefore(end) ? yesterday : end);
      if (!mounted || auth.personId != personId) return;
      final timetable = context.read<PortalTimetableStore>().read(personId);
      final classes = hourlyClassesFrom(days, studyForm: timetable.formFor);
      final totals = {
        for (final option in options)
          option.value: monthlyWorkload(classes, option.month, today),
      };
      setState(() => _batchProgress = null);
      final checked = await showDialog<List<WorkloadBatchOption>>(
        context: context,
        builder: (_) => WorkloadBatchChecklist([
          for (final option in options)
            (
              option: option,
              hours: departmentWorkload(totals[option.value]!, original.cells)
                  .shown
                  .fold(0, (sum, total) => sum + total.hours),
            ),
        ]),
      );
      if (!mounted || auth.personId != personId || checked == null) return;
      final months = <WorkloadBatchMonth>[];
      for (final option in checked) {
        setState(() => _batchProgress = 'Загружаем ${option.label}…');
        restore = true;
        final selection = {...original.selection, 'month': option.value};
        final report = await _portal.load(selection: selection);
        if (!mounted || auth.personId != personId) return;
        if (!mapEquals(report.selection, selection) ||
            report.month != option.month ||
            report.filters['person']!.selected !=
                original.filters['person']!.selected) {
          throw PortalWorkloadFailure(
              'Портал открыл другую форму вместо «${option.label}».');
        }
        reports[option.value] = report;
        months.add(WorkloadBatchMonth(
          option,
          totals[option.value]!,
          report.cells,
          occupied: {
            if (option.month == month)
              for (final cell in report.cells)
                if (_values.containsKey(cell.key) ||
                    typed.contains(workloadCellIdentity(cell)))
                  cell.key,
          },
        ));
      }
      setState(() => _batchProgress = null);
      final changes =
          await Navigator.of(context).push<List<WorkloadMonthChanges>>(
        MaterialPageRoute(
          builder: (_) => WorkloadBatchReview(WorkloadBatch(months)),
        ),
      );
      if (!mounted || auth.personId != personId || changes == null) return;
      final confirmed = await _confirm(
        'Сохранить на портале?',
        [
          for (final month in changes) ...[
            month.option.label,
            if (month.amounts.isEmpty) 'Нет изменений.',
            ...month.descriptions,
            'Итого за месяц: ${formatWorkloadHours(month.total)} ч.',
            '',
          ],
          'Итого за все месяцы: ${formatWorkloadHours(workloadBatchTotal(changes))} ч.',
        ].join('\n'),
        'Сохранить',
      );
      if (!mounted || auth.personId != personId || !confirmed) return;
      result = await _saveBatch(changes, reports, auth, personId);
    } on ApiException catch (error) {
      _notice(error.message);
    } on PortalWorkloadFailure catch (error) {
      _handle(error);
    } on Exception {
      _handle(PortalWorkloadFailure(_batchProgress == null
          ? 'Не удалось подготовить нагрузку за несколько месяцев.'
          : '$_batchProgress Не удалось завершить загрузку.'));
    } finally {
      if (restore && mounted && auth.personId == personId) {
        await _restoreBatchMonth(original, auth, personId);
      }
      if (mounted) {
        setState(() {
          _batchProgress = null;
          _saving = false;
          _busy = false;
        });
      }
    }
    if (!mounted || auth.personId != personId || result == null) return;
    final restoreError = _batchNeedsReload ? _error : null;
    await showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Сохранение нагрузки'),
        content: SingleChildScrollView(
          child: Text(
              [result, if (restoreError != null) restoreError].join('\n\n')),
        ),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('Закрыть')),
        ],
      ),
    );
  }

  Future<String?> _saveBatch(
    List<WorkloadMonthChanges> changes,
    Map<String, PortalWorkloadReport> reports,
    AuthController auth,
    int personId,
  ) async {
    final pending = changes.where((month) => month.amounts.isNotEmpty).toList();
    final labels = [for (final month in pending) month.option.label];
    final unchanged = [
      for (final month in changes)
        if (month.amounts.isEmpty) month.option.label,
    ];
    setState(() {
      _saving = true;
      _saveProgress = 0;
    });
    var verified = 0;
    String? failure;
    try {
      for (final month in pending) {
        setState(
            () => _batchProgress = workloadBatchProgress(labels, verified));
        final before = reports[month.option.value]!;
        final after = await _portal.submit(
          before,
          month.amounts,
          onProgress: (completedStages) {
            if (!mounted || auth.personId != personId) return;
            setState(() {
              _saveProgress = workloadSaveProgress(
                months: pending.length,
                completedMonths: verified,
                completedStages: completedStages,
              );
            });
          },
        );
        if (!mounted || auth.personId != personId) return null;
        if (after.scope != before.scope) {
          throw const PortalWorkloadFailure(
              'После отправки портал открыл другую форму.');
        }
        final count = month.verifiedCount(after.cells);
        if (count != month.amounts.length) {
          throw PortalWorkloadFailure(
              'Портал подтвердил $count из ${month.amounts.length} полей.');
        }
        verified++;
      }
    } on PortalWorkloadFailure catch (error) {
      failure = error.message;
    } on Exception {
      failure = 'Не удалось проверить сохранение.';
    }
    return [
      workloadBatchResult(labels, verified, unchanged: unchanged),
      if (failure != null) failure,
    ].join('\n');
  }

  Future<void> _restoreBatchMonth(
      PortalWorkloadReport original, AuthController auth, int personId) async {
    final label = original.filters['month']!.selected.label;
    setState(() => _batchProgress = 'Обновляем $label…');
    PortalWorkloadFailure? failure;
    try {
      final report =
          await _portal.load(selection: original.selection, fresh: true);
      if (!mounted || auth.personId != personId) return;
      if (report.scope != original.scope) {
        throw const PortalWorkloadFailure('Портал открыл другую форму.');
      }
      setState(() {
        _setReport(report, submitted: const {});
        _signInRequired = false;
      });
    } on PortalWorkloadFailure catch (error) {
      failure = error;
    } on Exception {
      failure = const PortalWorkloadFailure('Повторите загрузку.');
    }
    if (failure == null || !mounted || auth.personId != personId) return;
    setState(() => _batchNeedsReload = true);
    _handle(PortalWorkloadFailure(
        'Не удалось обновить «$label». ${failure.message}',
        signIn: failure.signIn));
  }

  Future<void> _save(
      PortalWorkloadReport report, Map<String, int> changes) async {
    final auth = context.read<AuthController>();
    final id = auth.personId;
    final month = report.filters['month']!.selected.label;
    final cells = {for (final cell in report.cells) cell.key: cell};
    final total = changes.values.fold(0, (sum, amount) => sum + amount);
    if (id == null ||
        !await _confirm(
            'Сохранить на портале?',
            [
              '$month · $_semester',
              '',
              for (final entry in changes.entries)
                workloadChange(cells[entry.key]!, entry.value),
              '',
              'Итого в этих полях: ${formatWorkloadHours(total)} ч.',
            ].join('\n'),
            'Сохранить')) {
      return;
    }
    if (!mounted || auth.personId != id) return;
    setState(() {
      _busy = true;
      _saving = true;
      _saveProgress = 0;
      _error = null;
    });
    try {
      final verified = await _portal.submit(
        report,
        changes,
        onProgress: (completedStages) {
          if (!mounted || auth.personId != id) return;
          setState(() {
            _saveProgress = workloadSaveProgress(
              months: 1,
              completedMonths: 0,
              completedStages: completedStages,
            );
          });
        },
      );
      if (!mounted || auth.personId != id) return;
      final saved = {for (final cell in verified.cells) cell.key: cell.amount};
      final count = changes.entries
          .where((entry) => saved[entry.key] == entry.value)
          .length;
      setState(() {
        _setReport(verified, submitted: changes.keys.toSet());
        if (count != changes.length) {
          _error = 'Портал подтвердил $count из ${changes.length} полей. '
              'В форме показаны текущие значения с портала.';
        }
      });
      if (count == changes.length) _notice('Изменения сохранены.');
    } on PortalWorkloadFailure catch (error) {
      _handle(error);
    } on Exception {
      _handle(const PortalWorkloadFailure(
          'Не удалось проверить сохранение. Обновите месяц перед повторной отправкой.'));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showLogin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Вход на портал'),
          leading: BackButton(onPressed: () {
            _portal.cancelLogin();
            setState(() => _showLogin = false);
          }),
        ),
        body: WebViewWidget(controller: _portal.controller),
      );
    }
    final report = _report;
    final canEdit =
        report != null && !_busy && !_signInRequired && !_batchNeedsReload;
    final cells = [
      for (final cell in report?.cells ?? const <PortalWorkloadCell>[])
        if (cell.semester == _semester) cell,
    ];
    final changes = _changes(cells);
    final invalid = cells
        .any((cell) => parseWorkloadHours(_values[cell.key] ?? '') == null);
    final month = report?.month;
    final canAutofill = canEdit &&
        cells.isNotEmpty &&
        month != null &&
        _semester == workloadSemesterForMonth(month);
    return PopScope(
      canPop: !_saving && !_hasEdits,
      onPopInvokedWithResult: (popped, _) async {
        if (popped || _saving) return;
        final leave = await _confirm('Выйти без сохранения?',
            'Изменения в форме ещё не сохранены.', 'Выйти');
        if (leave && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Учебная нагрузка'),
          actions: [
            IconButton(
              tooltip: 'Обновить',
              onPressed: _busy || _signInRequired ? null : _changePeriod,
              icon: const Icon(Icons.refresh),
            ),
          ],
          bottom: _busy
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: _saving
                      ? LinearProgressIndicator(
                          minHeight: 3, value: _saveProgress)
                      : const LinearProgressIndicator())
              : null,
        ),
        body: Column(
          children: [
            if (_batchProgress case final progress?)
              ReadableWidth(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(progress, textAlign: TextAlign.center),
                ),
              ),
            Expanded(
              child: _signInRequired || _batchNeedsReload || report == null
                  ? _connection()
                  : _form(report, cells, canEdit),
            ),
          ],
        ),
        bottomNavigationBar: report == null ||
                _signInRequired ||
                _batchNeedsReload
            ? null
            : SafeArea(
                top: false,
                child: ReadableWidth(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OutlinedButton.icon(
                          onPressed: canAutofill
                              ? () => _autofill(report, cells)
                              : null,
                          icon: const Icon(Icons.edit_calendar_outlined),
                          label: const Text('Заполнить из расписания'),
                        ),
                        OutlinedButton(
                          onPressed: canEdit ? () => _openBatch(report) : null,
                          child: const Text('Несколько месяцев'),
                        ),
                        FilledButton(
                          onPressed: canEdit && !invalid && changes.isNotEmpty
                              ? () => _save(report, changes)
                              : null,
                          child: Text(
                              _saving ? 'Сохраняем…' : 'Сохранить на портале'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _connection() {
    if (_signInRequired && !_busy) {
      return PortalSignIn(
        signIn: _portal.signIn,
        onSignedIn: () => unawaited(_load()),
        onUnexpected: () => unawaited(_openLogin()),
        message: _error,
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: _busy
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_error != null)
                    Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => _load(fresh: true),
                    child: const Text('Повторить'),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _form(PortalWorkloadReport report, List<PortalWorkloadCell> cells,
      bool canEdit) {
    final rows = <String, List<PortalWorkloadCell>>{};
    for (final cell in cells) {
      rows.putIfAbsent(cell.rowKey, () => []).add(cell);
    }
    final groups = rows.values.toList();
    final style = Theme.of(context).textTheme;
    final form = ListView.builder(
      key: PageStorageKey(('workload', _semester)),
      padding: readable(context, const EdgeInsets.fromLTRB(16, 12, 16, 16)),
      itemCount: groups.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (report.filters['department']!.options.length > 1)
                  _filter(report, 'department', 'Кафедра', canEdit),
                _filter(report, 'year', 'Учебный год', canEdit),
                _filter(report, 'month', 'Месяц', canEdit),
                if (_error != null)
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                if (groups.isEmpty)
                  const Text(
                      'За выбранный месяц в этом семестре нет нагрузки.'),
              ],
            ),
          );
        }
        final group = groups[index - 1];
        final first = group.first;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(first.discipline, style: style.titleMedium),
                Text(first.specialty, style: style.bodySmall),
                Text(first.appointment, style: style.bodySmall),
                for (final cell in group)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Expanded(
                            child: Text(workloadColumnLabels[cell.column]!)),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 108,
                          child: TextFormField(
                            key: ValueKey((cell.key, _revision)),
                            initialValue: _values[cell.key] ??
                                formatWorkloadHours(cell.amount),
                            enabled: canEdit,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'[\d,.]'))
                            ],
                            onChanged: (value) =>
                                setState(() => _values[cell.key] = value),
                            decoration: InputDecoration(
                              isDense: true,
                              suffixText: 'ч.',
                              errorText:
                                  parseWorkloadHours(_values[cell.key] ?? '') ==
                                          null
                                      ? 'До 2 знаков'
                                      : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
    final semesters = {
      ...workloadSemesterLabels,
      _semester,
      for (final cell in report.cells) cell.semester,
    };
    return Column(
      children: [
        Padding(
          padding: readable(context, const EdgeInsets.fromLTRB(16, 8, 16, 0)),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final semester in semesters)
                ChoiceChip(
                  label: Text(semester),
                  selected: semester == _semester,
                  onSelected: canEdit
                      ? (_) {
                          FocusScope.of(context).unfocus();
                          setState(() => _semester = semester);
                        }
                      : null,
                ),
            ],
          ),
        ),
        Expanded(child: form),
      ],
    );
  }

  Widget _filter(
      PortalWorkloadReport report, String name, String label, bool enabled) {
    final filter = report.filters[name]!;
    final options = {filter.selected.value: filter.selected.label};
    for (final option in filter.options) {
      options[option.value] = option.label;
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, isDense: true),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            isDense: true,
            value: filter.selected.value,
            onChanged: enabled && options.length > 1
                ? (value) => _changePeriod(name, value)
                : null,
            items: [
              for (final option in options.entries)
                DropdownMenuItem(value: option.key, child: Text(option.value)),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkloadReview extends StatefulWidget {
  const _WorkloadReview(this.totals, this.choices, this.occupied, this.hidden);

  final List<WorkloadTotal> totals;
  final List<WorkloadTargetOptions> choices;
  final Set<String> occupied;
  final List<WorkloadTotal> hidden;

  @override
  State<_WorkloadReview> createState() => _WorkloadReviewState();
}

class _WorkloadReviewState extends State<_WorkloadReview> {
  late final _targets = [
    for (final item in widget.choices) item.suggested ?? ''
  ];

  bool _canFill(PortalWorkloadCell cell) =>
      cell.available && !widget.occupied.contains(cell.key);

  @override
  Widget build(BuildContext context) {
    final draft = <String, int>{};
    for (var i = 0; i < _targets.length; i++) {
      final key = _targets[i];
      if (key.isEmpty) continue;
      final hours = widget.totals[i].hours;
      draft.update(key, (value) => value + hours, ifAbsent: () => hours);
    }
    final hours = draft.values.fold(0, (sum, value) => sum + value);
    final offset = widget.hidden.isEmpty ? 0 : 1;
    return Scaffold(
      appBar: AppBar(title: const Text('Из расписания')),
      body: ListView.separated(
        padding: readable(context, const EdgeInsets.all(16)),
        itemCount: widget.totals.length + offset,
        separatorBuilder: (_, __) => const Divider(height: 24),
        itemBuilder: (context, position) {
          if (position < offset) {
            return WorkloadHiddenSummary(widget.hidden);
          }
          final index = position - offset;
          final total = widget.totals[index];
          final options = widget.choices[index];
          final choices = options.choices.where(_canFill).toList();
          final target = _targets[index];
          final dates =
              total.dates.toSet().map(DateFormat('dd.MM').format).join(', ');
          final kind = workloadColumnLabels[total.column];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(total.discipline,
                  style: Theme.of(context).textTheme.titleSmall),
              Text('$kind · ${total.groups.join(', ')} · ${total.hours} ч.'),
              Text(dates, style: Theme.of(context).textTheme.bodySmall),
              if (!options.sameDiscipline)
                Text('В нагрузке портала нет поля «$kind» для этой дисциплины.')
              else if (choices.isEmpty)
                const Text('Подходящие поля уже заполнены.'),
              if (choices.isNotEmpty)
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    itemHeight: null,
                    style: Theme.of(context).textTheme.bodyMedium,
                    value: target.isEmpty ? null : target,
                    hint: Text(options.sameDiscipline
                        ? 'Выбрать строку портала'
                        : 'Сопоставить с другой дисциплиной'),
                    onChanged: (value) =>
                        setState(() => _targets[index] = value ?? ''),
                    items: [
                      const DropdownMenuItem(
                          value: '', child: Text('Пропустить')),
                      for (final cell in choices)
                        DropdownMenuItem(
                          value: cell.key,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              '${cell.specialty} · ${cell.appointment}'
                              '${options.sameDiscipline ? '' : ' · ${cell.discipline}'}',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 3,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: ReadableWidth(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: FilledButton(
              onPressed:
                  draft.isEmpty ? null : () => Navigator.pop(context, draft),
              child: Text('Перенести в форму · $hours ч.'),
            ),
          ),
        ),
      ),
    );
  }
}
