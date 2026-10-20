import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme.dart';
import '../compose.dart';
import '../mail_controller.dart';
import '../mail_text.dart';
import '../text_intents.dart';
import 'attachment_view.dart';
import 'compose_page.dart';

/// What can be done with a link, an address, a number or a date tapped in
/// a letter whose subject is [subject] — nothing opens without a choice.
Future<void> showLinkSheet(BuildContext context, MailLink link,
    {required String subject, TextIntents intents = const TextIntents()}) {
  final mail = context.read<MailController>();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => ChangeNotifierProvider.value(
      value: mail,
      child: LinkSheet(link: link, subject: subject, intents: intents),
    ),
  );
}

/// A new message from a `mailto:` link.
void composeTo(NavigatorState navigator, MailController mail, String mailto) {
  final m = parseMailto(mailto);
  unawaited(navigator.push(MaterialPageRoute<void>(
    builder: (_) => ChangeNotifierProvider.value(
      value: mail,
      child: ComposePage(
          draft: ComposeDraft(
              to: m.to, cc: m.cc, subject: m.subject, text: m.body)),
    ),
  )));
}

void copied(BuildContext context, String text, {String? what}) {
  unawaited(Clipboard.setData(ClipboardData(text: text)));
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(what ?? 'Скопировано: $text',
          maxLines: 2, overflow: TextOverflow.ellipsis)));
}

/// A picture from the letter, to look at closely: a `data:` one decoded, a
/// web one downloaded (it's on the page already, so nothing new is told).
/// Null when it can't be had.
Future<ReceivedFile?> pictureFrom(String src) async {
  if (src.startsWith('data:')) {
    final data = Uri.tryParse(src)?.data;
    if (data == null) return null;
    final type = data.mimeType;
    return ReceivedFile(
        name: 'картинка.${_ext(type)}',
        bytes: data.contentAsBytes(),
        type: type);
  }
  final uri = Uri.tryParse(src);
  if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) {
    return null;
  }
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final res = await (await client.getUrl(uri))
        .close()
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) return null;
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in res.timeout(const Duration(seconds: 30))) {
      bytes.add(chunk);
      if (bytes.length > 20 * 1024 * 1024) return null;
    }
    final type = res.headers.contentType?.mimeType ?? 'image/png';
    final last = uri.pathSegments.where((s) => s.isNotEmpty).lastOrNull;
    final name = last != null && last.contains('.')
        ? Uri.decodeComponent(last)
        : 'картинка.${_ext(type)}';
    return ReceivedFile(name: name, bytes: bytes.takeBytes(), type: type);
  } on Object {
    return null;
  } finally {
    client.close(force: true);
  }
}

String _ext(String type) => switch (type.toLowerCase()) {
      'image/jpeg' || 'image/jpg' => 'jpg',
      'image/gif' => 'gif',
      'image/webp' => 'webp',
      'image/bmp' => 'bmp',
      'image/svg+xml' => 'svg',
      _ => 'png',
    };

/// «Картинки из интернета скрыты»: show them here, or always for [sender].
class ImagesBanner extends StatelessWidget {
  const ImagesBanner(
      {super.key,
      required this.spam,
      required this.onShow,
      this.onAlways});
  /// The server marked the letter as spam: shown once, never always.
  final bool spam;
  final VoidCallback onShow;
  final VoidCallback? onAlways;

  @override
  Widget build(BuildContext context) {
    final muted = Brand.muted(context);
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
        child: Row(children: [
          Icon(Icons.image_not_supported_outlined, size: 20, color: muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
                spam
                    ? 'Картинки скрыты: письмо помечено как спам'
                    : 'Картинки из интернета скрыты',
                style: const TextStyle(fontSize: 13.5)),
          ),
          TextButton(onPressed: onShow, child: const Text('Показать')),
          if (onAlways != null && !spam)
            TextButton(onPressed: onAlways, child: const Text('Всегда')),
        ]),
      ),
    );
  }
}

/// «14 октября 2026, 15:00».
String dateLabel(MailLink l) {
  final when = l.when!;
  final day = DateFormat('d MMMM y', 'ru_RU').format(when);
  return l.hasTime ? '$day, ${DateFormat('HH:mm').format(when)}' : day;
}

class LinkSheet extends StatelessWidget {
  const LinkSheet(
      {super.key,
      required this.link,
      required this.subject,
      this.intents = const TextIntents()});
  final MailLink link;
  final String subject;
  final TextIntents intents;

