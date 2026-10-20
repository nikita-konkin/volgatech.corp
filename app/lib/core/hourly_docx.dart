import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'hourly_load.dart';

/// Where the bundled template lives (built by tool/make_hourly_template.py
/// from a filled report).
const kHourlyTemplateAsset = 'assets/hourly/form28_appendix.docx';

/// The teacher line and the signature of the report.
class HourlyHeader {
  const HourlyHeader({
    this.teacherPost = '',
    this.teacherName = '',
    this.signerPost = 'Зав. кафедрой',
    this.signerName = '',
  });

  final String teacherPost; // «ст. преподаватель»
  final String teacherName; // full name
  final String signerPost; // «Зав. кафедрой ПиП ЭВС»
  final String signerName; // «И.О. Фамилия»

  /// Fields that must be filled before the report makes sense.
  List<String> get missing => [
        if (teacherName.isEmpty) 'преподаватель',
        if (signerName.isEmpty) 'подписывающий',
      ];

  Map<String, dynamic> toJson() => {
        'teacherPost': teacherPost,
        'teacherName': teacherName,
        'signerPost': signerPost,
        'signerName': signerName,
      };

  factory HourlyHeader.fromJson(Map<String, dynamic> j) {
    const d = HourlyHeader();
    String s(String k, String fallback) => j[k] as String? ?? fallback;
    return HourlyHeader(
      teacherPost: s('teacherPost', d.teacherPost),
      teacherName: s('teacherName', d.teacherName),
      signerPost: s('signerPost', d.signerPost),
      signerName: s('signerName', d.signerName),
    );
  }
}

/// Fills [template] with [header] and [rows] and returns the finished .docx.
///
/// The template's prototype class row is cloned once per row; the «Итого»
/// row after it gets the hours summed. Fonts, column widths and page setup
/// stay as the department's form has them.
Uint8List buildHourlyDocx(
    Uint8List template, HourlyHeader header, List<HourlyRow> rows) {
  if (rows.isEmpty) {
    throw ArgumentError.value(
        rows, 'rows', 'the report needs at least one class');
  }
  final archive = ZipDecoder().decodeBytes(template);
  final docFile = archive.findFile('word/document.xml');
  if (docFile == null) throw const FormatException('not a .docx template');
  var doc = utf8.decode(docFile.content);

  final proto = _row.allMatches(doc).firstWhere(
      (m) => m[0]!.contains('{{date}}'),
      orElse: () => throw const FormatException('no class row in template'));
  final filled = StringBuffer();
  for (final r in rows) {
    filled.write(_fillMarkers(proto[0]!, {
      'date': _dmyy(r.date),
      'hours': '${r.hours}',
      'group': r.groups.join(', '),
      'type': r.type,
      'discipline': r.discipline,
      'topic': r.topic,
    }));
  }
  doc = doc.substring(0, proto.start) +
      filled.toString() +
      doc.substring(proto.end);

  doc = _fillMarkers(doc, {
    'teacher': [header.teacherPost, header.teacherName]
        .where((s) => s.isNotEmpty)
        .join(' '),
    'total': '${rows.fold<int>(0, (s, r) => s + r.hours)}',
    'signer_post': header.signerPost,
    'signer_name': header.signerName,
  });

  final leftover = RegExp(r'\{\{[a-z_]+\}\}').firstMatch(doc);
  if (leftover != null) {
    throw FormatException('template marker not filled: ${leftover[0]}');
  }

  final out = Archive();
  for (final f in archive.files) {
    out.addFile(f.name == docFile.name
        ? ArchiveFile.bytes(f.name, utf8.encode(doc))
        : ArchiveFile.bytes(f.name, f.content));
  }
  return ZipEncoder().encodeBytes(out);
}

/// Topic plans read back from a finished report (one made by hand, or by
/// this app): for each discipline and lesson type, its topics in order, a
/// topic held over several classes in a row counted once with how many.
/// Where several groups went through a discipline, the one with the most
/// classes gives the plan. Keyed like [HourlyClass.planKey].
Map<String, List<PlanTopic>> plansFromReport(Uint8List docx) {
  final archive = ZipDecoder().decodeBytes(docx);
  final docFile = archive.findFile('word/document.xml');
  if (docFile == null) throw const FormatException('это не документ Word');
  final doc = utf8.decode(docFile.content, allowMalformed: true);

  // Group -> topics in document order, per discipline and type.
  final runs = <String, Map<String, List<String>>>{};
  for (final table in _table.allMatches(doc)) {
    final rows = [
      for (final r in _row.allMatches(table[0]!))
        [for (final c in _cell.allMatches(r[0]!)) _text(c[0]!)],
    ];
    if (rows.isEmpty || rows.first.length < 6) continue;
    final head = rows.first.map((s) => s.toLowerCase()).toList();
    if (!head.first.contains('дата') || !head.last.contains('тема')) continue;
    for (final cells in rows.skip(1)) {
      if (cells.length < 6 || !_date.hasMatch(cells[0])) continue;
      final [_, _, group, type, discipline, topic, ...] = cells;
      if (discipline.isEmpty || topic.isEmpty) continue;
      runs
          .putIfAbsent('$discipline|$type', () => {})
          .putIfAbsent(group, () => [])
          .add(topic);
    }
  }

  return {
    for (final MapEntry(:key, :value) in runs.entries)
      key:
          _collapse(value.values.reduce((a, b) => b.length > a.length ? b : a)),
  };
}

/// «A, A, B, A» -> A ×2, B ×1, A ×1.
List<PlanTopic> _collapse(List<String> topics) {
  final out = <PlanTopic>[];
  for (final t in topics) {
    if (out.isNotEmpty && out.last.title == t) {
      out[out.length - 1] = out.last.copyWith(count: out.last.count + 1);
    } else {
      out.add(PlanTopic(t));
    }
  }
  return out;
}

final _table = RegExp(r'<w:tbl>.*?</w:tbl>', dotAll: true);
final _row = RegExp(r'<w:tr[ >].*?</w:tr>', dotAll: true);
final _cell = RegExp(r'<w:tc>.*?</w:tc>', dotAll: true);
final _para = RegExp(r'<w:p[ >].*?</w:p>', dotAll: true);
final _t = RegExp(r'<w:t(?: [^>]*)?>([^<]*)</w:t>');
final _date = RegExp(r'\d{1,2}\.\d{1,2}\.\d{2,4}');

/// A cell's text, its paragraphs joined by a space.
String _text(String cell) => [
      for (final p in _para.allMatches(cell))
        _unescape(_t.allMatches(p[0]!).map((m) => m[1]!).join()),
    ]
        .where((s) => s.trim().isNotEmpty)
        .join(' ')
        .trim()
        .replaceAll(_spaces, ' ');

final _spaces = RegExp(r'\s+');

String _fillMarkers(String xml, Map<String, String> values) =>
    xml.replaceAllMapped(RegExp(r'\{\{([a-z_]+)\}\}'), (m) {
      final v = values[m[1]];
      return v == null ? m[0]! : _escape(v);
    });

String _escape(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _unescape(String s) => s
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&amp;', '&');

/// «05.02.26», as the department's form writes dates.
String _dmyy(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${(d.year % 100).toString().padLeft(2, '0')}';
