import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../mail/mail_alerts.dart';
import '../mail/mail_background_settings.dart';

/// Controls background mail notifications and shows how to keep checks running.
class MailAlertTile extends StatelessWidget {
  const MailAlertTile({
    super.key,
    this.settings = const AndroidMailBackgroundSettings(),
  });

  final MailBackgroundSettings settings;

  Future<void> _set(BuildContext context, bool on) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await context.read<MailAlerts>().setEnabled(on);
    if (!ok) {
      messenger.showSnackBar(const SnackBar(
        content: Text(
            'Уведомления запрещены. Разрешите их приложению в настройках телефона.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final alerts = context.watch<MailAlerts>();
    final enabled = alerts.enabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          title: const Text('Новые письма'),
          subtitle:
              const Text('Проверять «Входящие» даже когда приложение закрыто'),
          value: enabled,
          onChanged: (v) => _set(context, v),
        ),
        if (enabled) ...[
          ListTile(
            title: const Text('Проверять почту'),
            trailing: DropdownButton<int>(
              value: alerts.checkMinutes,
              items: [
                for (final (minutes, label) in const [
                  (1, 'каждую минуту'),
                  (5, 'каждые 5 минут'),
                  (10, 'каждые 10 минут'),
                  (15, 'каждые 15 минут'),
                  (30, 'каждые 30 минут'),
                  (60, 'каждый час'),
                  (1440, 'раз в день'),
                ])
                  DropdownMenuItem(value: minutes, child: Text(label)),
              ],
              onChanged: (minutes) async {
                if (minutes != null) await alerts.setCheckMinutes(minutes);
              },
            ),
          ),
          if (alerts.checkMinutes < 15)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                  'Android может проверять реже, пока телефон не используется'),
            ),
          _MailBackgroundInfo(settings: settings),
        ],
      ],
    );
  }
}

/// Updates the check time and device settings on entry and after Android resumes.
class _MailBackgroundInfo extends StatefulWidget {
  const _MailBackgroundInfo({required this.settings});

  final MailBackgroundSettings settings;

  @override
  State<_MailBackgroundInfo> createState() => _MailBackgroundInfoState();
}

/// Tracks the latest preference read and the battery exemption state.
class _MailBackgroundInfoState extends State<_MailBackgroundInfo> {
  late final AppLifecycleListener _lifecycle;
  late Future<DateTime?> _lastCheck;
  late Future<({bool hasAppLaunch, bool canRequestBatteryExemption})> _status;

  @override
  void initState() {
    super.initState();
    _refresh();
    _lifecycle = AppLifecycleListener(onResume: () => setState(_refresh));
  }

  void _refresh() {
    _lastCheck = context.read<MailAlerts>().lastBackgroundCheck();
    _status = widget.settings.status();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _open(Future<bool> Function() action) async {
    if (await action() || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Не удалось открыть настройки телефона'),
    ));
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FutureBuilder(
              future: _lastCheck,
              builder: (context, snapshot) {
                final at = snapshot.data;
                if (at == null &&
                    snapshot.connectionState != ConnectionState.done) {
                  return const SizedBox.shrink();
                }
                final time = switch (at) {
                  final DateTime date =>
                    DateFormat('dd.MM.yyyy, HH:mm').format(date.toLocal()),
                  null when snapshot.hasError => 'не удалось прочитать',
                  null => 'ещё не было',
                };
                return Text('Последняя проверка в фоне: $time');
              },
            ),
            FutureBuilder(
              future: _status,
              builder: (context, snapshot) {
                final status = snapshot.data;
                if (status == null || !status.hasAppLaunch) {
                  return const SizedBox.shrink();
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    const Text('Если смахнуть приложение, телефон остановит '
                        'проверку почты. Разрешите работу в фоне в «Запуске приложений»'),
                    TextButton(
                      onPressed: () => _open(widget.settings.openAppLaunch),
                      child: const Text('Открыть «Запуск приложений»'),
                    ),
                    if (status.canRequestBatteryExemption)
                      TextButton(
                        onPressed: () =>
                            _open(widget.settings.requestBatteryExemption),
                        child: const Text('Отключить экономию батареи'),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      );
}
