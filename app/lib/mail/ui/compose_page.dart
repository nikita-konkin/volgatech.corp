import 'dart:async';

import 'package:enough_mail/enough_mail.dart' show MediaType;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/prefs.dart';
import '../../theme.dart';
import '../compose.dart';
import '../mail_controller.dart';
import 'message_page.dart' show fileSize;
import 'recipient_field.dart';

/// New message, reply or forward.
class ComposePage extends StatefulWidget {
  const ComposePage(
      {super.key, required this.draft, this.title = 'Новое письмо'});
  final ComposeDraft draft;
  final String title;

  @override
  State<ComposePage> createState() => _ComposePageState();
}

class _ComposePageState extends State<ComposePage> {
  late final _to = TextEditingController(text: widget.draft.to);
  late final _cc = TextEditingController(text: widget.draft.cc);
  late final _subject = TextEditingController(text: widget.draft.subject);
  late final _text = TextEditingController(
      text: widget.draft.signedAlready
          ? widget.draft.text
          : signed(widget.draft.text,
              context.read<Prefs>().signatureFor(reply: widget.draft.quotes)));
  late bool _showCc = widget.draft.cc.isNotEmpty;
  late bool _banner = widget.draft.fromPhone;
  bool _sending = false;
  String? _error;

  /// The form as it opened, to tell whether leaving loses anything.
  late final String _start;

  @override
  void initState() {
    super.initState();
    // Replies start above the quote.
    _text.selection = const TextSelection.collapsed(offset: 0);
    _start = _snapshot();
  }

  String _snapshot() => [
        _to.text,
        _cc.text,
        _subject.text,
        _text.text,
        '${widget.draft.attachments.length}',
      ].join('\u0000');

  ComposeDraft _filled() => widget.draft
    ..to = _to.text
    ..cc = _cc.text
    ..subject = _subject.text
    ..text = _text.text;

