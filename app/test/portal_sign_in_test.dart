import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:volgatech_pro/data/portal_workload_client.dart';
import 'package:volgatech_pro/ui/portal_sign_in.dart';

Future<void> _showForm(
  WidgetTester tester,
  Future<PortalSignInResult> Function(String, String) signIn, {
  VoidCallback? onSignedIn,
  VoidCallback? onUnexpected,
  Map<String, Object> preferences = const {},
}) async {
  SharedPreferences.setMockInitialValues(preferences);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: PortalSignIn(
        signIn: signIn,
        onSignedIn: onSignedIn ?? () {},
        onUnexpected: onUnexpected ?? () {},
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('The untouched sign-in form shows neutral instructions',
      (tester) async {
    final login = 'p.cha-${Random().nextInt(58139)}';
    await _showForm(
      tester,
      (_, __) async => PortalSignInResult.unexpected,
      preferences: {'portal_workload_login': login},
    );
    final hint =
        find.text('Логин и пароль — те же, что для университетской почты');
    final hintText = find
        .descendant(of: hint, matching: find.byType(RichText))
        .evaluate()
        .singleOrNull;
    final color = (hintText?.widget as RichText?)?.text.style?.color;
    final theme = Theme.of(tester.element(find.byType(PortalSignIn)));
    expect(
      (find.text('Вход на портал').evaluate().length, color),
      (1, theme.textTheme.bodyMedium?.color),
      reason: 'the heading was missing or the hint did not use normal text',
    );
  });

  testWidgets('The sign-in callback receives the normalised login',
      (tester) async {
    final random = Random();
    final name = 'a.kim-${random.nextInt(87315)}';
    final password = 'm!X ${random.nextInt(47317)}?';
    (String, String)? credentials;
    await _showForm(tester, (login, password) async {
      credentials = (login, password);
      return PortalSignInResult.signedIn;
    });
    await tester.enterText(
        find.widgetWithText(TextField, 'Логин'), ' $name@volgatech.net ');
    await tester.enterText(find.widgetWithText(TextField, 'Пароль'), password);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
    await tester.pumpAndSettle();
    expect(
      credentials,
      ('MARSTU\\$name', password),
      reason:
          'the callback did not receive the domain login and exact password',
    );
  });

  testWidgets('An explicitly typed domain is kept', (tester) async {
    final random = Random();
    final name = 's.ven-${random.nextInt(99731)}';
    final domain = 'BRANCH${random.nextInt(573)}';
    String? submitted;
    await _showForm(tester, (login, _) async {
      submitted = login;
      return PortalSignInResult.signedIn;
    });
    await tester.enterText(
        find.widgetWithText(TextField, 'Логин'), '$domain\\$name');
    await tester.enterText(find.widgetWithText(TextField, 'Пароль'),
        'Q/a-${random.nextInt(86153)}');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
    await tester.pumpAndSettle();
    expect(
      submitted,
      '$domain\\$name',
      reason: 'the typed domain was replaced',
    );
  });

  testWidgets('A rejected sign-in shows the error and clears the password',
      (tester) async {
    final random = Random();
    await _showForm(tester, (_, __) async => PortalSignInResult.rejected);
    final password = find.widgetWithText(TextField, 'Пароль');
    await tester.enterText(find.widgetWithText(TextField, 'Логин'),
        'be.lin-${random.nextInt(39771)}');
    await tester.enterText(password, 'Q!${random.nextInt(68131)}_a');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
    await tester.pumpAndSettle();
    expect(
      (
        find.text('Неверный логин или пароль').evaluate().length,
        tester.widget<TextField>(password).controller!.text,
      ),
      (1, ''),
      reason: 'the rejection message was missing or the password was retained',
    );
  });

  testWidgets('The sign-in button is disabled when either field is empty',
      (tester) async {
    final random = Random();
    await _showForm(tester, (_, __) async => PortalSignInResult.unexpected);
    final button = find.widgetWithText(FilledButton, 'Войти');
    final login = find.widgetWithText(TextField, 'Логин');
    await tester.enterText(login, 'v.n-${random.nextInt(88771)}');
    await tester.pump();
    final withoutPassword = tester.widget<FilledButton>(button).onPressed;
    await tester.enterText(login, '');
    await tester.enterText(find.widgetWithText(TextField, 'Пароль'),
        'r@t-${random.nextInt(46839)}');
    await tester.pump();
    expect(
      (withoutPassword, tester.widget<FilledButton>(button).onPressed),
      (null, null),
      reason: 'the sign-in button was enabled with an empty field',
    );
  });

  testWidgets('The form prefills the saved login and saves the typed login',
      (tester) async {
    final random = Random();
    final saved = 'y.bel-${random.nextInt(76161)}';
    final typed = 'y.bel-${random.nextInt(63737)}@volgatech.net';
    final password = 'h*Z-${random.nextInt(24557)}';
    var completed = false;
    await _showForm(
      tester,
      (_, __) async => PortalSignInResult.signedIn,
      onSignedIn: () => completed = true,
      preferences: {'portal_workload_login': saved},
    );
    final login = find.widgetWithText(TextField, 'Логин');
    final prefilled = tester.widget<TextField>(login).controller!.text;
    await tester.enterText(login, typed);
    await tester.enterText(find.widgetWithText(TextField, 'Пароль'), password);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
    await tester.pumpAndSettle();
    final preferences = await SharedPreferences.getInstance();
    expect(
      (prefilled, preferences.getString('portal_workload_login'), completed),
      (saved, typed, true),
      reason: 'the typed login was not restored or saved on successful sign-in',
    );
  });

  testWidgets('An unexpected landing opens the fallback with no password kept',
      (tester) async {
    final random = Random();
    var fallback = false;
    await _showForm(
      tester,
      (_, __) async => PortalSignInResult.unexpected,
      onUnexpected: () => fallback = true,
    );
    final password = find.widgetWithText(TextField, 'Пароль');
    await tester.enterText(find.widgetWithText(TextField, 'Логин'),
        't.don-${random.nextInt(76591)}');
    await tester.enterText(password, 'b?c-${random.nextInt(94123)}');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Войти'));
    await tester.pumpAndSettle();
    expect(
      (fallback, tester.widget<TextField>(password).controller!.text),
      (true, ''),
      reason: 'the fallback was skipped or the password was retained',
    );
  });
}
