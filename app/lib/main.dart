import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/api_client.dart';
import 'core/app_lock.dart';
import 'core/cache.dart';
import 'core/photo_store.dart';
import 'core/prefs.dart';
import 'core/session.dart';
import 'data/volgatech_api.dart';
import 'mail/mail_badge.dart';
import 'mail/mail_config.dart';
import 'mail/mail_credentials.dart';
import 'state/auth_controller.dart';
import 'state/theme_controller.dart';
import 'state/updater.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru_RU', null);

  final session = Session();
  final client = ApiClient(session); // base: https://api.volgatech.net
  final api = VolgatechApi(client);
  final cache = JsonCache();
  final prefs = await Prefs.load();
  // A build without the mail client never keeps the mail password, even one
  // left behind by a MAIL build installed over before.
  if (!kNativeMail) unawaited(MailCredentialStore().clear());

  runApp(
    MultiProvider(
      providers: [
        Provider<Session>.value(value: session),
        Provider<VolgatechApi>.value(value: api),
        Provider<JsonCache>.value(value: cache),
        Provider<PhotoStore>.value(value: PhotoStore(api, cache)),
        Provider<Prefs>.value(value: prefs),
        ChangeNotifierProvider<ThemeController>(
          create: (_) => ThemeController(prefs),
        ),
        ChangeNotifierProvider<AppLock>(
          create: (_) => AppLock(prefs),
        ),
        ChangeNotifierProvider<Updater>(create: (_) => Updater(prefs: prefs)),
        if (kNativeMail)
          ChangeNotifierProvider<MailBadge>(
            create: (_) =>
                MailBadge(prefs: prefs, store: MailCredentialStore())..watch(),
          ),
        ChangeNotifierProvider<AuthController>(
          create: (_) {
            final auth = AuthController(api, session, cache);
            unawaited(auth.bootstrap());
            return auth;
          },
        ),
      ],
      child: const VolgatechApp(),
    ),
  );
}
