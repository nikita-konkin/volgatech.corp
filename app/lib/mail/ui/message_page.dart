import 'dart:async';
import 'dart:convert';

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../core/prefs.dart';
import '../../theme.dart';
import '../attachments.dart';
import '../compose.dart';
import '../mail_controller.dart';
import '../mail_html.dart';
import '../mail_models.dart';
import '../mail_text.dart';
import '../text_intents.dart';
import 'attachment_view.dart';
import 'compose_page.dart';
import 'mail_actions.dart';
import 'message_tools.dart';
import 'recipient_field.dart' show initials;

/// One message: sender, recipients, attachments and the body.
class MessagePage extends StatefulWidget {
  const MessagePage({super.key, required this.header});
  final MailHeader header;

  @override
  State<MessagePage> createState() => _MessagePageState();
}

enum _Tool {
  find,
  links,
  quote,
  copy,
  share,
  translate,
  textSize,
  dark,
  images,
  contact,
  unsubscribe,
}

class _MessagePageState extends State<MessagePage> {
  late Future<MimeMessage> _message = _load();
  final _body = GlobalKey<_BodyState>();
  final _intents = const TextIntents();
  late final Prefs _prefs = context.read<Prefs>();
  late int _zoom = _prefs.mailTextZoom;
  late bool _darkBody = _prefs.mailDarkBody;

  /// Pictures from the internet let in: always, for this sender, or for
  /// this letter just now. Never by themselves for a letter marked spam.
  late bool _images = !_spam &&
      (_prefs.mailImagesAlways ||
          _prefs.mailImageSenders
              .contains(widget.header.fromEmail.toLowerCase()));

  bool get _spam => widget.header.subject.contains('*** SPAM ***');

  /// The letter, once here, and its page as last made.
  MimeMessage? _loaded;
  PreparedBody? _page;
  (bool, bool)? _pageMade;

  Future<MimeMessage> _load() async {
    final m = await context.read<MailController>().open(widget.header);
    if (mounted) setState(() => _loaded = m);
    return m;
  }

  bool get _dark =>
      _darkBody && Theme.of(context).brightness == Brightness.dark;

  PreparedBody _pageOf(MimeMessage m) {
    if (_page == null || _pageMade != (_dark, _images)) {
      _page = messageBody(m, dark: _dark, remoteImages: _images);
      _pageMade = (_dark, _images);
    }
    return _page!;
  }

  Future<void> _alwaysImages() async {
    setState(() => _images = true);
    final from = widget.header.fromEmail;
    if (from.isEmpty) return;
    await _prefs.addMailImageSender(from);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Картинки от $from будут показываться сразу')));
  }

