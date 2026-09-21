import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_lock.dart';
import '../state/auth_controller.dart';
import '../theme.dart';

/// Full-screen cover shown while [AppLock] is locked. Prompts for the
/// fingerprint/PIN on appearance; offers "Выйти" as a guaranteed escape so the
/// lock can never trap the user out of their own app.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Pop the system auth prompt as soon as the lock appears.
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryUnlock());
  }

  Future<void> _tryUnlock() async {
    if (_busy) return;
    setState(() => _busy = true);
    await context.read<AppLock>().unlock();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _exit() async {
    final lock = context.read<AppLock>();
    final auth = context.read<AuthController>();
    await lock.disable(); // remove the lock so login is reachable
    await auth.logout(); // destroy the session — nothing sensitive is exposed
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // Opaque cover so no content shows behind the lock.
    return Material(
      color: dark ? Brand.bgDark : Brand.blue,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 64, color: Colors.white),
                const SizedBox(height: 20),
                const Text('Volgatech PRO',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Приложение заблокировано',
                    style: TextStyle(color: Colors.white70, fontSize: 15)),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _tryUnlock,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Разблокировать'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _busy ? null : _exit,
                  child: const Text('Выйти',
                      style: TextStyle(color: Colors.white70)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
