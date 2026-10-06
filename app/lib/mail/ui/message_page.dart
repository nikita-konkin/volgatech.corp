import 'dart:async';

import 'package:enough_mail/enough_mail.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../theme.dart';
import '../attachments.dart';
import '../compose.dart';
import '../mail_controller.dart';
import '../mail_html.dart';
import '../mail_models.dart';
import 'compose_page.dart';
import 'mail_actions.dart';
import 'recipient_field.dart' show initials;

/// One message: sender, recipients, attachments and the body.
class MessagePage extends StatefulWidget {
  const MessagePage({super.key, required this.header});
  final MailHeader header;

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  late Future<MimeMessage> _message = _load();

  Future<MimeMessage> _load() =>
      context.read<MailController>().open(widget.header);

  /// Pinned, as far as this page knows: it changes here.
  late bool _pinned = widget.header.pinned;

  Future<void> _delete() async {
    final c = context.read<MailController>();
    Navigator.pop(context);
    await c.delete(widget.header);
  }

  Future<void> _move() async {
    final to = await pickFolder(context, context.read<MailController>());
    if (to == null || !mounted) return;
    moveMessages(context, [widget.header], to);
    Navigator.pop(context);
  }

  Future<void> _archive() async {
    if (await archiveMessages(context, [widget.header]) && mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _togglePin() async {
    if (await togglePin(context, widget.header.copyWith(pinned: _pinned)) &&
        mounted) {
      setState(() => _pinned = !_pinned);
    }
  }

  Future<void> _markUnread() async {
    final c = context.read<MailController>();
    Navigator.pop(context);
    await c.markUnread(widget.header);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (context.read<MailController>().folder.role != FolderRole.archive)
            IconButton(
              tooltip: 'В архив',
              icon: const Icon(Icons.archive_outlined),
              onPressed: () => unawaited(_archive()),
            ),
          IconButton(
            tooltip: 'Удалить',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => unawaited(_delete()),
          ),
          IconButton(
            tooltip: 'Переместить',
            icon: const Icon(Icons.drive_file_move_outline),
            onPressed: () => unawaited(_move()),
          ),
          IconButton(
            tooltip: _pinned ? 'Открепить' : 'Закрепить',
            icon: Icon(_pinned ? Icons.push_pin : Icons.push_pin_outlined),
            onPressed: () => unawaited(_togglePin()),
          ),
          IconButton(
            tooltip: 'Отметить непрочитанным',
            icon: const Icon(Icons.mark_email_unread_outlined),
            onPressed: () => unawaited(_markUnread()),
          ),
        ],
      ),
      body: FutureBuilder<MimeMessage>(
        future: _message,
        builder: (context, snap) {
          if (snap.hasError) {
            return _Failed(onRetry: () => setState(() => _message = _load()));
          }
          final m = snap.data;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Head(header: widget.header, message: m),
              if (m == null)
                const Expanded(
                    child: Center(child: CircularProgressIndicator()))
              else ...[
                _Attachments(m),
                Expanded(child: _Body(m)),
                _ReplyBar(m),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Head extends StatelessWidget {
  const _Head({required this.header, this.message});
  final MailHeader header;
  final MimeMessage? message;

  @override
  Widget build(BuildContext context) {
    final muted = Brand.muted(context);
    String people(List<MailAddress>? list) => [
          for (final a in list ?? const <MailAddress>[])
            (a.personalName?.trim().isNotEmpty ?? false)
                ? a.personalName!.trim()
                : a.email,
        ].join(', ');
    final to = people(message?.to);
    final cc = people(message?.cc);
    final date = header.date == null
        ? ''
        : DateFormat('d MMMM y, HH:mm', 'ru_RU').format(header.date!.toLocal());
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            header.subject.isEmpty ? '(без темы)' : header.subject,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          // Tap for the people: write to one, or copy an address.
          InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => unawaited(showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              isScrollControlled: true,
              builder: (_) => ChangeNotifierProvider.value(
                value: context.read<MailController>(),
                child: _People(header: header, message: message),
              ),
            )),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                          TextSpan(children: [
                            TextSpan(
                                text: header.from,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            if (header.fromName.isNotEmpty &&
                                header.fromEmail.isNotEmpty)
                              TextSpan(
                                  text: '  <${header.fromEmail}>',
                                  style: TextStyle(color: muted, fontSize: 13)),
                          ]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      if (to.isNotEmpty)
                        Text('Кому: $to',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: muted, fontSize: 13)),
                      if (cc.isNotEmpty)
                        Text('Копия: $cc',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: muted, fontSize: 13)),
                    ],
                  ),
                ),
                Icon(Icons.expand_more, color: muted),
              ]),
            ),
          ),
          Text(
              [
                if (date.isNotEmpty) date,
                if (header.size case final size?) fileSize(size),
              ].join(' · '),
              style: TextStyle(color: muted, fontSize: 13)),
        ],
      ),
    );
  }
}

