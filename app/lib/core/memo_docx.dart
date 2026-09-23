import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'foreign_memo.dart';

/// Where the bundled template lives (built by tool/make_memo_template.py from
/// the portal's own «служебная записка»).
const kMemoTemplateAsset = 'assets/memo/foreign_language_memo.docx';

/// Letterhead, signature and teacher fields of the memo.
class MemoHeader {
  const MemoHeader({
    this.department = '',
    this.departmentDative = '',
    this.addresseePost = 'Первому проректору',
    this.addresseeName = '',
    this.signerPost = 'Заведующий кафедрой',
    this.signerName = '',
    this.executorName = '',
    this.executorPhone = '',
    this.teacherName = '',
    this.teacherPost = '',
  });

  final String department; // «Кафедра …» — letterhead
  final String departmentDative; // «Кафедре …» — «по Кафедре … следующим»
  final String addresseePost; // «Первому проректору»
  final String addresseeName; // «Фамилии И.О.» (dative)
  final String signerPost; // head of department
  final String signerName; // «И.О. Фамилия»
  final String executorName; // who prepared it
  final String executorPhone;
  final String teacherName; // full name
  final String teacherPost; // «ст. преподаватель»

  /// Fields that must be filled before the memo makes sense.
  List<String> get missing => [
        if (department.isEmpty) 'подразделение',
        if (addresseeName.isEmpty) 'адресат',
        if (signerName.isEmpty) 'подписывающий',
        if (teacherName.isEmpty) 'преподаватель',
      ];

  MemoHeader copyWith({
    String? department,
    String? departmentDative,
    String? addresseePost,
    String? addresseeName,
    String? signerPost,
    String? signerName,
    String? executorName,
    String? executorPhone,
    String? teacherName,
    String? teacherPost,
  }) =>
      MemoHeader(
        department: department ?? this.department,
        departmentDative: departmentDative ?? this.departmentDative,
        addresseePost: addresseePost ?? this.addresseePost,
        addresseeName: addresseeName ?? this.addresseeName,
        signerPost: signerPost ?? this.signerPost,
        signerName: signerName ?? this.signerName,
        executorName: executorName ?? this.executorName,
        executorPhone: executorPhone ?? this.executorPhone,
        teacherName: teacherName ?? this.teacherName,
        teacherPost: teacherPost ?? this.teacherPost,
      );

  Map<String, dynamic> toJson() => {
        'department': department,
        'departmentDative': departmentDative,
        'addresseePost': addresseePost,
        'addresseeName': addresseeName,
        'signerPost': signerPost,
        'signerName': signerName,
        'executorName': executorName,
        'executorPhone': executorPhone,
        'teacherName': teacherName,
        'teacherPost': teacherPost,
      };

  factory MemoHeader.fromJson(Map<String, dynamic> j) {
    const d = MemoHeader();
    String s(String k, String fallback) => j[k] as String? ?? fallback;
    return MemoHeader(
      department: s('department', d.department),
      departmentDative: s('departmentDative', d.departmentDative),
      addresseePost: s('addresseePost', d.addresseePost),
      addresseeName: s('addresseeName', d.addresseeName),
      signerPost: s('signerPost', d.signerPost),
      signerName: s('signerName', d.signerName),
      executorName: s('executorName', d.executorName),
      executorPhone: s('executorPhone', d.executorPhone),
      teacherName: s('teacherName', d.teacherName),
      teacherPost: s('teacherPost', d.teacherPost),
    );
  }
}

/// Fills the portal template [template] with [header] and [rows] and returns
/// the finished .docx.
///
/// The template keeps the portal's content controls, styles and metadata; only
/// the {{markers}} change. The class table's two prototype rows (a teacher's
/// first row, with the vertically merged teacher cell, and a continuation row)
/// are cloned once per class. As in the paper memo, the last row's load reads
/// "2/36": that class's hours, then the total.
Uint8List buildMemoDocx(
    Uint8List template, MemoHeader header, List<MemoRow> rows) {
  if (rows.isEmpty) {
    throw ArgumentError.value(
        rows, 'rows', 'the memo needs at least one class');
  }
  final archive = ZipDecoder().decodeBytes(template);
  final docFile = archive.findFile('word/document.xml');
  if (docFile == null) throw const FormatException('not a .docx template');
  var doc = utf8.decode(docFile.content);

  doc = _fillMarkers(doc, {
    'department': header.department,
    'addressee_post': header.addresseePost,
    'addressee_name': header.addresseeName,
    'department_dative': header.departmentDative,
    'signer_post': header.signerPost,
    'signer_name': header.signerName,
    'executor_name': header.executorName,
    'executor_phone': header.executorPhone,
  });
  doc = _fillClassTable(doc, header, rows);

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

final _row = RegExp(r'<w:tr[ >].*?</w:tr>', dotAll: true);

String _fillClassTable(String doc, MemoHeader h, List<MemoRow> rows) {
  final protos = _row.allMatches(doc).where((m) => m[0]!.contains('{{date}}'));
  final first = protos.firstWhere((m) => m[0]!.contains('{{teacher_name}}'),
      orElse: () => throw const FormatException('no teacher row in template'));
  final next = protos.firstWhere((m) => m.start > first.start,
      orElse: () => throw const FormatException('no continuation row'));

  final total = rows.fold<int>(0, (s, r) => s + r.hours);
  final out = StringBuffer();
  for (var i = 0; i < rows.length; i++) {
    final r = rows[i];
    final last = i == rows.length - 1;
    out.write(_fillMarkers(i == 0 ? first[0]! : next[0]!, {
      'teacher_name': h.teacherName.isEmpty ? '' : '${h.teacherName}, ',
      'teacher_post': h.teacherPost,
      'date': _dmy(r.date),
      'group': r.groups.join(', '),
      'discipline': r.discipline,
      'type': r.type,
      'hours': last ? '${r.hours}/$total' : '${r.hours}',
    }));
  }
  return doc.substring(0, first.start) +
      out.toString() +
      doc.substring(next.end);
}

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

String _dmy(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
