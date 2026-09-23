import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/memo_docx.dart';
import '../state/memo_controller.dart';
import '../theme.dart';

/// Letterhead, signature and teacher fields of the memo. Filled once and
/// remembered; the preview flags anything required that is still empty.
class MemoHeaderPage extends StatefulWidget {
  const MemoHeaderPage({super.key});

  @override
  State<MemoHeaderPage> createState() => _MemoHeaderPageState();
}

class _MemoHeaderPageState extends State<MemoHeaderPage> {
  late final MemoHeader _initial = context.read<MemoController>().header;
  late final _department = TextEditingController(text: _initial.department);
  late final _departmentDative =
      TextEditingController(text: _initial.departmentDative);
  late final _addresseePost =
      TextEditingController(text: _initial.addresseePost);
  late final _addresseeName =
      TextEditingController(text: _initial.addresseeName);
  late final _signerPost = TextEditingController(text: _initial.signerPost);
  late final _signerName = TextEditingController(text: _initial.signerName);
  late final _executorName = TextEditingController(text: _initial.executorName);
  late final _executorPhone =
      TextEditingController(text: _initial.executorPhone);
  late final _teacherName = TextEditingController(text: _initial.teacherName);
  late final _teacherPost = TextEditingController(text: _initial.teacherPost);

  List<TextEditingController> get _all => [
        _department,
        _departmentDative,
        _addresseePost,
        _addresseeName,
        _signerPost,
        _signerName,
        _executorName,
        _executorPhone,
        _teacherName,
        _teacherPost,
      ];

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    String t(TextEditingController c) => c.text.trim();
    final navigator = Navigator.of(context);
    await context.read<MemoController>().saveHeader(MemoHeader(
          department: t(_department),
          departmentDative: t(_departmentDative),
          addresseePost: t(_addresseePost),
          addresseeName: t(_addresseeName),
          signerPost: t(_signerPost),
          signerName: t(_signerName),
          executorName: t(_executorName),
          executorPhone: t(_executorPhone),
          teacherName: t(_teacherName),
          teacherPost: t(_teacherPost),
        ));
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Шапка и подписи'),
        actions: [
          TextButton(
            onPressed: _save,
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Сохранить'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const _Section('Подразделение'),
          _Field(_department, 'В шапке', hint: 'Кафедра …'),
          _Field(_departmentDative, 'В тексте: «по … следующим сотрудникам»',
              hint: 'Кафедре …'),
          const _Section('Кому'),
          _Field(_addresseePost, 'Должность', hint: 'Первому проректору'),
          _Field(_addresseeName, 'Фамилия И.О. (кому)', hint: 'Иванову И.И.'),
          const _Section('Подписывает'),
          _Field(_signerPost, 'Должность', hint: 'Заведующий кафедрой'),
          _Field(_signerName, 'И.О. Фамилия', hint: 'И.И. Иванова'),
          const _Section('Преподаватель'),
          _Field(_teacherName, 'ФИО'),
          _Field(_teacherPost, 'Должность', hint: 'ст. преподаватель'),
          const _Section('Исполнитель'),
          _Field(_executorName, 'ФИО'),
          _Field(_executorPhone, 'Телефон', keyboard: TextInputType.phone),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 10),
        child: Text(title,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.bold, color: Brand.coral)),
      );
}

class _Field extends StatelessWidget {
  const _Field(this.controller, this.label, {this.hint, this.keyboard});
  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboard;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: controller,
          keyboardType: keyboard,
          maxLines: null,
          decoration: InputDecoration(labelText: label, hintText: hint),
        ),
      );
}