  /// Left without sending: what was written stays on the phone, for
  /// «Написать» to bring back.
  void _left() {
    if (_sending) return;
    final prefs = context.read<Prefs>();
    // Only a signature (or nothing) is not worth keeping.
    final written = [_to, _cc, _subject].any((c) => c.text.trim().isNotEmpty) ||
        _text.text.trim() !=
            signed('', prefs.signatureFor(reply: false)).trim();
    if (!written && widget.draft.fromPhone) {
      unawaited(prefs.setMailDraft(null)); // emptied: forget it
    }
    if (!written || _snapshot() == _start) return;
    unawaited(prefs.setMailDraft(_filled().toJson()));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
          content: Text('Черновик сохранён — он откроется в «Написать»')));
  }

  /// «Удалить» on a brought-back draft: a clean new message instead.
  void _discard() {
    final c = context.read<MailController>();
    unawaited(context.read<Prefs>().setMailDraft(null));
    _sending = true; // nothing to keep on the way out
    unawaited(Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
      builder: (_) => ChangeNotifierProvider.value(
          value: c, child: ComposePage(draft: ComposeDraft())),
    )));
  }

  @override
  void dispose() {
    for (final c in [_to, _cc, _subject, _text]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Exchange's usual limit for a whole message is 25 MB, base64 included.
  static const _maxAttachments = 18 * 1024 * 1024;

  Future<void> _attach() async {
    final picked =
        await FilePicker.pickFiles(allowMultiple: true, withData: true);
    if (picked == null || !mounted) return;
    final list = widget.draft.attachments;
    var total = list.fold<int>(0, (n, a) => n + a.bytes.length);
    final skipped = <String>[];
    for (final f in picked.files) {
      final bytes = f.bytes;
      if (bytes == null) continue;
      if (total + bytes.length > _maxAttachments) {
        skipped.add(f.name);
        continue;
      }
      total += bytes.length;
      list.add(DraftAttachment(
          f.name, MediaType.guessFromFileName(f.name).text, bytes));
    }
    setState(() => _error = skipped.isEmpty
        ? null
        : 'Не поместилось (вложения до 18 МБ): ${skipped.join(', ')}');
  }

  Future<void> _send() async {
    final to = parseRecipients(_to.text);
    final cc = parseRecipients(_cc.text);
    if (to == null || to.isEmpty || cc == null) {
      setState(() => _error = to != null && to.isEmpty
          ? 'Укажите получателя'
          : 'Проверьте адреса: через запятую, вида name@volgatech.net');
      return;
    }
    final draft = _filled();
    final c = context.read<MailController>();
    final prefs = context.read<Prefs>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    _sending = true;
    if (widget.draft.fromPhone) unawaited(prefs.setMailDraft(null));
    navigator.pop(true);
    // A few seconds to take it back, as in Gmail.
    final outcome = c.sendSoon(draft);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('Письмо отправляется…'),
        duration: const Duration(seconds: 5),
        // Goes after its duration (with an action Flutter would keep it).
        persist: false,
        action: SnackBarAction(
          label: 'Отменить',
          onPressed: () {
            final back = c.cancelSend();
            if (back == null) return;
            unawaited(navigator.push(MaterialPageRoute<void>(
              builder: (_) => ChangeNotifierProvider.value(
                value: c,
                child: ComposePage(
                    draft: back..signedAlready = true, title: widget.title),
              ),
            )));
          },
        ),
      ));
    final result = await outcome;
    if (identical(result, sendCancelled)) return;
    if (result == null) {
      messenger
          .showSnackBar(const SnackBar(content: Text('Письмо отправлено')));
    } else {
      // Nothing written is lost: «Написать» brings it back.
      await prefs.setMailDraft(draft.toJson());
      messenger.showSnackBar(SnackBar(
        duration: const Duration(seconds: 8),
        content: Text('Письмо не отправлено: $result. '
            'Текст сохранён — он откроется в «Написать».'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = Brand.muted(context);
    InputDecoration field(String label, {Widget? suffix}) => InputDecoration(
          labelText: label,
          suffixIcon: suffix,
          filled: false,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        );
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _left();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            IconButton(
              tooltip: 'Прикрепить файл',
              icon: const Icon(Icons.attach_file),
              onPressed: _sending ? null : () => unawaited(_attach()),
            ),
            IconButton(
              tooltip: 'Отправить',
              icon: const Icon(Icons.send),
              onPressed: _sending ? null : () => unawaited(_send()),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            if (_banner)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  Expanded(
                    child: Text(
                        widget.draft.lostAttachments > 0
                            ? 'Восстановлен черновик — вложения не сохранились'
                            : 'Восстановлен несохранённый черновик',
                        style: const TextStyle(fontSize: 13.5)),
                  ),
                  TextButton(onPressed: _discard, child: const Text('Удалить')),
                  IconButton(
                    tooltip: 'Скрыть',
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _banner = false),
                  ),
                ]),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child:
                    Text(_error!, style: const TextStyle(color: Brand.coral)),
              ),
            RecipientField(
              controller: _to,
              enabled: !_sending,
              decoration: field('Кому',
                  suffix: _showCc
                      ? null
                      : TextButton(
                          onPressed: () => setState(() => _showCc = true),
                          child: const Text('Копия'))),
            ),
            if (_showCc) ...[
              const Divider(height: 1),
              RecipientField(
                controller: _cc,
                enabled: !_sending,
                decoration: field('Копия'),
              ),
            ],
            const Divider(height: 1),
            TextField(
              controller: _subject,
              enabled: !_sending,
              textCapitalization: TextCapitalization.sentences,
              decoration: field('Тема'),
            ),
            const Divider(height: 1),
            if (widget.draft.attachments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Wrap(spacing: 8, runSpacing: 4, children: [
                  for (final a in widget.draft.attachments)
                    InputChip(
                      avatar: const Icon(Icons.attach_file, size: 18),
                      label: Text('${a.name} · ${fileSize(a.bytes.length)}'),
                      onDeleted: _sending
                          ? null
                          : () => setState(
                              () => widget.draft.attachments.remove(a)),
                    ),
                ]),
              ),
            TextField(
              controller: _text,
              enabled: !_sending,
              maxLines: null,
              minLines: 8,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Текст письма',
                hintStyle: TextStyle(color: muted),
                filled: false,
                border: InputBorder.none,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
