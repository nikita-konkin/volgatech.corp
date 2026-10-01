import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volgatech_pro/core/prefs.dart';
import 'package:volgatech_pro/core/updates.dart';
import 'package:volgatech_pro/state/updater.dart';
import 'package:volgatech_pro/ui/update_banner.dart';

const _base =
    'https://github.com/nikita-konkin/volgatech.corp/releases/download/v0.5.1';
final _apk = utf8.encode('not really an apk');

Map<String, dynamic> _release(
        {String tag = 'v0.5.1', String? digest, int? size}) =>
    {
      'tag_name': tag,
      'html_url':
          'https://github.com/nikita-konkin/volgatech.corp/releases/tag/$tag',
      'assets': [
        for (final name in [
          'app-arm64-v8a-release.apk',
          'app-mail-arm64-v8a-release.apk',
          'app-mail-armeabi-v7a-release.apk',
        ])
          {
            'name': name,
            'size': size ?? _apk.length,
            'browser_download_url': '$_base/$name',
            'digest': digest ?? 'sha256:${sha256.convert(_apk)}',
          },
      ],
    };

void main() {
  test('versions: a release over its betas, numbers compared as numbers', () {
    expect(isNewer('v0.5.1', '0.5.0'), isTrue);
    expect(isNewer('0.5.0', '0.5.0-beta.7'), isTrue);
    expect(isNewer('0.10.0', '0.9.9'), isTrue);
    expect(isNewer('1.0.0', '0.99.0'), isTrue);
    expect(isNewer('v0.5.0', '0.5.0'), isFalse);
    expect(isNewer('0.4.2', '0.5.0'), isFalse);
    expect(isNewer('0.5.0-beta.8', '0.5.0'), isFalse);
    expect(isNewer('nightly', '0.5.0'), isFalse);
  });

  test('the APK for this phone and this build', () {
    expect(abiFromVersionCode(2010), 'arm64-v8a');
    expect(abiFromVersionCode(1010), 'armeabi-v7a');
    expect(abiFromVersionCode(4010), 'x86_64');
    expect(abiFromVersionCode(10), isNull); // universal: not on the page
    expect(apkNameFor(mail: true, abi: 'arm64-v8a'),
        'app-mail-arm64-v8a-release.apk');
    expect(
        apkNameFor(mail: false, abi: 'arm64-v8a'), 'app-arm64-v8a-release.apk');

    final r = parseRelease(_release(), 'app-mail-arm64-v8a-release.apk')!;
    expect(r.version, '0.5.1');
    expect(r.apkUrl, '$_base/app-mail-arm64-v8a-release.apk');
    expect(r.size, _apk.length);
    expect(r.sha256, '${sha256.convert(_apk)}');
    expect(parseRelease(_release(), 'app-x86_64-release.apk'), isNull);
    expect(parseRelease('rate limited', 'app-arm64-v8a-release.apk'), isNull);

    // Only from this project's releases.
    final elsewhere = _release();
    ((elsewhere['assets'] as List).first
            as Map<String, dynamic>)['browser_download_url'] =
        'https://example.com/app-arm64-v8a-release.apk';
    expect(parseRelease(elsewhere, 'app-arm64-v8a-release.apk'), isNull);
    expect(megabytes(22954260), '21,9 МБ');
  });

  group('Updater', () {
    late Prefs prefs;
    late Directory dir;
    late Object? latest;
    late int fetches;
    late List<String> installed;
    late DateTime now;
    late InstalledBuild build;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await Prefs.load();
      dir = await Directory.systemTemp.createTemp('updates');
      latest = _release();
      fetches = 0;
      installed = [];
      now = DateTime(2026, 10, 1, 9);
      build = (version: '0.5.0', code: 2010);
    });
    tearDown(() => dir.delete(recursive: true));

    Updater updater({List<int>? bytes}) => Updater(
          prefs: prefs,
          enabled: true,
          mail: true,
          installed: () async => build,
          fetchLatest: () async {
            fetches++;
            if (latest case final Exception e) throw e;
            return latest;
          },
          download: (url, path, progress) async {
            expect(url, '$_base/app-mail-arm64-v8a-release.apk');
            final data = bytes ?? _apk;
            progress(data.length ~/ 2, data.length);
            await File(path).writeAsBytes(data);
            progress(data.length, data.length);
          },
          install: (path) async {
            installed.add(path);
            return null;
          },
          folder: () async => Directory('${dir.path}/updates'),
          now: () => now,
        );

    test('offers a newer release once, then waits a few hours', () async {
      final u = updater();
      expect(await u.check(), isTrue);
      expect(u.stage, UpdateStage.available);
      expect(u.release?.version, '0.5.1');
      expect(u.installedVersion, '0.5.0');
      expect(u.showBanner, isTrue);

      await u.check(); // just now: not asked again
      expect(fetches, 1);
      now = now.add(const Duration(hours: 7));
      await u.check();
      expect(fetches, 2);
      await u.check(force: true);
      expect(fetches, 3);
    });

    test('nothing to offer: same version, or a local universal build',
        () async {
      build = (version: '0.5.1', code: 2011);
      final same = updater();
      await same.check();
      expect(same.stage, UpdateStage.none);
      expect(same.showBanner, isFalse);

      build = (version: '0.5.0', code: 11);
      final universal = updater();
      await universal.check();
      expect(universal.stage, UpdateStage.none);
    });

    test('offline: says so when asked, keeps quiet otherwise', () async {
      latest = const SocketException('no network');
      final u = updater();
      expect(await u.check(force: true), isFalse);
      expect(u.stage, UpdateStage.none);
    });

    test('«Позже» puts that version off for the banner, not for Настройки',
        () async {
      final u = updater();
      await u.check();
      u.hideBanner();
      expect(u.showBanner, isFalse);
      expect(prefs.updateDismissed, '0.5.1');

      final next = updater(); // the app opened again
      await next.check();
      expect(next.stage, UpdateStage.available);
      expect(next.showBanner, isFalse);

      latest = _release(tag: 'v0.5.2'); // a later one is offered again
      await next.check(force: true);
      expect(next.showBanner, isTrue);
    });

    test('downloads, checks the file and opens the installer', () async {
      final u = updater();
      await u.check();
      final progress = <double>[];
      u.addListener(() => progress.add(u.progress));
      await u.download();
      expect(u.stage, UpdateStage.ready);
      expect(u.error, isNull);
      expect(progress.where((p) => p > 0 && p < 1), isNotEmpty);
      expect(progress.last, 1.0);
      expect(installed, ['${dir.path}/updates/app-mail-arm64-v8a-release.apk']);
      expect(await File(installed.single).readAsBytes(), _apk);

      // Installed and started again: the file is cleared away.
      build = (version: '0.5.1', code: 2011);
      await updater().check();
      expect(File(installed.single).existsSync(), isFalse);
    });

    test('a damaged download is thrown away, not installed', () async {
      final u = updater(bytes: utf8.encode('not really an apX'));
      await u.check();
      await u.download();
      expect(u.stage, UpdateStage.failed);
      expect(u.error, 'файл пришёл повреждённым');
      expect(installed, isEmpty);
      expect(Directory('${dir.path}/updates').listSync(), isEmpty); // deleted
      expect(u.showBanner, isTrue); // with «Повторить»
    });

    testWidgets('the banner: offer, download, install', (tester) async {
      late Updater u;
      await tester.runAsync(() async => u = updater());
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: u,
        child: MaterialApp(
          builder: (context, child) => UpdateWatcher(child: child!),
          home: const Scaffold(body: Text('Расписание')),
        ),
      ));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pumpAndSettle();
      expect(find.text('Доступна версия 0.5.1 · 0,0 МБ'), findsOneWidget);

      await tester.tap(find.text('Обновить'));
      // The file is really written: let real time pass between frames.
      for (var i = 0; i < 200 && u.stage != UpdateStage.ready; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(installed, hasLength(1));
      expect(find.text('Версия 0.5.1 загружена — осталось установить'),
          findsOneWidget);
      expect(find.text('Установить'), findsOneWidget);

      await tester.tap(find.text('Позже'));
      await tester.pumpAndSettle();
      expect(find.byType(MaterialBanner), findsNothing);
    });
  });
}
