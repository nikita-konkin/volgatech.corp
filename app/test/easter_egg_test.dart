import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:volgatech_pro/ui/easter_egg.dart';

void main() {
  testWidgets('the settings footer shows the installed version',
      (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'Волгатех.Коллектив',
      packageName: 'net.volgatech.volgatech_pro',
      version: '9.8.7',
      buildNumber: '42',
      buildSignature: '',
    );
    await tester
        .pumpWidget(const MaterialApp(home: Scaffold(body: EasterEggFooter())));
    await tester.pumpAndSettle();
    expect(find.text('Волгатех.Коллектив · v9.8.7'), findsOneWidget);
  });
}
