import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../theme.dart';
import '../mail_controller.dart';
import '../mail_models.dart';

/// «Автоответ»: out-of-office replies, set in the mailbox itself (the same
/// setting as in Outlook), so they go out while the phone is off too.
class AutoReplyPage extends StatefulWidget {
  const AutoReplyPage({super.key});

  @override
  State<AutoReplyPage> createState() => _AutoReplyPageState();
}

class _AutoReplyPageState extends State<AutoReplyPage> {
  late Future<AutoReply> _loaded = _load();
  final _message = TextEditingController();
  bool _on = false;
  bool _dated = false;
  bool _external = true;
  late DateTimeRange _dates = _defaultDates();
  bool _saving = false;

  static DateTimeRange _defaultDates() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DateTimeRange(start: today, end: today.add(const Duration(days: 7)));
  }

  Future<AutoReply> _load() async {
    final r = await context.read<MailController>().autoReply();
    _on = r.state != AutoReplyState.off;
    _dated = r.state == AutoReplyState.scheduled;
    _external = r.external;
    _message.text = r.message;
    final start = r.start, end = r.end;
    if (start != null && end != null && end.isAfter(start)) {
      // Stored as [first day 00:00, day after the last 00:00).
      _dates = DateTimeRange(
          start: DateUtils.dateOnly(start),
          end: DateUtils.dateOnly(end.subtract(const Duration(minutes: 1))));
    }
    return r;
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _dates,
      helpText: 'Когда отвечать',
    );
    if (picked != null) setState(() => _dates = picked);
  }

  Future<void> _save() async {
    if (_on && _message.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Напишите текст автоответа')));
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await context.read<MailController>().setAutoReply(AutoReply(
            state: !_on
                ? AutoReplyState.off
                : _dated
                    ? AutoReplyState.scheduled
                    : AutoReplyState.on,
            start: _dates.start,
            // Through the whole of the last day.
            end: _dates.end.add(const Duration(days: 1)),
            message: _message.text,
            external: _external,
          ));
      navigator.pop();
      messenger.showSnackBar(SnackBar(
          content: Text(_on ? 'Автоответ включён' : 'Автоответ выключен')));
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text('Не сохранено: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Brand.muted(context);
    final day = DateFormat('d MMMM y', 'ru_RU');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Автоответ'),
        actions: [
          IconButton(
            tooltip: 'Сохранить',
            icon: _saving
                ? SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).appBarTheme.foregroundColor))
                : const Icon(Icons.check),
            onPressed: _saving ? null : () => unawaited(_save()),
          ),
        ],
      ),
      body: FutureBuilder<AutoReply>(
        future: _loaded,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Не удалось загрузить настройки',
                    style: TextStyle(color: muted)),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => setState(() => _loaded = _load()),
                  child: const Text('Повторить'),
                ),
              ]),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Отправлять автоответы'),
                subtitle: const Text('Например, в отпуске или командировке'),
                value: _on,
                onChanged: (v) => setState(() => _on = v),
              ),
              if (_on) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Только в эти дни'),
                  value: _dated,
                  onChanged: (v) => setState(() => _dated = v),
                ),
                if (_dated)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.date_range),
                    title: Text('${day.format(_dates.start)} — '
                        '${day.format(_dates.end)}'),
                    subtitle: const Text('Нажмите, чтобы изменить'),
                    onTap: () => unawaited(_pickDates()),
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: _message,
                  minLines: 4,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Текст автоответа',
                    hintText: 'Я в отпуске до …, отвечу после возвращения.',
                    alignLabelWithHint: true,
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Отвечать и на письма извне'),
                  subtitle: const Text('Не только из volgatech.net'),
                  value: _external,
                  onChanged: (v) => setState(() => _external = v),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Настройка хранится на почтовом сервере — та же, что в '
                'веб-почте, и работает, даже когда телефон выключен.',
                style: TextStyle(color: muted, fontSize: 12.5),
              ),
            ],
          );
        },
      ),
    );
  }
}
