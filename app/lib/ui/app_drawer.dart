import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/cache.dart';
import '../core/photo_store.dart';
import '../mail/attachments.dart';
import '../mail/mail_badge.dart';
import '../mail/mail_config.dart';
import '../mail/mail_credentials.dart';
import '../mail/ui/mail_page.dart';
import '../state/auth_controller.dart';
import '../theme.dart';
import 'exams_page.dart';
import 'foreign_memo_page.dart';
import 'profile_page.dart';
import 'settings_page.dart';
import 'web_view_page.dart';
import 'widgets/person_avatar.dart';

/// External services opened in-app via WebView (see API_CONTRACT §6 — we
/// intentionally do NOT handle the corporate password; the WebView keeps only
/// the site's session cookie). The exception is the built-in mail client of
/// the MAIL build ([kNativeMail]), which has to keep the mail password.
const _portalUrl = 'https://portal.volgatech.net/';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  void _openWeb(BuildContext context, String title, String url) {
    Navigator.pop(context);
    if (kIsWeb) {
      // Already in a browser: the site in its own tab, signed in there.
      unawaited(launchUrl(Uri.parse(url), webOnlyWindowName: '_blank'));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
          builder: (_) => WebViewScreen(title: title, url: url)),
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
            leading: const Icon(Icons.translate, color: Brand.blue),
            title: const Text('Иностранные группы'),
            subtitle: const Text('служебная записка за месяц'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => const ForeignMemoPage()),
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
            trailing: kNativeMail ? const _UnreadCount() : null,
            onTap: kNativeMail
                ? () {
                    Navigator.pop(context);
                    Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => const MailPage()));
                  }
                : () => _openWeb(context, 'Почта', kWebMailUrl),
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
              await MailCredentialStore().clear();
              if (kNativeMail && context.mounted) {
                context.read<MailBadge>().set(0);
              }
              await clearAttachmentFiles();
              await authCtl.logout();
            },
          ),
        ],
      ),
    );
  }
}

/// Unread mail next to «Почта».
class _UnreadCount extends StatelessWidget {
  const _UnreadCount();

  @override
  Widget build(BuildContext context) {
    final n = context.watch<MailBadge>().unread;
    if (n == 0) return const SizedBox.shrink();
    return Badge(
      label: Text(n > 99 ? '99+' : '$n'),
      backgroundColor: Brand.coral,
      textColor: Colors.white,
    );
  }
}

/// The menu button, with a dot while there is unread mail.
class MenuButtonWithMail extends StatelessWidget {
  const MenuButtonWithMail({super.key});

  @override
  Widget build(BuildContext context) {
    final unread = kNativeMail && context.watch<MailBadge>().unread > 0;
    return IconButton(
      tooltip: 'Меню',
      icon: Badge(
        isLabelVisible: unread,
        smallSize: 9,
        backgroundColor: Brand.coral,
        child: const Icon(Icons.menu),
      ),
      onPressed: () => Scaffold.of(context).openDrawer(),
    );
  }
}
