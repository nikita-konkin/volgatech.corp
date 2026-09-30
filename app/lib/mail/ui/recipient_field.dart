import 'dart:async';

import 'package:enough_mail/enough_mail.dart' show MailAddress;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme.dart';
import '../compose.dart';
import '../mail_controller.dart';

/// «Кому» / «Копия»: addresses separated by commas, with people from the
/// organisation's address book suggested as a name is typed, as in Outlook.
class RecipientField extends StatefulWidget {
  const RecipientField({
    super.key,
    required this.controller,
    required this.decoration,
    this.enabled = true,
  });

  final TextEditingController controller;
  final InputDecoration decoration;
  final bool enabled;

  @override
  State<RecipientField> createState() => _RecipientFieldState();
}

class _RecipientFieldState extends State<RecipientField> {
  static const _minLength = 3;
  static const _shown = 8;

  final _focus = FocusNode();
  Timer? _debounce;
  String _query = '';
  List<MailAddress> _found = const [];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _focus.addListener(() {
      if (!_focus.hasFocus) _clear();
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _debounce?.cancel();
    _focus.dispose();
    super.dispose();
  }

  void _clear() {
    _debounce?.cancel();
    if (_found.isNotEmpty) setState(() => _found = const []);
  }

  void _changed() {
    final c = widget.controller;
    // Only the recipient at the end is being typed.
    final atEnd = c.selection.baseOffset == c.text.length;
    final q = atEnd ? lastRecipient(c.text) : '';
    if (q == _query) return;
    _query = q;
    _clear();
    if (q.length < _minLength || q.contains('@')) return;
    final mail = context.read<MailController>();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final found = await mail.searchDirectory(q);
      // Typing went on, or the field was left, while the server answered.
      if (!mounted || q != _query || !_focus.hasFocus) return;
      setState(() => _found = found);
    });
  }

  void _pick(MailAddress a) {
    final text = withRecipient(widget.controller.text, a);
    widget.controller.value = TextEditingValue(
        text: text, selection: TextSelection.collapsed(offset: text.length));
    _clear();
  }

  @override
  Widget build(BuildContext context) {
    final muted = Brand.muted(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focus,
          enabled: widget.enabled,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: widget.decoration,
        ),
        if (_found.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              for (final a in _found.take(_shown))
                ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 16,
                    child: Text(initials(a.personalName ?? a.email),
                        style: const TextStyle(fontSize: 12)),
                  ),
                  title: Text(a.personalName ?? a.email,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(a.email,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => _pick(a),
                ),
              if (_found.length > _shown)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: Text('Ещё ${_found.length - _shown} — уточните запрос',
                      style: TextStyle(color: muted, fontSize: 12.5)),
                ),
            ]),
          ),
      ],
    );
  }
}

/// «ОА» for «Орлов Антон Дмитриевич».
String initials(String name) => name
    .split(RegExp(r'\s+'))
    .where((w) => w.isNotEmpty)
    .take(2)
    .map((w) => w.characters.first.toUpperCase())
    .join();