  Future<void> _openPicture(String src) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final file = await pictureFrom(src);
    if (file == null || file.preview != PreviewKind.image) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Не удалось открыть картинку')));
      return;
    }
    await navigator.push(
        MaterialPageRoute<void>(builder: (_) => AttachmentViewPage(file)));
  }

  String get _subject =>
      widget.header.subject.isEmpty ? '(без темы)' : widget.header.subject;

  void _onLink(MailLink link) =>
      unawaited(showLinkSheet(context, link, subject: _subject));

  void _compose(String title, ComposeDraft draft) {
    final c = context.read<MailController>();
    unawaited(Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ChangeNotifierProvider.value(
        value: c,
        child: ComposePage(draft: draft, title: title),
      ),
    )));
  }

  Future<void> _tool(_Tool t, MimeMessage m) async {
    final messenger = ScaffoldMessenger.of(context);
    final text = tidyText(plainTextOf(m));
    switch (t) {
      case _Tool.find:
        _body.currentState?.openFind();
      case _Tool.links:
        await showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (_) =>
              LinksSheet(links: _pageOf(m).webLinks, onTap: _onLink),
        );
      case _Tool.quote:
        final quote = await _body.currentState?.selection() ?? '';
        if (!mounted) return;
        if (quote.isEmpty) {
          messenger.showSnackBar(const SnackBar(
              content: Text('Выделите в письме текст для цитаты: '
                  'нажмите на него и подержите')));
          return;
        }
        _compose(
            'Ответ',
            ComposeDraft.reply(m,
                all: false,
                myLogin: context.read<MailController>().login ?? '',
                quote: quote));
      case _Tool.copy:
        copied(context, text, what: 'Текст письма скопирован');
      case _Tool.share:
        await SharePlus.instance
            .share(ShareParams(text: text, subject: _subject));
      case _Tool.translate:
        if (!await _intents.translate(text)) {
          // No translator: whoever takes the text.
          await SharePlus.instance
              .share(ShareParams(text: text, subject: _subject));
        }
      case _Tool.textSize:
        await showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (_) => TextSizeSheet(
            percent: _zoom,
            onChanged: (p) {
              setState(() => _zoom = p);
              unawaited(_prefs.setMailTextZoom(p));
            },
          ),
        );
      case _Tool.dark:
        setState(() => _darkBody = !_darkBody);
        await _prefs.setMailDarkBody(_darkBody);
      case _Tool.images:
        final always = !_prefs.mailImagesAlways;
        await _prefs.setMailImagesAlways(always);
        if (always && !_spam) setState(() => _images = true);
      case _Tool.contact:
        final from = m.from?.firstOrNull;
        final taken = await _intents.addContact(
          name: from?.personalName?.trim(),
          email: from?.email ?? widget.header.fromEmail,
          phone: signaturePhone(plainTextOf(m))?.split(',').first,
        );
        if (!taken) {
          messenger.showSnackBar(const SnackBar(
              content: Text('На телефоне нет приложения контактов')));
        }
      case _Tool.unsubscribe:
        await _unsubscribe(m);
    }
  }

  Future<void> _unsubscribe(MimeMessage m) async {
    final target = unsubscribeTarget(m.getHeaderValue('list-unsubscribe'));
    if (target == null) return;
    final byMail = target.toLowerCase().startsWith('mailto:');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отписаться от рассылки?'),
        content: Text(byMail
            ? 'Рассылка просит письмо на ${parseMailto(target).to} — '
                'оно откроется готовым к отправке.'
            : 'Откроется страница отписки на '
                '${Uri.tryParse(target)?.host ?? target}.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Отписаться')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (byMail) {
      final to = parseMailto(target);
      _compose(
          'Отписка',
          ComposeDraft(
              to: to.to,
              subject: to.subject.isEmpty ? 'unsubscribe' : to.subject,
              text: to.body));
    } else {
      await launchUrl(Uri.parse(target), mode: LaunchMode.externalApplication);
    }
  }

  Widget _tools(MimeMessage m) {
    final page = _pageOf(m);
    final links = page.webLinks.length;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final unsubscribe =
        unsubscribeTarget(m.getHeaderValue('list-unsubscribe')) != null;
    PopupMenuItem<_Tool> item(_Tool t, IconData icon, String label) =>
        PopupMenuItem(
          value: t,
          child: ListTile(
            leading: Icon(icon),
            title: Text(label),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        );
    return PopupMenuButton<_Tool>(
      tooltip: 'Ещё',
      onSelected: (t) => unawaited(_tool(t, m)),
      itemBuilder: (_) => [
        item(_Tool.find, Icons.search, 'Найти в письме'),
        if (links > 0)
          item(_Tool.links, Icons.link, 'Ссылки в письме · $links'),
        item(_Tool.quote, Icons.format_quote_outlined,
            'Ответить с цитатой выделенного'),
        item(_Tool.copy, Icons.copy_outlined, 'Копировать текст'),
        item(_Tool.share, Icons.share_outlined, 'Поделиться текстом'),
        item(_Tool.translate, Icons.translate, 'Перевести'),
        item(_Tool.textSize, Icons.format_size, 'Размер текста'),
        if (dark)
          CheckedPopupMenuItem(
              value: _Tool.dark,
              checked: _darkBody,
              child: const Text('Тёмный фон письма')),
        CheckedPopupMenuItem(
            value: _Tool.images,
            checked: _prefs.mailImagesAlways,
            child: const Text('Всегда показывать картинки')),
        if (_intents.available)
          item(_Tool.contact, Icons.person_add_alt,
              'Сохранить отправителя в контакты'),
        if (unsubscribe)
          item(_Tool.unsubscribe, Icons.unsubscribe_outlined,
              'Отписаться от рассылки'),
      ],
    );
  }

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
          if (_loaded case final m?) _tools(m),
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
                _Attachments(m, meeting: _pageOf(m).meeting, onLink: _onLink),
                if (!_images && _pageOf(m).remoteImages > 0)
                  ImagesBanner(
                    spam: _spam,
                    onShow: () => setState(() => _images = true),
                    onAlways: () => unawaited(_alwaysImages()),
                  ),
                Expanded(
                  child: _Body(
                    key: _body,
                    page: _pageOf(m),
                    dark: _dark,
                    zoom: _zoom,
                    onLink: _onLink,
                    onPicture: (src) => unawaited(_openPicture(src)),
                  ),
                ),
                _ReplyBar(m, compose: _compose),
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

/// The letter's attachments, after «Присоединиться» when it invites to an
/// online meeting.
class _Attachments extends StatelessWidget {
  const _Attachments(this.message, {this.meeting, required this.onLink});
  final MimeMessage message;
  final MailLink? meeting;
  final void Function(MailLink) onLink;

  Future<void> _choose(BuildContext context, ContentInfo info) async {
    final messenger = ScaffoldMessenger.of(context);
    final bytes = message.getPart(info.fetchId)?.decodeContentBinary();
    if (bytes == null) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Не удалось прочитать вложение')));
      return;
    }
    final name = attachmentFileName(info.fileName);
    final file = ReceivedFile(
      name: name,
      bytes: bytes,
      type: attachmentType(name, info.mediaType),
    );
    // Pictures, PDFs and text right here; the rest in another app.
    if (file.preview != null) {
      await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => AttachmentViewPage(file)));
      return;
    }
    if (!context.mounted) return;
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
    final call = meeting;
    if (files.isEmpty && call == null) return const SizedBox.shrink();
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          if (call != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                avatar: const Icon(Icons.videocam_outlined, size: 18),
                label: Text('Присоединиться · ${call.meeting}'),
                onPressed: () => onLink(call),
              ),
            ),
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

