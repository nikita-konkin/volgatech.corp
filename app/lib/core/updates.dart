/// New versions, as published on the project's GitHub releases page.
library;

/// The latest published (not draft, not pre-release) release.
const kLatestReleaseApi =
    'https://api.github.com/repos/nikita-konkin/volgatech.corp/releases/latest';

/// The download, as it may be served after GitHub's redirect.
const _downloadPrefix =
    'https://github.com/nikita-konkin/volgatech.corp/releases/download/';

/// A newer build to offer: the APK for this phone and this variant.
class AppRelease {
  const AppRelease({
    required this.version,
    required this.pageUrl,
    required this.apkName,
    required this.apkUrl,
    required this.size,
    this.sha256,
  });

  /// «0.5.1», from the tag «v0.5.1».
  final String version;

  /// The release on GitHub, with its notes.
  final String pageUrl;
  final String apkName;
  final String apkUrl;

  /// Bytes, as GitHub lists the file.
  final int size;

  /// Hex digest GitHub keeps for the file, when it lists one.
  final String? sha256;
}

/// The CPU type a per-ABI APK was built for, from its version code: Flutter
/// numbers them 1000 × ABI + build (1 armeabi-v7a, 2 arm64-v8a, 4 x86_64).
/// Null for a universal APK, which has no counterpart on the releases page.
String? abiFromVersionCode(int code) => switch (code ~/ 1000) {
      1 => 'armeabi-v7a',
      2 => 'arm64-v8a',
      4 => 'x86_64',
      _ => null,
    };

/// The APK that replaces this build: `app-mail-arm64-v8a-release.apk` for
/// the build with the mail client, `app-arm64-v8a-release.apk` without.
String apkNameFor({required bool mail, required String abi}) =>
    'app-${mail ? 'mail-' : ''}$abi-release.apk';

/// The release from [kLatestReleaseApi] with its APK named [apkName]; null
/// when it isn't there (or isn't from this project's releases).
AppRelease? parseRelease(Object? json, String apkName) {
  if (json is! Map<String, dynamic>) return null;
  final tag = json['tag_name'];
  final assets = json['assets'];
  if (tag is! String || assets is! List) return null;
  for (final a in assets) {
    if (a is! Map<String, dynamic> || a['name'] != apkName) continue;
    final url = a['browser_download_url'];
    final size = a['size'];
    if (url is! String || !url.startsWith(_downloadPrefix) || size is! int) {
      return null;
    }
    final digest = a['digest'];
    return AppRelease(
      version: tag.startsWith('v') ? tag.substring(1) : tag,
      pageUrl: json['html_url'] as String? ?? '',
      apkName: apkName,
      apkUrl: url,
      size: size,
      sha256: digest is String && digest.startsWith('sha256:')
          ? digest.substring(7).toLowerCase()
          : null,
    );
  }
  return null;
}

/// Whether [candidate] («0.5.1», «v0.5.1») is later than [installed]
/// («0.5.0», «0.5.0-beta.7»). A pre-release comes before its release.
bool isNewer(String candidate, String installed) {
  final a = _Version.parse(candidate), b = _Version.parse(installed);
  if (a == null || b == null) return false;
  for (var i = 0; i < 3; i++) {
    if (a.parts[i] != b.parts[i]) return a.parts[i] > b.parts[i];
  }
  // Same numbers: only a release over its own pre-release counts.
  return a.pre == null && b.pre != null;
}

class _Version {
  const _Version(this.parts, this.pre);
  final List<int> parts;
  final String? pre;

  static _Version? parse(String text) {
    final m = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+.*)?$')
        .firstMatch(text.trim());
    if (m == null) return null;
    return _Version([for (var i = 1; i <= 3; i++) int.parse(m[i]!)], m[4]);
  }
}

/// «21,9 МБ».
String megabytes(int bytes) =>
    '${(bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} МБ';