/// Everyone on the message, each to write to or copy.
class _People extends StatelessWidget {
  const _People({required this.header, this.message});
  final MailHeader header;
  final MimeMessage? message;

  @override
  Widget build(BuildContext context) {
    final m = message;
    final from = m?.from ??
        [
          if (header.fromEmail.isNotEmpty)
            MailAddress(header.fromName, header.fromEmail)
        ];
    final groups = {
      'От': from,
      'Кому': m?.to ?? const <MailAddress>[],
      'Копия': m?.cc ?? const <MailAddress>[],
    };
    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: ListView(shrinkWrap: true, children: [
          for (final MapEntry(key: label, value: people) in groups.entries)
            if (people.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(label,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600)),
              ),
              for (final a in people) _Person(a),
            ],
        ]),
      ),
    );
  }
}

class _Person extends StatelessWidget {
  const _Person(this.a);
  final MailAddress a;

  @override
  Widget build(BuildContext context) {
    final name = a.personalName?.trim() ?? '';
    return ListTile(
      leading: CircleAvatar(
          child: Text(initials(name.isEmpty ? a.email : name),
              style: const TextStyle(fontSize: 13))),
      title: Text(name.isEmpty ? a.email : name,
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: name.isEmpty
          ? null
          : Text(a.email, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
          tooltip: 'Написать',
          icon: const Icon(Icons.edit_outlined),
          onPressed: () {
            final c = context.read<MailController>();
            final navigator = Navigator.of(context)..pop();
            unawaited(navigator.push(MaterialPageRoute<void>(
              builder: (_) => ChangeNotifierProvider.value(
                value: c,
                child:
                    ComposePage(draft: ComposeDraft(to: formatAddresses([a]))),
              ),
            )));
          },
        ),
        IconButton(
          tooltip: 'Скопировать адрес',
          icon: const Icon(Icons.copy_outlined),
          onPressed: () {
            unawaited(Clipboard.setData(ClipboardData(text: a.email)));
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Скопировано: ${a.email}')));
          },
        ),
      ]),
    );
  }
}

class _Attachments extends StatelessWidget {
  const _Attachments(this.message);
  final MimeMessage message;

  Future<void> _choose(BuildContext context, ContentInfo info) async {
    final messenger = ScaffoldMessenger.of(context);
    final bytes = message.getPart(info.fetchId)?.decodeContentBinary();
    if (bytes == null) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Не удалось прочитать вложение')));
      return;
    }
    final name = attachmentFileName(info.fileName);
    final file = _Received(
      name: name,
      bytes: bytes,
      type: attachmentType(name, info.mediaType),
    );
    final action = await showModalBottomSheet<_FileAction>(
      context: context,
      showDragHandle: true,
      builder: (_) => _FileSheet(file),
    );
    switch (action) {
      case null:
        return;
      case _FileAction.open:
        await file.open(messenger);
      case _FileAction.save:
        await file.save(messenger);
      case _FileAction.share:
        await file.share();
    }
  }

  @override
  Widget build(BuildContext context) {
    final files = message.findContentInfo();
    if (files.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final f in files)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                avatar: const Icon(Icons.attach_file, size: 18),
                label: Text([
                  f.fileName ?? 'вложение',
                  if (f.size != null) fileSize(f.size!),
                ].join(' · ')),
                onPressed: () => unawaited(_choose(context, f)),
              ),
            ),
        ],
      ),
    );
  }
}

enum _FileAction { open, save, share }

/// A decoded attachment and what can be done with it.
class _Received {
  const _Received({required this.name, required this.bytes, this.type});
  final String name;
  final Uint8List bytes;
  final String? type;

  /// In whichever app handles the type (a PDF reader, Word, a gallery…).
  Future<void> open(ScaffoldMessengerState messenger) async {
    final file = await attachmentFile(name, bytes);
    final result = await OpenFilex.open(file.path, type: type);
    switch (result.type) {
      case ResultType.done:
        return;
      case ResultType.noAppToOpen:
        messenger.showSnackBar(SnackBar(
          content: const Text('Нет приложения, чтобы открыть этот файл'),
          // Goes after its duration (with an action Flutter would keep it).
          persist: false,
          action: SnackBarAction(
              label: 'Сохранить', onPressed: () => unawaited(save(messenger))),
        ));
      case _:
        messenger.showSnackBar(
            const SnackBar(content: Text('Не удалось открыть файл')));
    }
  }

