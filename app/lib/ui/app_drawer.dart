import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/cache.dart';
import '../core/photo_store.dart';
import '../state/auth_controller.dart';
import '../theme.dart';
import 'exams_page.dart';
import 'profile_page.dart';
import 'settings_page.dart';
import 'web_view_page.dart';
import 'widgets/person_avatar.dart';

/// External services opened in-app via WebView (see API_CONTRACT §6 — we
/// intentionally do NOT handle the corporate password; the WebView keeps only
/// the site's session cookie).
const _mailUrl = 'https://mail.volgatech.net/owa/';
const _portalUrl = 'https://portal.volgatech.net/';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  void _openWeb(BuildContext context, String title, String url) {
    Navigator.pop(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => WebViewScreen(title: title, url: url)),
    );
  }

  void _soon(BuildContext context) {
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Раздел в разработке')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final profile = auth.profile;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          InkWell(
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ProfilePage()),
              );
            },
            child: Container(
              color: Brand.blue,
              padding: const EdgeInsets.fromLTRB(16, 48, 16, 20),
              width: double.infinity,
              child: Column(
              children: [
                PersonAvatar(
                  photoName: profile?.photoName,
                  radius: 44,
                  backgroundColor: Colors.white,
                  iconColor: Brand.blue,
                  iconSize: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  (profile?.fullName ?? 'Профиль').toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person_outline, color: Brand.blue),
            title: const Text('Профиль'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ProfilePage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.calendar_month, color: Brand.blue),
            title: const Text('Расписание занятий'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.menu_book, color: Brand.blue),
            title: const Text('Расписание экзаменов'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const ExamsPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.mail_outline, color: Brand.blue),
            title: const Text('Мои обращения'),
            onTap: () => _soon(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.email, color: Brand.coral),
            title: const Text('Почта'),
            subtitle: const Text('mail.volgatech.net'),
            onTap: () => _openWeb(context, 'Почта', _mailUrl),
          ),
          ListTile(
            leading: const Icon(Icons.public, color: Brand.coral),
            title: const Text('Портал'),
            subtitle: const Text('portal.volgatech.net'),
            onTap: () => _openWeb(context, 'Портал', _portalUrl),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings, color: Colors.grey),
            title: const Text('Настройки'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.grey),
            title: const Text('Выход'),
            onTap: () async {
              final cache = context.read<JsonCache>();
              final photos = context.read<PhotoStore>();
              final authCtl = context.read<AuthController>();
              Navigator.pop(context);
              photos.clear();
              await cache.clear();
              await authCtl.logout();
            },
          ),
        ],
      ),
    );
  }
}