  @override
  Widget build(BuildContext context) {
    final l = link;
    final muted = Brand.muted(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final mail = context.read<MailController>();
    // Each action closes the sheet first, then does its thing.
    Widget action(IconData icon, String label, void Function() run,
            {String? hint}) =>
        ListTile(
          leading: Icon(icon),
          title: Text(label),
          subtitle: hint == null ? null : Text(hint),
          onTap: () {
            navigator.pop();
            run();
          },
        );
    void open(String url) => unawaited(
        launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication));
    void copy(String text, [String? what]) {
      unawaited(Clipboard.setData(ClipboardData(text: text)));
      messenger.showSnackBar(SnackBar(
          content: Text(what ?? 'Скопировано: $text',
              maxLines: 2, overflow: TextOverflow.ellipsis)));
    }

    void notTaken(bool taken) {
      if (!taken) {
        messenger.showSnackBar(const SnackBar(
            content: Text('На телефоне нет подходящего приложения')));
      }
    }

    final (IconData icon, String title, Widget? detail) = switch (l.kind) {
      LinkKind.web || LinkKind.meeting => (
          l.kind == LinkKind.meeting ? Icons.videocam_outlined : Icons.link,
          l.meeting ??
              (l.text.isEmpty || l.text == l.target ? 'Ссылка' : l.text),
          _Address(l.target),
        ),
      LinkKind.mail => (Icons.alternate_email, l.value, null),
      LinkKind.phone => (Icons.phone_outlined, formatPhone(l.value), null),
      LinkKind.date => (Icons.event_outlined, dateLabel(l), null),
    };
    final shownOther = l.text.isNotEmpty &&
        l.text != l.target &&
        l.text != l.value &&
        l.kind != LinkKind.date;

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 12),
                  child:
                      Icon(icon, color: Theme.of(context).colorScheme.primary),
                ),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        if (detail != null) ...[
                          const SizedBox(height: 4),
                          detail,
                        ],
                        if (l.kind == LinkKind.mail && shownOther)
                          Text(l.text, style: TextStyle(color: muted)),
                      ]),
                ),
              ]),
            ),
            if (l.suspicious) _Warning(link: l),
            ...switch (l.kind) {
              LinkKind.web || LinkKind.meeting => [
                  if (l.kind == LinkKind.meeting)
                    action(Icons.videocam_outlined, 'Присоединиться',
                        () => open(l.target), hint: 'Откроется ${l.meeting}')
                  else
                    action(Icons.open_in_browser, 'Открыть в браузере',
                        () => open(l.target)),
                  action(Icons.copy_outlined, 'Копировать ссылку',
                      () => copy(l.target, 'Ссылка скопирована')),
                  if (shownOther)
                    action(Icons.short_text, 'Копировать текст ссылки',
                        () => copy(l.text)),
                  action(
                      Icons.share_outlined,
                      'Поделиться',
                      () => unawaited(SharePlus.instance.share(
                          ShareParams(text: l.target, subject: subject)))),
                ],
              LinkKind.mail => [
                  action(Icons.edit_outlined, 'Написать',
                      () => composeTo(navigator, mail, l.target)),
                  action(Icons.copy_outlined, 'Копировать адрес',
                      () => copy(l.value)),
                  if (intents.available)
                    action(
                        Icons.person_add_alt,
                        'Добавить в контакты',
                        () async => notTaken(await intents.addContact(
                            name: shownOther ? l.text : null, email: l.value))),
                ],
              LinkKind.phone => [
                  action(Icons.call_outlined, 'Позвонить',
                      () => open('tel:${l.value}'),
                      hint: l.value.contains(',')
                          ? 'Добавочный наберётся после соединения'
                          : null),
                  action(Icons.sms_outlined, 'Написать SMS',
                      () => open('sms:${l.value.split(',').first}')),
                  action(Icons.copy_outlined, 'Копировать номер',
                      () => copy(formatPhone(l.value))),
                  if (intents.available)
                    action(
                        Icons.person_add_alt,
                        'Добавить в контакты',
                        () async => notTaken(await intents.addContact(
                            phone: l.value.split(',').first))),
                ],
              LinkKind.date => [
                  if (intents.available)
                    action(
                        Icons.event_available_outlined,
                        'Добавить в календарь',
                        () async => notTaken(await intents.addEvent(
                              title: subject,
                              start: l.when!,
                              timed: l.hasTime,
                            )),
                        hint: l.hasTime
                            ? 'На час, с ${DateFormat('HH:mm').format(l.when!)}'
                            : 'На весь день'),
                  action(Icons.copy_outlined, 'Копировать', () => copy(l.text)),
                ],
            },
          ],
        ),
      ),
    );
  }
}

/// A web address in full, its site in bold: where the link really leads.
class _Address extends StatelessWidget {
  const _Address(this.url);
  final String url;

  @override
  Widget build(BuildContext context) {
    final muted = Brand.muted(context);
    final u = Uri.tryParse(url);
    final host = u?.host ?? '';
    final at = host.isEmpty ? -1 : url.indexOf(host);
    final style = TextStyle(color: muted, fontSize: 13.5);
    if (at < 0) return SelectableText(url, style: style);
    return SelectableText.rich(
      TextSpan(style: style, children: [
        TextSpan(text: url.substring(0, at)),
        TextSpan(
            text: host,
            style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface)),
        TextSpan(text: url.substring(at + host.length)),
      ]),
    );
  }
}

