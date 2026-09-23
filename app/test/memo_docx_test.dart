import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:volgatech_pro/core/foreign_memo.dart';
import 'package:volgatech_pro/core/memo_docx.dart';
import 'package:xml/xml.dart';

const _w = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main';

void main() {
  final template = File(kMemoTemplateAsset).readAsBytesSync();

  const header = MemoHeader(
    department: 'Кафедра информационных технологий, радиотехники и связи',
    departmentDative: 'Кафедре информационных технологий, радиотехники и связи',
    addresseeName: 'Иванову И.И.',
    signerName: 'П.П. Петрова',
    executorName: 'Сидорова & Ко <тест>', // must be XML-escaped
    executorPhone: '(8362) 00-00-00',
    teacherName: 'Смирнов Сергей Сергеевич',
    teacherPost: 'ст. преподаватель',
  );

  MemoRow row(int day, String group, String type) => MemoRow(
        date: DateTime(2026, 9, day),
        time: '08:00',
        groups: [group],
        discipline: 'Информационные технологии в отрасли',
        type: type,
      );

  final rows = [
    row(2, 'ИСТ-110', 'практическая'),
    row(2, 'ИСТ-210', 'лабораторная'),
    MemoRow(
      date: DateTime(2026, 9, 4),
      time: '09:45',
      groups: const ['ИСТ-110', 'ИСТ-210'],
      discipline: 'Введение в инженерную деятельность',
      type: 'лекция',
    ),
  ];

  late Uint8List out;
  late XmlDocument doc;

  setUpAll(() {
    out = buildMemoDocx(template, header, rows);
    final xml = utf8.decode(
        ZipDecoder().decodeBytes(out).findFile('word/document.xml')!.content);
    doc = XmlDocument.parse(xml); // throws if the XML is broken
    final path = Platform.environment['MEMO_OUT'];
    if (path != null) File(path).writeAsBytesSync(out); // for a visual check
  });

  String text(XmlElement e) =>
      e.findAllElements('t', namespaceUri: _w).map((t) => t.innerText).join();

  List<List<String>> classTable() {
    final table = doc
        .findAllElements('tbl', namespaceUri: _w)
        .firstWhere((t) => text(t).contains('Преподаватель'));
    return [
      for (final tr in table.findElements('tr', namespaceUri: _w))
        [for (final tc in tr.findElements('tc', namespaceUri: _w)) text(tc)],
    ];
  }

  String sdt(String tag) {
    final e = doc.findAllElements('sdt', namespaceUri: _w).firstWhere((s) =>
        s
            .findAllElements('tag', namespaceUri: _w)
            .first
            .getAttribute('val', namespaceUri: _w) ==
        tag);
    return text(e.findElements('sdtContent', namespaceUri: _w).first);
  }

  test('one table row per class, the last one carrying the total', () {
    expect(classTable(), [
      [
        'Преподаватель',
        'Дата занятия',
        'Группа',
        'Дисциплина',
        'Тип занятия',
        'Нагрузка, час.'
      ],
      [
        'Смирнов Сергей Сергеевич, ст. преподаватель',
        '02.09.2026',
        'ИСТ-110',
        'Информационные технологии в отрасли',
        'практическая',
        '2'
      ],
      [
        '',
        '02.09.2026',
        'ИСТ-210',
        'Информационные технологии в отрасли',
        'лабораторная',
        '2'
      ],
      [
        '',
        '04.09.2026',
        'ИСТ-110, ИСТ-210',
        'Введение в инженерную деятельность',
        'лекция',
        '2/6'
      ],
    ]);
  });

  test('the teacher cell spans every row (vertical merge)', () {
    final table = doc
        .findAllElements('tbl', namespaceUri: _w)
        .firstWhere((t) => text(t).contains('Преподаватель'));
    final merges = [
      for (final tr in table.findElements('tr', namespaceUri: _w).skip(1))
        tr
            .findElements('tc', namespaceUri: _w)
            .first
            .findAllElements('vMerge', namespaceUri: _w)
            .first
            .getAttribute('val', namespaceUri: _w),
    ];
    expect(merges, ['restart', null, null]); // null = continue the merge
  });

  test('the column headings repeat on every page', () {
    final table = doc
        .findAllElements('tbl', namespaceUri: _w)
        .firstWhere((t) => text(t).contains('Преподаватель'));
    final rows = table.findElements('tr', namespaceUri: _w).toList();
    bool repeats(XmlElement tr) =>
        tr.findAllElements('tblHeader', namespaceUri: _w).isNotEmpty;
    expect(repeats(rows.first), isTrue);
    expect(rows.skip(1).where(repeats), isEmpty);
  });

  test('a class row is never split across a page break', () {
    final table = doc
        .findAllElements('tbl', namespaceUri: _w)
        .firstWhere((t) => text(t).contains('Преподаватель'));
    final rows = table.findElements('tr', namespaceUri: _w).skip(1).toList();
    expect(rows, hasLength(3));
    for (final tr in rows) {
      expect(tr.findAllElements('cantSplit', namespaceUri: _w), isNotEmpty);
    }
  });

  test('content controls keep their tags and get the header values', () {
    expect(sdt('Подразделение'), header.department);
    expect(sdt('Адресат - Должность'), 'Первому проректору');
    expect(sdt('Адресат - Фамилия И.О.'), 'Иванову И.И.');
    expect(sdt('Структурное подразделение'), header.departmentDative);
    expect(sdt('Подписывающий - Должность'), 'Заведующий кафедрой');
    expect(sdt('Подписывающий - И.О.Фамилия'), 'П.П. Петрова');
    expect(sdt('Исполнитель'), 'Сидорова & Ко <тест>');
    expect(sdt('Телефон исполнителя'), '(8362) 00-00-00');
    expect(sdt('Название'),
        'Об оплате проведения учебных занятий на иностранном языке');
  });

  test('no marker is left and every other part of the template is kept', () {
    expect(doc.toXmlString(), isNot(contains('{{')));
    final names = [for (final f in ZipDecoder().decodeBytes(out).files) f.name];
    final original = [
      for (final f in ZipDecoder().decodeBytes(template).files) f.name
    ];
    expect(names, original);
  });

  test('refuses to build a memo without classes', () {
    expect(() => buildMemoDocx(template, header, const []),
        throwsA(isA<ArgumentError>()));
  });
}
