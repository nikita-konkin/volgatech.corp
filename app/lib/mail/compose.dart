import 'dart:convert';
import 'dart:typed_data';

import 'package:enough_mail/enough_mail.dart';
import 'package:intl/intl.dart';

import 'mail_config.dart';

class DraftAttachment {
  const DraftAttachment(this.name, this.mediaType, this.bytes);
  final String name;
  final String mediaType;
  final Uint8List bytes;
}

/// What the compose screen edits and [buildMime] turns into a message.
class ComposeDraft {
  ComposeDraft({
    this.to = '',
    this.cc = '',
    this.subject = '',
    this.text = '',
    List<DraftAttachment>? attachments,
    this.inReplyTo,
    this.references,
    this.quotes = false,
  }) : attachments = attachments ?? [];

  /// Reply to the sender (and, with [all], everyone else but me).
  factory ComposeDraft.reply(MimeMessage original,
      {required bool all, required String myLogin}) {
    final sender = original.replyTo?.isNotEmpty ?? false
        ? original.replyTo!
        : original.from ?? const <MailAddress>[];
    final seen = <String>{for (final a in sender) a.email.toLowerCase()};
    final others = <MailAddress>[
      if (all)
        for (final a in [...?original.to, ...?original.cc])
          if (!isMine(a.email, myLogin) && seen.add(a.email.toLowerCase())) a,
    ];
    final messageId = original.getHeaderValue('message-id');
    final refs = original.getHeaderValue('references');
    return ComposeDraft(
      to: formatAddresses(sender),
      cc: formatAddresses(others),
      subject: _prefixed('RE: ', original.decodeSubject()),
      text: '\n\n${_quoteHeader(original)}\n${_quote(_plainText(original))}',
      inReplyTo: messageId,
      references:
          [if (refs != null) refs, if (messageId != null) messageId].join(' '),
      quotes: true,
    );
  }

  /// Forward with the original's attachments.
  factory ComposeDraft.forward(MimeMessage original) {
    final from = formatAddresses(original.from ?? const []);
    final to = formatAddresses(original.to ?? const []);
    final date = original.decodeDate();
    final files = <DraftAttachment>[
      for (final info in original.findContentInfo())
        if (original.getPart(info.fetchId)?.decodeContentBinary()
            case final bytes?)
          DraftAttachment(info.fileName ?? 'вложение',
              info.mediaType?.text ?? 'application/octet-stream', bytes),
    ];
    return ComposeDraft(
      subject: _prefixed('FW: ', original.decodeSubject()),
      text: '\n\n-------- Пересылаемое сообщение --------\n'
          'От: $from\n'
          '${date == null ? '' : 'Дата: ${_date(date)}\n'}'
          'Тема: ${original.decodeSubject() ?? ''}\n'
          '${to.isEmpty ? '' : 'Кому: $to\n'}'
          '\n${_plainText(original)}',
      attachments: files,
      quotes: true,
    );
  }

  String to;
  String cc;
  String subject;
  String text;
  final List<DraftAttachment> attachments;
  final String? inReplyTo;
  final String? references;

  /// A reply or forward: the text ends with the original.
  final bool quotes;

  /// The text is as the user left it, signature included (a message taken
  /// back from sending, or [fromPhone]).
  bool signedAlready = false;

  /// Kept on the phone after the compose screen was left unsent
  /// ([ComposeDraft.fromJson]); its [lostAttachments] weren't kept.
  bool fromPhone = false;
  int lostAttachments = 0;

  /// What is kept on the phone of a message left unsent — not the
  /// attachments, which may be megabytes.
  Map<String, Object?> toJson() => {
        'to': to,
        'cc': cc,
        'subject': subject,
        'text': text,
        'inReplyTo': inReplyTo,
        'references': references,
        'quotes': quotes,
        'attachments': attachments.length,
      };

  factory ComposeDraft.fromJson(Map<String, dynamic> j) => ComposeDraft(
        to: j['to'] as String? ?? '',
        cc: j['cc'] as String? ?? '',
        subject: j['subject'] as String? ?? '',
        text: j['text'] as String? ?? '',
        inReplyTo: j['inReplyTo'] as String?,
        references: j['references'] as String?,
        quotes: j['quotes'] as bool? ?? false,
      )
        ..signedAlready = true
        ..fromPhone = true
        ..lostAttachments = j['attachments'] as int? ?? 0;
}

/// [text] with [signature] below where the writing starts: at the end of a
/// new message, above the quoted original of a reply or forward.
String signed(String text, String signature) {
  final sig = signature.trim();
  return sig.isEmpty ? text : '\n\n$sig$text';
}