class _FileSheet extends StatelessWidget {
  const _FileSheet(this.file);
  final ReceivedFile file;

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
  const _Body(
      {super.key,
      required this.page,
      required this.dark,
      required this.zoom,
      required this.onLink,
      required this.onPicture});
  final PreparedBody page;
  final bool dark;

  /// Text size, in percent.
  final int zoom;
  final void Function(MailLink) onLink;

  /// A picture tapped: its address.
  final void Function(String src) onPicture;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  late final WebViewController _web = WebViewController();
  bool _finding = false;
  int? _found;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    // JavaScript for the reader's own find and selection only: the page's
    // policy (mail_html.dart) keeps the letter's scripts from running.
    unawaited(_web.setJavaScriptMode(JavaScriptMode.unrestricted));
    unawaited(_web.enableZoom(true));
    _zoomTo(widget.zoom);
    unawaited(_web.setNavigationDelegate(NavigationDelegate(
      onPageFinished: (_) => unawaited(_run(readerScript)),
      onNavigationRequest: (req) {
        // The letter's links: a sheet of what to do, nothing opens yet.
        if (req.url.startsWith('$kLinkScheme:')) {
          final i = int.tryParse(req.url.substring(kLinkScheme.length + 1));
          final links = widget.page.links;
          if (i != null && i >= 0 && i < links.length) widget.onLink(links[i]);
          return NavigationDecision.prevent;
        }
        if (req.url.startsWith('$kImageScheme:')) {
          final i = int.tryParse(req.url.substring(kImageScheme.length + 1));
          if (i != null) unawaited(_picture(i));
          return NavigationDecision.prevent;
        }
        final uri = Uri.tryParse(req.url);
        if (uri != null &&
            const ['http', 'https', 'mailto', 'tel'].contains(uri.scheme)) {
          // Not a link the page was made with (an image map, a refresh):
          // the same sheet.
          if (req.isMainFrame) widget.onLink(linkFor(req.url, ''));
          return NavigationDecision.prevent;
        }
        return req.isMainFrame
            ? NavigationDecision.navigate
            : NavigationDecision.prevent;
      },
    )));
    _show();
  }

  void _show() {
    unawaited(
        _web.setBackgroundColor(widget.dark ? Colors.black : Colors.white));
    unawaited(_web.loadHtmlString(widget.page.html));
  }

  void _zoomTo(int percent) {
    if (_web.platform case final AndroidWebViewController android) {
      unawaited(android.setTextZoom(percent));
    }
  }

  @override
  void didUpdateWidget(_Body old) {
    super.didUpdateWidget(old);
    if (old.page.html != widget.page.html) {
      _show();
      _found = null;
    }
    if (old.zoom != widget.zoom) _zoomTo(widget.zoom);
  }

  Future<Object?> _run(String script) async {
    try {
      return await _web.runJavaScriptReturningResult(script);
    } on Object {
      return null; // the page not there yet, or gone
    }
  }

  void openFind() => setState(() => _finding = true);

  Future<void> _picture(int index) async {
    final r = await _run(imageScript(index));
    final src = r is String && r.startsWith('"') ? jsonDecode(r) as String : '';
    if (src.isNotEmpty && mounted) widget.onPicture(src);
  }

  Future<void> _find(String query, int index) async {
    final n = switch (await _run(findScript(query, index))) {
      final num n => n.toInt(),
      final Object r => int.tryParse('$r') ?? 0,
      null => 0,
    };
    if (!mounted) return;
    setState(() {
      _found = query.isEmpty ? null : n;
      _current = n == 0 ? 0 : (index % n + n) % n;
    });
  }

  void _closeFind() {
    unawaited(_run(findScript('', 0)));
    setState(() {
      _finding = false;
      _found = null;
      _current = 0;
    });
  }

  /// The text selected in the letter, or selected last.
  Future<String> selection() async {
    final r = await _run(selectionScript);
    // Android hands strings back JSON-quoted.
    final text = r is String && r.startsWith('"')
        ? jsonDecode(r) as String
        : '${r ?? ''}';
    return text.trim();
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        if (_finding)
          FindBar(
            onFind: (q, i) => unawaited(_find(q, i)),
            onClose: _closeFind,
            found: _found,
            current: _current,
          ),
        Expanded(child: WebViewWidget(controller: _web)),
      ]);
}

class _ReplyBar extends StatelessWidget {
  const _ReplyBar(this.message, {required this.compose});
  final MimeMessage message;
  final void Function(String title, ComposeDraft draft) compose;

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
                () => compose('Ответ',
                    ComposeDraft.reply(message, all: false, myLogin: login))),
            action(
                Icons.reply_all,
                'Всем',
                () => compose('Ответ всем',
                    ComposeDraft.reply(message, all: true, myLogin: login))),
            action(Icons.forward, 'Переслать',
                () => compose('Пересылка', ComposeDraft.forward(message))),
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
