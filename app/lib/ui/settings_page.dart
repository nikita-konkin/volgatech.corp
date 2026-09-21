import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_lock.dart';
import '../state/theme_controller.dart';
import 'easter_egg.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Future<void> _toggleLock(BuildContext context, bool value) async {
    final lock = context.read<AppLock>();
    final messenger = ScaffoldMessenger.of(context);
    if (value) {
      final ok = await lock.enable();
      if (!ok) {
        messenger.showSnackBar(const SnackBar(
          content: Text(
              'Не удалось включить. Настройте отпечаток, Face ID или PIN в настройках устройства.'),
        ));
      }
    } else {
      await lock.disable();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    final lock = context.watch<AppLock>();
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Тема оформления',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          RadioGroup<ThemeMode>(
            groupValue: theme.mode,
            onChanged: (m) => theme.setMode(m!),
            child: const Column(
              children: [
                RadioListTile<ThemeMode>(
                  title: Text('Системная'),
                  value: ThemeMode.system,
                ),
                RadioListTile<ThemeMode>(
                  title: Text('Светлая'),
                  value: ThemeMode.light,
                ),
                RadioListTile<ThemeMode>(
                  title: Text('Тёмная'),
                  value: ThemeMode.dark,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Безопасность',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          SwitchListTile(
            title: const Text('Блокировка при входе'),
            subtitle: const Text(
                'Спрашивать отпечаток, Face ID или PIN при открытии приложения'),
            value: lock.enabled,
            onChanged: (v) => _toggleLock(context, v),
          ),
          const EasterEggFooter(),
        ],
      ),
    );
  }
}
