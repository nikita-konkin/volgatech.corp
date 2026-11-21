import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volgatech_pro/core/prefs.dart';
import 'package:volgatech_pro/core/updates.dart';
import 'package:volgatech_pro/state/updater.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('A disabled updater cannot check for a release', () async {
    SharedPreferences.setMockInitialValues({});
    var checks = 0;
    final updater = Updater(
      prefs: await Prefs.load(),
      enabled: false,
      installed: () async => (version: '0.0.0', code: 1000),
      fetchLatest: () async => checks++,
    );

    await updater.check(force: true);

    expect(checks, 0, reason: 'A disabled updater cannot call GitHub');
  });

  test('A disabled updater cannot start processing an available APK', () async {
    SharedPreferences.setMockInitialValues({});
    var attempts = 0;
    final updater = Updater(
      prefs: await Prefs.load(),
      enabled: false,
      folder: () async => throw StateError('${++attempts}'),
    );
    updater.release = AppRelease(
      version: '1.0.${Random().nextInt(100)}',
      pageUrl: '',
      apkName: 'app.apk',
      apkUrl: '',
      size: 1,
    );

    await updater.download();

    expect(attempts, 0, reason: 'A disabled updater cannot prepare an APK');
  });

  test('A disabled updater cannot show the update banner', () async {
    SharedPreferences.setMockInitialValues({});
    final updater = Updater(prefs: await Prefs.load(), enabled: false)
      ..release = AppRelease(
        version: '1.0.${Random().nextInt(100)}',
        pageUrl: '',
        apkName: 'app.apk',
        apkUrl: '',
        size: 1,
      )
      ..stage = UpdateStage.available;

    expect(updater.showBanner, isFalse,
        reason: 'A disabled updater cannot show an available release');
  });
}