class _Warning extends StatelessWidget {
  const _Warning({required this.link});
  final MailLink link;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Brand.coral.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.warning_amber_rounded, color: Brand.coral),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
                'Текст ссылки — «${link.text}», а ведёт она на ${link.host}. '
                'Так выглядят фишинговые письма: не вводите пароль на этом '
                'сайте, если не уверены.',
                style: const TextStyle(fontSize: 13.5)),
          ),
        ]),
      );
}

/// Every web link in the letter, each address once.
class LinksSheet extends StatelessWidget {
  const LinksSheet({super.key, required this.links, required this.onTap});
  final List<MailLink> links;
  final void Function(MailLink) onTap;

  @override
  Widget build(BuildContext context) {
    final muted = Brand.muted(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
            child: Row(children: [
              Expanded(
                child: Text('Ссылки в письме · ${links.length}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              TextButton.icon(
                icon: const Icon(Icons.copy_all_outlined, size: 18),
                label: const Text('Копировать все'),
                onPressed: () {
                  Navigator.pop(context);
                  copied(context, links.map((l) => l.target).join('\n'),
                      what: 'Скопировано ссылок: ${links.length}');
                },
              ),
            ]),
          ),
          Flexible(
            child: ListView(shrinkWrap: true, children: [
              for (final l in links)
                ListTile(
                  leading: Icon(
                      l.suspicious
                          ? Icons.warning_amber_rounded
                          : l.kind == LinkKind.meeting
                              ? Icons.videocam_outlined
                              : Icons.link,
                      color: l.suspicious ? Brand.coral : null),
                  title: Text(
                      l.meeting ??
                          (l.text.isEmpty || l.text == l.target
                              ? (l.host ?? l.target)
                              : l.text),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  subtitle: Text(l.target,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: muted, fontSize: 12.5)),
                  onTap: () {
                    Navigator.pop(context);
                    onTap(l);
                  },
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// The letter's text size, applied as the slider moves.
class TextSizeSheet extends StatefulWidget {
  const TextSizeSheet(
      {super.key, required this.percent, required this.onChanged});
  final int percent;
  final ValueChanged<int> onChanged;

  @override
  State<TextSizeSheet> createState() => _TextSizeSheetState();
}

class _TextSizeSheetState extends State<TextSizeSheet> {
  late int _p = widget.percent;

  void _set(int p) {
    setState(() => _p = p.clamp(70, 200));
    widget.onChanged(_p);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Размер текста · $_p%',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Row(children: [
              IconButton(
                tooltip: 'Мельче',
                icon: const Icon(Icons.text_decrease),
                onPressed: () => _set(_p - 10),
              ),
              Expanded(
                child: Slider(
                  value: _p.toDouble(),
                  min: 70,
                  max: 200,
                  divisions: 13,
                  label: '$_p%',
                  onChanged: (v) => _set(v.round()),
                ),
              ),
              IconButton(
                tooltip: 'Крупнее',
                icon: const Icon(Icons.text_increase),
                onPressed: () => _set(_p + 10),
              ),
            ]),
            TextButton(
                onPressed: _p == 100 ? null : () => _set(100),
                child: const Text('Как было')),
          ]),
        ),
      );
}

/// The find-in-letter bar: what to look for, how many, next and previous.
class FindBar extends StatefulWidget {
  const FindBar(
      {super.key,
      required this.onFind,
      required this.onClose,
      required this.found,
      required this.current});

  /// Looks for the text, the given match current (counted from 0).
  final void Function(String query, int index) onFind;
  final VoidCallback onClose;

  /// How many there are, null before the first search; the current one.
  final int? found;
  final int current;

  @override
  State<FindBar> createState() => _FindBarState();
}

class _FindBarState extends State<FindBar> {
  final _q = TextEditingController();
  Timer? _typing;

  @override
  void dispose() {
    _typing?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _changed(String q) {
    _typing?.cancel();
    _typing =
        Timer(const Duration(milliseconds: 250), () => widget.onFind(q, 0));
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.found;
    final muted = Brand.muted(context);
    final step = n != null && n > 1;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 0, 0),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _q,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Найти в письме',
                border: InputBorder.none,
                filled: false,
                isDense: true,
              ),
              onChanged: _changed,
              onSubmitted: (q) => widget.onFind(q, widget.current + 1),
            ),
          ),
          if (n != null && _q.text.isNotEmpty)
            Text(n == 0 ? 'нет' : '${widget.current % n + 1} из $n',
                style: TextStyle(color: muted, fontSize: 13)),
          IconButton(
            tooltip: 'Предыдущее',
            icon: const Icon(Icons.keyboard_arrow_up),
            onPressed:
                step ? () => widget.onFind(_q.text, widget.current - 1) : null,
          ),
          IconButton(
            tooltip: 'Следующее',
            icon: const Icon(Icons.keyboard_arrow_down),
            onPressed:
                step ? () => widget.onFind(_q.text, widget.current + 1) : null,
          ),
          IconButton(
            tooltip: 'Закрыть поиск',
            icon: const Icon(Icons.close),
            onPressed: widget.onClose,
          ),
        ]),
      ),
    );
  }
}
