import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../core/prefs.dart';
import '../core/updates.dart';
import '../mail/mail_config.dart';

enum UpdateStage { none, available, downloading, ready, failed }

/// The installed build: its version name and code.
typedef InstalledBuild = ({String version, int code});

/// Looks for a newer release on GitHub, fetches its APK for this phone, and
/// opens Android's installer with it. The installer only accepts an APK
/// signed with the same key as the installed app, so a file from anywhere
/// else can't replace it.
class Updater extends ChangeNotifier {
  Updater({
    required Prefs prefs,
    bool? enabled,
    bool mail = kNativeMail,
    Future<InstalledBuild> Function()? installed,
    Future<Object?> Function()? fetchLatest,
    Future<void> Function(String url, String path,
            void Function(int got, int total) progress)?
        download,
    Future<String?> Function(String path)? install,
    Future<Directory> Function()? folder,
    DateTime Function()? now,
  })  : _prefs = prefs,
        enabled = enabled ?? (!kIsWeb && Platform.isAndroid),
        _mail = mail,
        _installed = installed ?? _installedBuild,
        _fetchLatest = fetchLatest ?? _fetchFromGitHub,
        _download = download ?? _downloadWithDio,
        _install = install ?? _openInstaller,
        _folder = folder ?? _updatesFolder,
        _now = now ?? DateTime.now;

  final Prefs _prefs;

  /// Android only: elsewhere there is no APK to install.
  final bool enabled;
  final bool _mail;
  final Future<InstalledBuild> Function() _installed;
  final Future<Object?> Function() _fetchLatest;
  final Future<void> Function(
      String url, String path, void Function(int, int) progress) _download;
  final Future<String?> Function(String path) _install;
  final Future<Directory> Function() _folder;
  final DateTime Function() _now;

  /// Asked again on returning to the app only after this long.
  static const recheckAfter = Duration(hours: 6);

  UpdateStage stage = UpdateStage.none;

  /// The newer release, while there is one.
  AppRelease? release;
  String? installedVersion;
  bool checking = false;

  /// Share of the download done, 0…1.
  double progress = 0;

  /// What went wrong downloading or opening the installer.
  String? error;

  String? _apk;
  DateTime? _checkedAt;
  bool _bannerHidden = false;

  /// Asks GitHub for the latest release, at most every [recheckAfter] unless
  /// [force]d. False when it couldn't be asked.
  Future<bool> check({bool force = false}) async {
    if (!enabled || checking) return true;
    if (stage == UpdateStage.downloading || stage == UpdateStage.ready) {
      return true;
    }
    final at = _checkedAt;
    if (!force && at != null && _now().difference(at) < recheckAfter) {
      return true;
    }
    checking = true;
    notifyListeners();
    try {
      final build = await _installed();
      installedVersion = build.version;
      final abi = abiFromVersionCode(build.code);
      // A universal APK (a local build) has nothing to be replaced with.
      final found = abi == null
          ? null
          : parseRelease(
              await _fetchLatest(), apkNameFor(mail: _mail, abi: abi));
      _checkedAt = _now();
      if (found != null && isNewer(found.version, build.version)) {
        if (found.version != release?.version) _bannerHidden = false;
        release = found;
        stage = UpdateStage.available;
      } else {
        release = null;
        stage = UpdateStage.none;
        await _clearFolder(); // the one just installed, if any
      }
      return true;
    } on Object {
      return false; // offline: nothing to say
    } finally {
      checking = false;
      notifyListeners();
    }
  }

  /// The banner over the app: a new version (unless put off with «Позже»),
  /// or how its download is going.
  bool get showBanner {
    final r = release;
    if (r == null || _bannerHidden || stage == UpdateStage.none) return false;
    return stage != UpdateStage.available ||
        _prefs.updateDismissed != r.version;
  }

  /// «Позже» / «Скрыть». A version put off isn't offered by the banner again;
  /// Настройки still have it.
  void hideBanner() {
    _bannerHidden = true;
    if (stage == UpdateStage.available) {
      unawaited(_prefs.setUpdateDismissed(release?.version));
    }
    notifyListeners();
  }

  /// Fetches the APK, checks it against GitHub's size and digest, and opens
  /// the installer.
  Future<void> download() async {
    final r = release;
    if (r == null || stage == UpdateStage.downloading) return;
    stage = UpdateStage.downloading;
    progress = 0;
    error = null;
    _bannerHidden = false;
    notifyListeners();
    try {
      await _clearFolder();
      final dir = await _folder();
      await dir.create(recursive: true);
      final path = '${dir.path}/${r.apkName}';
      var shown = 0.0;
      await _download(r.apkUrl, path, (got, total) {
        final all = total > 0 ? total : r.size;
        if (all <= 0) return;
        progress = (got / all).clamp(0.0, 1.0);
        // Every percent is plenty for the bar.
        if (progress - shown >= 0.01 || progress == 1) {
          shown = progress;
          notifyListeners();
        }
      });
      final file = File(path);
      final digest = r.sha256;
      if (await file.length() != r.size ||
          (digest != null &&
              '${await sha256.bind(file.openRead()).first}' != digest)) {
        await file.delete();
        throw const _Corrupt();
      }
      _apk = path;
      stage = UpdateStage.ready;
      notifyListeners();
      await install();
    } on Object catch (e) {
      stage = UpdateStage.failed;
      error = switch (e) {
        _Corrupt() => 'файл пришёл повреждённым',
        DioException() => 'нет связи с GitHub',
        _ => '$e',
      };
      notifyListeners();
    }
  }

  /// Opens Android's installer with the downloaded APK.
  Future<void> install() async {
    final path = _apk;
    if (path == null) return;
    error = await _install(path);
    notifyListeners();
  }

  Future<void> _clearFolder() async {
    try {
      final dir = await _folder();
      if (await dir.exists()) await dir.delete(recursive: true);
    } on Object {
      // Only a leftover file; the cache is the system's to clear anyway.
    }
    _apk = null;
  }
}

class _Corrupt implements Exception {
  const _Corrupt();
}

Future<InstalledBuild> _installedBuild() async {
  final info = await PackageInfo.fromPlatform();
  return (version: info.version, code: int.tryParse(info.buildNumber) ?? 0);
}

Future<Object?> _fetchFromGitHub() async {
  // A client of its own: nothing of the university's session goes along.
  final res = await Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: {'Accept': 'application/vnd.github+json'},
  )).get<Object?>(kLatestReleaseApi);
  return res.data;
}

Future<void> _downloadWithDio(
        String url, String path, void Function(int, int) progress) =>
    Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)))
        .download(url, path, onReceiveProgress: progress);

Future<String?> _openInstaller(String path) async {
  final r = await OpenFilex.open(path,
      type: 'application/vnd.android.package-archive');
  return r.type == ResultType.done ? null : r.message;
}

/// In the app's private cache, which the installer reads through the
/// file provider.
Future<Directory> _updatesFolder() async =>
    Directory('${(await getTemporaryDirectory()).path}/updates');
