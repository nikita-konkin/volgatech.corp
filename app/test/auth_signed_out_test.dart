import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volgatech_pro/core/session.dart';
import 'package:volgatech_pro/state/auth_controller.dart';

import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('whenSignedOut: at a signed-out start', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final auth = AuthController(FakeApi(), Session(), FakeCache());
    var calls = 0;
    whenSignedOut(auth, () => calls++);
    await auth.bootstrap();
    expect(auth.status, AuthStatus.unauthenticated);
    expect(calls, 1);
  });

  test('whenSignedOut: once per sign-out, none while signed in', () async {
    FlutterSecureStorage.setMockInitialValues(
        {'accessToken': 'a', 'refreshToken': 'r', 'personId': '7'});
    final auth = AuthController(FakeApi(), Session(), FakeCache());
    var calls = 0;
    whenSignedOut(auth, () => calls++);
    await auth.bootstrap();
    expect(auth.status, AuthStatus.authenticated);
    expect(calls, 0);

    await auth.logout();
    expect(calls, 1);
    await auth.logout();
    expect(calls, 1, reason: 'already signed out');
  });
}
