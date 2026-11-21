import 'package:flutter_test/flutter_test.dart';
import 'package:volgatech_pro/core/release_notes.dart';

void main() {
  test('An update shows the installed release notes.', () {
    final release = ReleaseNotes(
      version: '7.13.29',
      notes: const {
        '7.13.29': ['Pinned lab hours']
      },
      seenVersion: '7.4.16',
      signedIn: true,
    );
    expect(release.lines, ['Pinned lab hours'],
        reason: 'The notes did not come from the installed release.');
  });

  test('The same version cannot show twice.', () {
    final release = ReleaseNotes(
      version: '11.2.43',
      notes: const {
        '11.2.43': ['Clearer room labels']
      },
      seenVersion: '11.2.43',
      signedIn: true,
    );
    expect(release.lines, isEmpty,
        reason: 'The notes were offered again for a version already seen.');
  });

  test('A fresh install remembers its version silently.', () {
    final release = ReleaseNotes(
      version: '3.17.8',
      notes: const {
        '3.17.8': ['New print margins']
      },
      seenVersion: '',
      signedIn: false,
    );
    expect([release.lines, release.shouldRemember], [isEmpty, true],
        reason: 'The fresh install did not silently record its version.');
  });

  test('A version without notes is remembered silently.', () {
    final release = ReleaseNotes(
      version: '19.4.37',
      notes: const {
        '19.2.5': ['Sort archived letters']
      },
      seenVersion: '19.2.5',
      signedIn: true,
    );
    expect([release.lines, release.shouldRemember], [isEmpty, true],
        reason: 'A release without notes was not silently recorded.');
  });

  test('An existing session sees notes on the first launch with the feature.',
      () {
    final release = ReleaseNotes(
      version: '6.29.14',
      notes: const {
        '6.29.14': ['Keep draft recipients']
      },
      seenVersion: '',
      signedIn: true,
    );
    expect(release.lines, ['Keep draft recipients'],
        reason: 'The restored session did not qualify for release notes.');
  });
}