  /// Through the system «save as» dialog — Загрузки or any folder, drive.
  Future<void> save(ScaffoldMessengerState messenger) async {
    try {
      final saved = await FilePicker.saveFile(fileName: name, bytes: bytes);
      if (saved != null) {
        messenger.showSnackBar(SnackBar(content: Text('Сохранено: $name')));
      }
    } on Object {
      messenger.showSnackBar(
          const SnackBar(content: Text('Не удалось сохранить файл')));
    }
  }

  Future<void> share() async {
    final file = await attachmentFile(name, bytes);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: type)],
    ));
  }
}

class _FileSheet extends StatelessWidget {
  const _FileSheet(this.file);
  final _Received file;

  @override
  Widget build(BuildContext context) {
    Widget action(IconData icon, String label, _FileAction value) => ListTile(
          leading: Icon(icon),
          title: Text(label),
          onTap: () => Navigator.pop(context, value),
        );
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(file.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                Text(fileSize(file.bytes.length),
                    style: TextStyle(color: Brand.muted(context))),
              ],
            ),
          ),
          action(Icons.open_in_new, 'Открыть', _FileAction.open),
          action(Icons.download_outlined, 'Сохранить в…', _FileAction.save),
          action(Icons.share_outlined, 'Поделиться', _FileAction.share),
        ],
      ),
    );
  }
}

/// «840 Б», «12 КБ», «3,4 МБ», «1,8 ГБ».
String fileSize(int bytes) {
  if (bytes < 1024) return '$bytes Б';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} КБ';
  String one(double v) => v.toStringAsFixed(1).replaceAll('.', ',');
  final mb = bytes / (1024 * 1024);
  if (mb < 1024) return '${one(mb)} МБ';
  return '${one(mb / 1024)} ГБ';
}

class _Body extends StatefulWidget {
  const _Body(this.message);
  final MimeMessage message;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  late final WebViewController _web = WebViewController();

  @override
  void initState() {
    super.initState();
    // No JavaScript; links leave the app instead of loading in the reader.
    unawaited(_web.setJavaScriptMode(JavaScriptMode.disabled));
    unawaited(_web.setBackgroundColor(Colors.white));
    unawaited(_web.setNavigationDelegate(NavigationDelegate(
      onNavigationRequest: (req) {
        final uri = Uri.tryParse(req.url);
        if (uri != null &&
            const ['http', 'https', 'mailto', 'tel'].contains(uri.scheme)) {
          unawaited(launchUrl(uri, mode: LaunchMode.externalApplication));
          return NavigationDecision.prevent;
        }
        return req.isMainFrame
            ? NavigationDecision.navigate
            : NavigationDecision.prevent;
      },
    )));
    unawaited(_web.loadHtmlString(messageHtml(widget.message)));
  }

  @override
  Widget build(BuildContext context) => WebViewWidget(controller: _web);
}

class _ReplyBar extends StatelessWidget {
  const _ReplyBar(this.message);
  final MimeMessage message;

  void _compose(BuildContext context, String title, ComposeDraft draft) {
    final c = context.read<MailController>();
    unawaited(Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ChangeNotifierProvider.value(
        value: c,
        child: ComposePage(draft: draft, title: title),
      ),
    )));
  }

  @override
  Widget build(BuildContext context) {
    final login = context.read<MailController>().login ?? '';
    Widget action(IconData icon, String label, VoidCallback onTap) => Expanded(
          child: TextButton.icon(
            icon: Icon(icon, size: 20),
            label: Text(label, overflow: TextOverflow.ellipsis),
            onPressed: onTap,
          ),
        );
    return SafeArea(
      top: false,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(children: [
            action(
                Icons.reply,
                'Ответить',
                () => _compose(context, 'Ответ',
                    ComposeDraft.reply(message, all: false, myLogin: login))),
            action(
                Icons.reply_all,
                'Всем',
                () => _compose(context, 'Ответ всем',
                    ComposeDraft.reply(message, all: true, myLogin: login))),
            action(
                Icons.forward,
                'Переслать',
                () => _compose(
                    context, 'Пересылка', ComposeDraft.forward(message))),
          ]),
        ),
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cloud_off, size: 48, color: Brand.muted(context)),
          const SizedBox(height: 12),
          Text('Не удалось загрузить письмо',
              style: TextStyle(color: Brand.muted(context))),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Повторить')),
        ]),
      );
}
