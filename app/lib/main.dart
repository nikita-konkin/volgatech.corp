import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/api_client.dart';
import 'core/app_lock.dart';
import 'core/cache.dart';
import 'core/prefs.dart';
import 'core/session.dart';
import 'data/volgatech_api.dart';
import 'state/auth_controller.dart';
import 'state/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru_RU', null);

  final session = Session();
  final client = ApiClient(session); // base: https://api.volgatech.net
  final api = VolgatechApi(client);
  final cache = JsonCache();
  final prefs = await Prefs.load();

  runApp(
    MultiProvider(
      providers: [
        Provider<Session>.value(value: session),
        Provider<VolgatechApi>.value(value: api),
        Provider<JsonCache>.value(value: cache),
        Provider<Prefs>.value(value: prefs),
        ChangeNotifierProvider<ThemeController>(
          create: (_) => ThemeController(prefs),
        ),
        ChangeNotifierProvider<AppLock>(
          create: (_) => AppLock(prefs),
        ),
        ChangeNotifierProvider<AuthController>(
          create: (_) => AuthController(api, session, cache)..bootstrap(),
        ),
      ],
      child: const VolgatechApp(),
    ),
  );
}
