import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/prefs.dart';
import '../../theme.dart';
import '../mail_controller.dart';

/// «Подпись»: the text added under new messages (and replies), as in
/// Outlook on the web. The first time, the web mail's own is offered.
class SignaturePage extends StatefulWidget {
  const SignaturePage({super.key});

  @override
  State<SignaturePage> createState() => _SignaturePageState();
}

class _SignaturePageState extends State<SignaturePage> {
  late final Prefs _prefs = context.read<Prefs>();
  late final _text = TextEditingController(text: _prefs.mailSignature ?? '');
  late bool _onNew = _prefs.mailSignNew;
  late bool _onReplies = _prefs.mailSignReplies;
  bool _importing = false;
  bool _imported = false;

  @override
  void initState() {
    super.initState();
    if (_prefs.mailSignature == null) unawaited(_import());
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _import() async {
    setState(() => _importing = true);
    final web = await context.read<MailController>().webSignature();
    if (!mounted) return;
    setState(() {
      _importing = false;
      // Unless the user started writing one meanwhile.
      if (web != null && _text.text.isEmpty) {
        _text.text = web;
        _imported = true;
        unawaited(_prefs.setMailSignature(web));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final muted = Brand.muted(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Подпись')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          TextField(
            controller: _text,
            minLines: 4,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (v) => unawaited(_prefs.setMailSignature(v)),
            decoration: InputDecoration(
              hintText: 'Например: С уважением, Иванов И.И.',
              suffixIcon: _importing
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_imported ? 'Взята из веб-почты. ' : ''}'
            'Письма из приложения отправляются текстом, '
            'поэтому картинки в подпись не попадают.',
            style: TextStyle(color: muted, fontSize: 12.5),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('В новых письмах'),
            value: _onNew,
            onChanged: (v) {
              setState(() => _onNew = v);
              unawaited(_prefs.setMailSignNew(v));
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('В ответах и пересылках'),
            subtitle: const Text('Над цитатой исходного письма'),
            value: _onReplies,
            onChanged: (v) {
              setState(() => _onReplies = v);
              unawaited(_prefs.setMailSignReplies(v));
            },
          ),
        ],
      ),
    );
  }
}
