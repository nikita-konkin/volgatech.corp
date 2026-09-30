import 'package:enough_mail/enough_mail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:volgatech_pro/mail/mail_html.dart';
import 'package:volgatech_pro/mail/mail_models.dart';
import 'package:volgatech_pro/mail/ui/mail_page.dart';
import 'package:volgatech_pro/mail/ui/mailbox_size_page.dart'
    show limitFromMb, usageLabel;
import 'package:volgatech_pro/mail/ui/message_page.dart';
import 'package:volgatech_pro/mail/ui/message_tile.dart'
    show dateGroup, sizeTint;

MimeMessage _parse(String raw) =>
    MimeMessage.parseFromText(raw.replaceAll('\n', '\r\n'));

void main() {
  setUpAll(() => initializeDateFormatting('ru_RU'));

  test('plain text is escaped and shown as-is', () {
    final html = messageHtml(_parse('''
From: a@volgatech.net
Subject: t
Content-Type: text/plain; charset=utf-8

<script>alert(1)</script> Привет & пока
'''));
    expect(
        html,
        contains(
            '&lt;script&gt;alert(1)&lt;&#47;script&gt; Привет &amp; пока'));
    expect(html, isNot(contains('<script>')));
  });

  test('the page forbids scripts and remote loads', () {
    final html = messageHtml(_parse('''
From: a@volgatech.net
Subject: t
Content-Type: text/html; charset=utf-8

<p>Hi <img src="https://tracker.example/p.gif"></p>
'''));
    expect(html, contains("default-src 'none'"));
    expect(html, contains('img-src data:;'));
    expect(html, contains('<p>Hi'));
  });

  test('inline cid: images become data URIs', () {
    final html = messageHtml(_parse('''
From: a@volgatech.net
Subject: t
MIME-Version: 1.0
Content-Type: multipart/related; boundary="b"

--b
Content-Type: text/html; charset=utf-8

<img src="cid:logo@x">
--b
Content-Type: image/png
Content-Transfer-Encoding: base64
Content-ID: <logo@x>

iVBORw0KGgo=
--b--
'''));
    expect(html, contains('src="data:image/png;base64,iVBORw0KGgo="'));
  });

  test('dates and sizes read naturally', () {
    final now = DateTime(2026, 9, 29, 18);
    expect(mailDate(DateTime(2026, 9, 29, 9, 5), now), '09:05');
    expect(mailDate(DateTime(2026, 9, 3, 9, 5), now), '3 сент.');
    expect(mailDate(DateTime(2025, 12, 31), now), '31.12.25');
    expect(fileSize(840), '840 Б');
    // List headings, as in Outlook on the web (29.09.2026 is a Tuesday).
    expect(dateGroup(DateTime(2026, 9, 29, 7), now), 'Сегодня');
    expect(dateGroup(DateTime(2026, 9, 28, 23), now), 'Вчера');
    expect(dateGroup(DateTime(2026, 9, 27), now), 'На прошлой неделе');
    expect(dateGroup(DateTime(2026, 9, 21), now), 'На прошлой неделе');
    expect(dateGroup(DateTime(2026, 9, 20), now), 'Сентябрь');
    expect(dateGroup(DateTime(2025, 12, 31), now), 'Декабрь 2025');
    final friday = DateTime(2026, 10, 2, 12);
    expect(dateGroup(DateTime(2026, 9, 29), friday), 'На этой неделе');
    expect(dateGroup(null, now), 'Без даты');
    // The limit bar's label.
    const mb = 1024 * 1024, gb = 1024 * mb;
    expect(usageLabel(1932735283, 2 * gb), '1,8 из 2 ГБ');
    expect(usageLabel(2 * gb, 2 * gb), '2 из 2 ГБ');
    expect(usageLabel(450 * mb, 500 * mb), '450 из 500 МБ');
    expect(usageLabel(1932735283, null), '1,8 ГБ занято');
    expect(usageLabel(510612439, 512 * mb), '487 из 512 МБ');
    // The limit as typed in, the way the web mail shows it.
    for (final typed in ['512', '512,00', '512.00', ' 512 МБ', '512mb']) {
      expect(limitFromMb(typed), 512 * mb, reason: typed);
    }
    expect(limitFromMb('2 048'), 2 * gb);
    for (final typed in ['', '0', '0,5', 'много', '1.2.3']) {
      expect(limitFromMb(typed), isNull, reason: typed);
    }
    expect(fileSize(12 * 1024), '12 КБ');
    expect(fileSize(3565158), '3,4 МБ');
  });

  test('rows warm up from yellow to red as messages get bigger', () {
    const kb = 1024, mb = 1024 * kb;
    for (final dark in [false, true]) {
      expect(sizeTint(null, dark: dark), isNull);
      expect(sizeTint(100 * kb, dark: dark), isNull); // most mail: no colour
      final small = sizeTint(200 * kb, dark: dark)!;
      final one = sizeTint(mb, dark: dark)!;
      final ten = sizeTint(10 * mb, dark: dark)!;
      // Redder (less green) and stronger at each step.
      expect(small.g, greaterThan(one.g));
      expect(one.g, greaterThan(ten.g));
      expect(small.a, lessThan(one.a));
      expect(one.a, lessThan(ten.a));
      // 10 MB is already the top of the scale; the wash stays see-through.
      expect(sizeTint(25 * mb, dark: dark), ten);
      expect(ten.a, lessThan(0.4));
    }
  });

  test('folder roles come from flags or Russian/English names', () {
    expect(folderRole(path: 'INBOX', name: 'INBOX'), FolderRole.inbox);
    expect(folderRole(path: 'x', name: 'Отправленные'), FolderRole.sent);
    expect(folderRole(path: 'x', name: 'Удалённые'), FolderRole.trash);
    expect(folderRole(path: 'x', name: 'Deleted Items'), FolderRole.trash);
    expect(folderRole(path: 'x', name: 'Проекты'), FolderRole.other);
    expect(
        folderRole(path: 'x', name: 'Корзина', trash: true), FolderRole.trash);
  });
}