/// Whether [email] is the signed-in user's (the login without its domain).
bool isMine(String email, String myLogin) {
  final me = myLogin.split(r'\').last.split('@').first.toLowerCase();
  final local = email.split('@').first.toLowerCase();
  return me.isNotEmpty &&
      local == me &&
      email.toLowerCase().endsWith('@$kMailDomain');
}

String formatAddresses(List<MailAddress> list) => [
      for (final a in list)
        (a.personalName?.trim().isNotEmpty ?? false)
            ? '${a.personalName!.trim()} <${a.email}>'
            : a.email,
    ].join(', ');

final _separator = RegExp(r'[,;]');

/// The recipient being typed: whatever follows the last comma.
String lastRecipient(String text) =>
    text.substring(text.lastIndexOf(_separator) + 1).trim();

/// [text] with the recipient being typed replaced by [a], ready for the
/// next one.
String withRecipient(String text, MailAddress a) {
  final cut = text.lastIndexOf(_separator);
  final head = cut < 0 ? '' : '${text.substring(0, cut + 1)} ';
  final name =
      (a.personalName ?? '').replaceAll(RegExp(r'[,;<>"\s]+'), ' ').trim();
  return '$head${name.isEmpty ? a.email : '$name <${a.email}>'}, ';
}

final _addr = RegExp(r'^[^@\s<>,;]+@[^@\s<>,;]+\.[^@\s<>,;]+$');

/// Parses `Имя <a@b.ru>, c@d.ru; …`. Returns null when something isn't an
/// address, so the form can point at it.
List<MailAddress>? parseRecipients(String text) {
  final result = <MailAddress>[];
  for (final raw in text.split(RegExp(r'[,;\n]'))) {
    final s = raw.trim();
    if (s.isEmpty) continue;
    final m = RegExp(r'^(.*)<([^>]+)>$').firstMatch(s);
    final email = (m?[2] ?? s).trim();
    if (!_addr.hasMatch(email)) return null;
    final name = m?[1]?.trim().replaceAll('"', '');
    result.add(MailAddress(name == null || name.isEmpty ? null : name, email));
  }
  return result;
}

/// The message to send, as RFC 822 bytes. No From: Exchange puts the
/// signed-in mailbox there.
Uint8List buildMime(ComposeDraft d) {
  final b = MessageBuilder()
    ..to = parseRecipients(d.to)
    ..cc = parseRecipients(d.cc)
    ..subject = d.subject.trim()
    ..messageId = MessageBuilder.createMessageId(kMailDomain);
  if (d.inReplyTo != null) b.setHeader('In-Reply-To', d.inReplyTo);
  if (d.references?.isNotEmpty ?? false) {
    b.setHeader('References', d.references);
  }
  b.addTextPlain(d.text);
  for (final a in d.attachments) {
    b.addBinary(a.bytes, MediaType.fromText(a.mediaType),
        filename: encodedFileName(a.name));
  }
  return utf8.encode(b.buildMimeMessage().renderMessage());
}

/// enough_mail writes file names raw; non-ASCII ones go out as an RFC 2047
/// word, as Outlook does, which Exchange and mail clients decode.
String encodedFileName(String name) => name.codeUnits.every((c) => c < 128)
    ? name
    : '=?utf-8?B?${base64Encode(utf8.encode(name))}?=';

String _prefixed(String prefix, String? subject) {
  final s = (subject ?? '').trim();
  return s.toUpperCase().startsWith(prefix.trim()) ? s : '$prefix$s';
}

String _plainText(MimeMessage m) {
  final plain = m.decodeTextPlainPart();
  if (plain != null) return plain.trimRight();
  return htmlToText(m.decodeTextHtmlPart() ?? '');
}

/// Readable text of an HTML fragment: line breaks kept, tags dropped.
String htmlToText(String html) => html
    .replaceAll(RegExp(r'<(br|/p|/div|/tr)[^>]*>', caseSensitive: false), '\n')
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .replaceAll('&nbsp;', ' ')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&amp;', '&')
    .replaceAll(RegExp(r'\n{3,}'), '\n\n')
    .trim();

String _quote(String text) =>
    text.split('\n').map((l) => l.isEmpty ? '>' : '> $l').join('\n');

String _quoteHeader(MimeMessage m) {
  final from = formatAddresses(m.from ?? const []);
  final date = m.decodeDate();
  return '${date == null ? '' : '${_date(date)}, '}$from:';
}

String _date(DateTime d) =>
    DateFormat("d MMMM y 'г.', HH:mm", 'ru_RU').format(d.toLocal());
