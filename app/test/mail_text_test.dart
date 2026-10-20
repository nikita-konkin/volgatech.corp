import 'package:flutter_test/flutter_test.dart';
import 'package:volgatech_pro/mail/mail_text.dart';

void main() {
  final sent = DateTime(2026, 10, 20, 9);

  List<String> found(PreparedBody b) => [for (final l in b.links) '$l'];

  test('the letter\'s own links point at the reader, each with its text', () {
    final b = prepareBody(
        html: '<p>Смотрите <a href="https://volgatech.net/news?id=1&amp;p=2" '
            'target="_blank">новость</a> и <a href=\'mailto:dean@volgatech.net'
            '?subject=Вопрос\'><b>деканат</b></a>.</p>'
            '<a name="top">якорь</a><a href="#top">наверх</a>'
            '<a href="javascript:alert(1)">ссылка</a>',
        sent: sent);
    expect(found(b), [
      'LinkKind.web https://volgatech.net/news?id=1&p=2 «новость»',
      'LinkKind.mail mailto:dean@volgatech.net?subject=Вопрос «деканат»',
    ]);
    expect(b.html, contains('<a href="volga-link:0">новость</a>'));
    expect(b.html, contains('<a href="volga-link:1"><b>деканат</b></a>'));
    expect(b.html, isNot(contains('target=')));
    expect(b.html, contains('<a name="top">'));
    expect(b.html, contains('<a href="#top">'));
    expect(b.html, isNot(contains('javascript:')));
    expect(b.links[1].value, 'dean@volgatech.net');
  });

  test('text names one site, the link leads to another', () {
    expect(
        isSuspicious('https://volgatech-login.ru/x', 'volgatech.net'), isTrue);
    expect(isSuspicious('https://evil.example', 'https://www.volgatech.net/'),
        isTrue);
    expect(
        isSuspicious('https://evil.example', 'support@volgatech.net'), isTrue);
    expect(
        isSuspicious('https://lk.volgatech.net/a', 'volgatech.net'), isFalse);
    expect(isSuspicious('https://www.volgatech.net', 'volgatech.net'), isFalse);
    expect(isSuspicious('https://evil.example', 'Личный кабинет'), isFalse);
    final b = prepareBody(
        html:
            '<a href="https://volgatech.net.evil.example/">volgatech.net</a>');
    expect(b.links.single.suspicious, isTrue);
    expect(b.links.single.host, 'volgatech.net.evil.example');
  });

  test('online meetings', () {
    expect(meetingService('https://telemost.yandex.ru/j/123'), 'Телемост');
    expect(meetingService('https://telemost.360.yandex.ru/j/1'), 'Телемост');
    expect(meetingService('https://volgatech.ktalk.ru/abc'), 'Контур.Толк');
    expect(meetingService('https://us02web.zoom.us/j/8812?pwd=x'), 'Zoom');
    expect(meetingService('https://zoom.us/pricing'), isNull);
    expect(meetingService('https://vk.com/call/join/abc'), 'VK Звонки');
    expect(meetingService('https://vk.com/volgatech'), isNull);
    expect(
        meetingService('https://meet.google.com/abc-defg-hij'), 'Google Meet');
    expect(meetingService('https://jazz.sber.ru/x'), 'SaluteJazz');
    expect(meetingService('https://my.mts-link.ru/j/1'), 'МТС Линк');
    final b = prepareBody(
        text: 'Ссылка на встречу: https://telemost.yandex.ru/j/7788. До связи',
        sent: sent);
    expect(b.meeting?.target, 'https://telemost.yandex.ru/j/7788');
    expect(b.meeting?.meeting, 'Телемост');
  });

  test('plain text: addresses, numbers and dates become links', () {
    final b = prepareBody(
        text: 'Добрый день!\n'
            'Материалы: www.example.com/docs/file.pdf, и (см. https://ru.wikipedia.org/wiki/Mail_(protocol)).\n'
            'Пишите на ivanov@volgatech.net или звоните +7 (8362) 68-60-00 доб. 123,\n'
            'моб. 8 900 123-45-67, тел. 45-67-89.\n'
            'Защита 14 октября 2026 г. в 15:00, отчёт до 01.11.2026, '
            'консультация 3 ноября.\n'
            '<script>alert(1)</script> & пока',
        sent: sent);
    expect(found(b), [
      'LinkKind.web https://www.example.com/docs/file.pdf «www.example.com/docs/file.pdf»',
      'LinkKind.web https://ru.wikipedia.org/wiki/Mail_(protocol) «https://ru.wikipedia.org/wiki/Mail_(protocol)»',
      'LinkKind.mail mailto:ivanov@volgatech.net «ivanov@volgatech.net»',
      'LinkKind.phone tel:+78362686000,123 «+7 (8362) 68-60-00 доб. 123»',
      'LinkKind.phone tel:+79001234567 «8 900 123-45-67»',
      'LinkKind.phone tel:+78362456789 «45-67-89»',
      'LinkKind.date  «14 октября 2026 г. в 15:00»',
      'LinkKind.date  «01.11.2026»',
      'LinkKind.date  «3 ноября»',
    ]);
    final dates = b.links.where((l) => l.kind == LinkKind.date).toList();
    expect(dates[0].when, DateTime(2026, 10, 14, 15));
    expect(dates[0].hasTime, isTrue);
    expect(dates[1].when, DateTime(2026, 11, 1));
    expect(dates[1].hasTime, isFalse);
    expect(dates[2].when, DateTime(2026, 11, 3));
    // Still escaped, as before.
    expect(
        b.html, contains('&lt;script&gt;alert(1)&lt;/script&gt; &amp; пока'));
    expect(b.html, isNot(contains('<script>')));
    expect(b.html, startsWith('<div class="plain">'));
    expect(
        b.html,
        contains(
            '<a class="vt-auto" href="volga-link:2">ivanov@volgatech.net</a>'));
  });

  test('what isn\'t a number or a date stays text', () {
    final b = prepareBody(
        text: 'Заявка 2026-10-20, версия 1.2.3, счёт 123456, 31.02.2026, '
            '99.99.99, ИНН 1215012345, в 25:99',
        sent: sent);
    expect(found(b), isEmpty);
    // A time that isn't one is left out of the date.
    final t = prepareBody(text: '5 ноября в 25:61', sent: sent);
    expect(t.links.single.text, '5 ноября');
    expect(t.links.single.hasTime, isFalse);
  });

  test('a date without a year: the coming one', () {
    final dec = DateTime(2026, 12, 20);
    final b = prepareBody(text: 'Сессия с 15 января', sent: dec);
    expect(b.links.single.when, DateTime(2027, 1, 15));
    final b2 = prepareBody(text: 'Было 1 декабря', sent: dec);
    expect(b2.links.single.when, DateTime(2026, 12, 1));
  });

  test('HTML text: linked outside <a>, <style> and <head>, entities kept', () {
    final b = prepareBody(
        html: '<html><head><title>a@b.ru</title><style>p{color:red}'
            '</style></head><body><p>Сайт&nbsp;https://volgatech.net/a?x=1&amp;y=2&quot; '
            'и почта a@b.ru</p><!-- c@d.ru --></body></html>',
        sent: sent);
    expect(found(b), [
      'LinkKind.web https://volgatech.net/a?x=1&y=2 «https://volgatech.net/a?x=1&y=2»',
      'LinkKind.mail mailto:a@b.ru «a@b.ru»',
    ]);
    expect(b.html, contains('<title>a@b.ru</title>'));
    expect(b.html, contains('<!-- c@d.ru -->'));
    expect(
        b.html,
        contains('<a class="vt-link" href="volga-link:0">'
            'https://volgatech.net/a?x=1&amp;y=2</a>&quot;'));
  });

  test('every web address once, in the order the letter has them', () {
    final b = prepareBody(
        html: '<a href="https://a.ru">A</a> https://b.ru '
            '<a href="https://a.ru">ещё A</a> <a href="mailto:x@y.ru">x</a>');
    expect([for (final l in b.webLinks) l.target],
        ['https://a.ru', 'https://b.ru']);
  });

  test('tel: links, mailto: and List-Unsubscribe', () {
    expect(linkFor('tel:8 (8362) 68-60-00', 'Приёмная').target,
        'tel:+78362686000');
    final m = parseMailto(
        'mailto:a%40b.ru?subject=%D0%92%D0%BE%D0%BF%D1%80%D0%BE%D1%81&body=Hi&CC=c@d.ru');
    expect(m.to, 'a@b.ru');
    expect(m.subject, 'Вопрос');
    expect(m.body, 'Hi');
    expect(m.cc, 'c@d.ru');
    expect(parseMailto('mailto:x@y.ru').subject, '');
    // As letters have them: Cyrillic unescaped, a stray «%», a plus.
    expect(parseMailto('mailto:x@y.ru?subject=Справка 100%').subject,
        'Справка 100%');
    expect(parseMailto('mailto:x@y.ru?subject=C++%20и%20Java').subject,
        'C++ и Java');
    expect(
        unsubscribeTarget(
            '<mailto:leave@list.ru?subject=unsubscribe>, <https://list.ru/u?id=1>'),
        'https://list.ru/u?id=1');
    expect(unsubscribeTarget('<mailto:leave@list.ru>'), 'mailto:leave@list.ru');
    expect(unsubscribeTarget(null), isNull);
  });

  test('the sender\'s phone: from the signature, not the quote', () {
    const text = 'Спасибо!\n--\nИ.И. Иванов\nтел. 68-60-00\n\n'
        '-----Original Message-----\nОт: Петров\nмоб. +7 900 111-22-33';
    expect(signaturePhone(text), '+78362686000');
    expect(signaturePhone('Без подписи'), isNull);
    expect(ownText('Ок\n\n20.10.2026, Петров <p@x.ru> написал:\n> текст'),
        'Ок\n\n');
  });

  test('numbers as people write them', () {
    expect(formatPhone('+78362686000,123'), '+7 8362 68-60-00 доб. 123');
    expect(formatPhone('+79001234567'), '+7 900 123-45-67');
    expect(formatPhone('112'), '112');
    expect(tidyText('a  \r\n\r\n\r\n\r\nb\n'), 'a\n\nb');
    expect(htmlUnescape('&laquo;Тест&raquo; &#1055;&#x440; &amp;amp;'),
        '«Тест» Пр &amp;');
  });
}
