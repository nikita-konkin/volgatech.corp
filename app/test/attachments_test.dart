import 'dart:convert';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volgatech_pro/mail/attachments.dart';

void main() {
  group('attachmentFileName', () {
    test('keeps an ordinary name, Cyrillic included', () {
      expect(attachmentFileName('Приказ №12.pdf'), 'Приказ №12.pdf');
    });

    test('cannot leave the attachments folder', () {
      expect(attachmentFileName('../../shared_prefs/x.xml'),
          '.._.._shared_prefs_x.xml');
      expect(attachmentFileName(r'C:\temp\a.txt'), 'C__temp_a.txt');
      expect(attachmentFileName('..'), 'вложение');
    });

    test('names a nameless attachment', () {
      expect(attachmentFileName(null), 'вложение');
      expect(attachmentFileName('   '), 'вложение');
    });

    test('shortens a long name but keeps the extension', () {
      final name = attachmentFileName('${'Протокол заседания ' * 20}.docx');
      expect(utf8.encode(name).length, lessThanOrEqualTo(200));
      expect(name, startsWith('Протокол заседания'));
      expect(name, endsWith('.docx'));
    });
  });

  group('attachmentType', () {
    test('trusts a specific declared type', () {
      expect(attachmentType('scan', MediaType.fromText('image/jpeg')),
          'image/jpeg');
    });

    test('guesses from the name behind octet-stream', () {
      final octet = MediaType.fromText('application/octet-stream');
      expect(attachmentType('план.pdf', octet), 'application/pdf');
      expect(attachmentType('план.pdf', null), 'application/pdf');
      expect(attachmentType('data.bin', octet), isNull);
    });
  });
}
