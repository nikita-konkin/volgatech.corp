import 'dart:convert';

/// What a letter's text holds beyond words: links, addresses, phone numbers
/// and dates, found and made tappable; each tap opens a sheet of things to
/// do with it rather than leaving the app. Pure logic — no Flutter — so it
/// is unit-tested directly (test/mail_text_test.dart).

/// The scheme the prepared page links with: `volga-link:3` is [links][3].
const kLinkScheme = 'volga-link';

/// A picture tapped in the page: `volga-img:2` is `document.images[2]`.
const kImageScheme = 'volga-img';

enum LinkKind { web, meeting, mail, phone, date }

/// One tappable thing in a letter.
class MailLink {
  const MailLink({
    required this.kind,
    required this.target,
    required this.text,
    this.suspicious = false,
    this.when,
    this.hasTime = false,
  });

  final LinkKind kind;

  /// What it opens: the address for [LinkKind.web] and [LinkKind.meeting],
  /// `mailto:…` for [LinkKind.mail], `tel:+7…` for [LinkKind.phone].
  final String target;

  /// What the letter shows for it.
  final String text;

  /// Its text names another site than the one it leads to.
  final bool suspicious;

  /// For [LinkKind.date]: the day, and the time when [hasTime].
  final DateTime? when;
  final bool hasTime;

  /// The site a web link leads to, without «www.».
  String? get host => switch (Uri.tryParse(target)?.host) {
        final h? when h.isNotEmpty => h.replaceFirst(RegExp('^www\\.'), ''),
        _ => null,
      };

  /// For [LinkKind.meeting]: «Телемост», «Zoom», …
  String? get meeting => meetingService(target);

  /// The address of a mail link, the number of a phone link.
  String get value => switch (kind) {
        LinkKind.mail => uriDecode(target.substring(7).split('?').first),
        LinkKind.phone => target.substring(4),
        _ => target,
      };

  @override
  String toString() => '$kind $target «$text»${suspicious ? ' !' : ''}';
}

/// A letter's body ready for the reader, and what in it can be tapped.
class PreparedBody {
  const PreparedBody(this.html, this.links, {this.remoteImages = 0});

  /// The body's HTML, every link pointing at `volga-link:<index>`.
  final String html;
  final List<MailLink> links;

  /// How many pictures the letter takes from the internet.
  final int remoteImages;

  /// The web and meeting links, each address once, as the letter has them.
  List<MailLink> get webLinks {
    final seen = <String>{};
    return [
      for (final l in links)
        if ((l.kind == LinkKind.web || l.kind == LinkKind.meeting) &&
            seen.add(l.target))
          l,
    ];
  }

  /// The first link to an online meeting, if any.
  MailLink? get meeting =>
      links.where((l) => l.kind == LinkKind.meeting).firstOrNull;
}

/// The body of a letter, from its [html] part or, failing that, its plain
/// [text]: links rewritten to [kLinkScheme], and addresses, phone numbers,
/// dates and bare web addresses in the text made into links too. [sent]
/// gives the year of a date written without one.
PreparedBody prepareBody({String? html, String? text, DateTime? sent}) {
  final links = <MailLink>[];
  final out = StringBuffer();
  final at = sent ?? DateTime.now();
  if (html == null) {
    out
      ..write('<div class="plain">')
      ..write(_linkify(
          const HtmlEscape(HtmlEscapeMode.element).convert(text ?? ''),
          links,
          at))
      ..write('</div>');
    return PreparedBody(out.toString(), links);
  }

  var skip = 0; // inside <style>, <script>, <title>, <head>, …
  _Anchor? anchor;
  for (final m in _token.allMatches(html)) {
    final tag = m[1];
    if (tag == null) {
      final chunk = m[0]!;
      if (anchor != null) {
        anchor.text.write(chunk);
        out.write(chunk);
      } else {
        out.write(skip > 0 ? chunk : _linkify(chunk, links, at));
      }
      continue;
    }
    final name = _tagName.firstMatch(tag)?[1]?.toLowerCase() ?? '';
    final closing = tag.startsWith('</');
    if (_skipped.contains(name)) {
      if (closing) {
        if (skip > 0) skip--;
      } else if (!tag.endsWith('/>')) {
        skip++;
      }
      out.write(tag);
    } else if (name == 'a' && !closing) {
      anchor?.close(links);
      anchor = _Anchor.open(tag, links);
      out.write(anchor.tag);
    } else if (name == 'a' && closing) {
      anchor?.close(links);
      anchor = null;
      out.write(tag);
    } else {
      out.write(tag);
    }
  }
  anchor?.close(links);
  return PreparedBody(out.toString(), links);
}

final _token = RegExp(r'(<!--[\s\S]*?-->|<[^>]*>)|[^<]+|<');
final _tagName = RegExp(r'^</?\s*([a-zA-Z0-9]+)');
const _skipped = {
  'style',
  'script',
  'title',
  'head',
  'textarea',
  'select',
  'option',
  'noscript',
};

/// An `<a>` being read: its link, and the text it shows.
class _Anchor {
  _Anchor(this.tag, this.index, this.href);

  /// The tag as the page gets it.
  final String tag;
  final int? index;
  final String? href;
  final text = StringBuffer();

  factory _Anchor.open(String tag, List<MailLink> links) {
    final m = _href.firstMatch(tag);
    if (m == null) return _Anchor(tag, null, null); // a named anchor
    final href = htmlUnescape(m[2] ?? m[3] ?? m[4] ?? '').trim();
    final lower = href.toLowerCase();
    // In-page anchors work as they are; anything not to be followed loses
    // its link.
    if (href.startsWith('#')) return _Anchor(tag, null, null);
    final kept = lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('mailto:') ||
        lower.startsWith('tel:');
    final noTarget = tag.replaceAll(_target, '');
    if (!kept) {
      return _Anchor(noTarget.replaceRange(m.start, m.end, ''), null, null);
    }
    final index = links.length;
    links.add(MailLink(kind: LinkKind.web, target: href, text: ''));
    return _Anchor(noTarget.replaceFirst(_href, ' href="$kLinkScheme:$index"'),
        index, href);
  }

  void close(List<MailLink> links) {
    final i = index;
    if (i == null) return;
    final shown = htmlUnescape(text.toString().replaceAll(_tags, ''))
        .replaceAll(_spaces, ' ')
        .trim();
    links[i] = linkFor(href!, shown);
  }
}

final _href = RegExp(r'''\s+href\s*=\s*(?:(")([^"]*)"|'([^']*)'|([^\s>]+))''',
    caseSensitive: false);
final _target = RegExp(r'''\s+target\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>]+)''',
    caseSensitive: false);
final _tags = RegExp(r'<[^>]*>');
final _spaces = RegExp(r'\s+');

/// A link the letter itself made: to [href], showing [shown].
MailLink linkFor(String href, String shown) {
  final lower = href.toLowerCase();
  if (lower.startsWith('mailto:')) {
    return MailLink(kind: LinkKind.mail, target: href, text: shown);
  }
  if (lower.startsWith('tel:')) {
    var number =
        uriDecode(href.substring(4)).replaceAll(RegExp(r'[^\d+,;]'), '');
    if (number.length == 11 && number.startsWith('8')) {
      number = '+7${number.substring(1)}';
    }
    return MailLink(kind: LinkKind.phone, target: 'tel:$number', text: shown);
  }
  return MailLink(
    kind: meetingService(href) != null ? LinkKind.meeting : LinkKind.web,
    target: href,
    text: shown,
    suspicious: isSuspicious(href, shown),
  );
}

/// Whether link text [shown] names a site (or an address) other than the
/// one [href] leads to — «volgatech.net» on a link to somewhere else.
bool isSuspicious(String href, String shown) {
  final to = Uri.tryParse(href)?.host.toLowerCase() ?? '';
  if (to.isEmpty) return false;
  final text = shown.trim().toLowerCase();
  final named =
      _domainText.firstMatch(text)?[1] ?? _emailText.firstMatch(text)?[1];
  if (named == null) return false;
  String bare(String h) => h.replaceFirst(RegExp(r'^www\.'), '');
  final a = bare(named), b = bare(to);
  return !(a == b || a.endsWith('.$b') || b.endsWith('.$a'));
}

final _domainText =
    RegExp(r'^(?:https?://)?((?:[a-z0-9-]+\.)+[a-z]{2,})(?:[/:?#]\S*)?$');
final _emailText = RegExp(r'^[a-z0-9._%+-]+@((?:[a-z0-9-]+\.)+[a-z]{2,})$');

/// The online-meeting service [url] is a meeting of, or null.
String? meetingService(String url) {
  final u = Uri.tryParse(url);
  if (u == null || !(u.scheme == 'http' || u.scheme == 'https')) return null;
  final h = u.host.toLowerCase();
  final p = u.path.toLowerCase();
  bool at(String domain) => h == domain || h.endsWith('.$domain');
  if (at('telemost.yandex.ru') || at('telemost.360.yandex.ru')) {
    return 'Телемост';
  }
  if (at('ktalk.ru')) return 'Контур.Толк';
  if (at('vk.com') && p.startsWith('/call')) return 'VK Звонки';
  if (at('zoom.us') && (p.startsWith('/j/') || p.startsWith('/my/'))) {
    return 'Zoom';
  }
  if (at('teams.microsoft.com') || at('teams.live.com')) return 'Teams';
  if (at('meet.google.com')) return 'Google Meet';
  if (at('jazz.sber.ru') || at('salutejazz.ru')) return 'SaluteJazz';
  if (at('mts-link.ru') || at('webinar.ru')) return 'МТС Линк';
  return null;
}

/// [chunk] (HTML text, entities and all) with web addresses, e-mail
/// addresses, phone numbers and dates wrapped in links added to [links].
String _linkify(String chunk, List<MailLink> links, DateTime sent) {
  final text =
      chunk.replaceAll('&nbsp;', '\u00a0').replaceAll('&#160;', '\u00a0');
  final found = <_Found>[
    for (final m in _url.allMatches(text))
      if (_urlAt(m) case final f?) f,
    for (final m in _email.allMatches(text))
      _Found(m.start, m.end, LinkKind.mail, 'mailto:${htmlUnescape(m[0]!)}'),
    for (final m in _phone.allMatches(text))
      if (_phoneAt(m) case final f?) f,
    for (final m in _localPhone.allMatches(text))
      if (_localPhoneAt(m) case final f?) f,
    for (final m in _wordDate.allMatches(text))
      if (_wordDateAt(m, sent) case final f?) f,
    for (final m in _numDate.allMatches(text))
      if (_numDateAt(m, sent) case final f?) f,
  ]..sort((a, b) => a.start != b.start ? a.start - b.start : b.end - a.end);
  if (found.isEmpty) return text;
  final out = StringBuffer();
  var pos = 0;
  for (final f in found) {
    if (f.start < pos) continue; // inside one already taken
    final shown = text.substring(f.start, f.end);
    out.write(text.substring(pos, f.start));
    final index = links.length;
    links.add(MailLink(
      kind: f.kind == LinkKind.web && meetingService(f.target) != null
          ? LinkKind.meeting
          : f.kind,
      target: f.target,
      text: htmlUnescape(shown),
      when: f.when,
      hasTime: f.hasTime,
    ));
    final cls = f.kind == LinkKind.web ? 'vt-link' : 'vt-auto';
    out.write('<a class="$cls" href="$kLinkScheme:$index">$shown</a>');
    pos = f.end;
  }
  out.write(text.substring(pos));
  return out.toString();
}

class _Found {
  _Found(this.start, this.end, this.kind, this.target,
      {this.when, this.hasTime = false});
  final int start, end;
  final LinkKind kind;
  final String target;
  final DateTime? when;
  final bool hasTime;
}

final _url =
    RegExp(r'''(?:https?://|www\.)[^\s<>"'«»\u00a0]+''', caseSensitive: false);
final _quoteEntity =
    RegExp(r'&(?:quot|apos|lt|gt|laquo|raquo|#34|#39|#171|#187);');
final _email = RegExp(r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}');

_Found? _urlAt(RegExpMatch m) {
  var s = m[0]!;
  // Quotes and brackets written as entities end it too.
  final quote = _quoteEntity.firstMatch(s);
  if (quote != null) s = s.substring(0, quote.start);
  // Punctuation after an address belongs to the sentence; a closing
  // bracket only when it has no opening one in the address.
  while (s.isNotEmpty) {
    final last = s[s.length - 1];
    if ('.,;:!?»\'"'.contains(last) ||
        (last == ')' && '('.allMatches(s).length < ')'.allMatches(s).length)) {
      s = s.substring(0, s.length - 1);
    } else {
      break;
    }
  }
  if (s.length < 5) return null;
  var target = htmlUnescape(s);
  if (!target.toLowerCase().startsWith('http')) target = 'https://$target';
  return _Found(m.start, m.start + s.length, LinkKind.web, target);
}

const _sep = r'[\s\u00a0\-‐–]*';
final _phone =
    RegExp('(?<![\\d+])(?:\\+7|8)$_sep\\(?$_sep(\\d{3,5})$_sep\\)?$_sep'
        '(\\d{1,3})$_sep(\\d{2})$_sep(\\d{2})(?!\\d)$_ext');
final _localPhone = RegExp(
    r'(?:тел(?:ефон)?\.?|т\.|tel\.?|phone|моб\.?|факс)\s*:?\s*'
    '(?<![\\d+])(\\d{2,3})[\\-‐–](\\d{2})[\\-‐–](\\d{2})(?!\\d)$_ext',
    caseSensitive: false);
const _ext =
    r'(?:[\s\u00a0]*,?[\s\u00a0]*(?:доб\.?|вн\.?|ext\.?)[\s\u00a0]*(\d{1,5}))?';

_Found? _phoneAt(RegExpMatch m) {
  final digits = m[0]!
      .split(RegExp(r'(?:доб|вн|ext)', caseSensitive: false))
      .first
      .replaceAll(RegExp(r'\D'), '');
  if (digits.length != 11) return null;
  final ext = m[5];
  return _Found(m.start, m.end, LinkKind.phone,
      'tel:+7${digits.substring(1)}${ext == null ? '' : ',$ext'}');
}

/// «тел. 68-60-00»: a Yoshkar-Ola number, without the city's code.
_Found? _localPhoneAt(RegExpMatch m) {
  final number = '${m[1]}${m[2]}${m[3]}';
  if (number.length != 6) return null;
  final ext = m[4];
  final start = m.start + m[0]!.indexOf(m[1]!);
  return _Found(start, m.end, LinkKind.phone,
      'tel:+78362$number${ext == null ? '' : ',$ext'}');
}

const _months = [
  'января',
  'февраля',
  'марта',
  'апреля',
  'мая',
  'июня',
  'июля',
  'августа',
  'сентября',
  'октября',
  'ноября',
  'декабря',
];
const _time = r'(?:[\s ]*(?:,|в|с)?[\s ]*(\d{1,2})[:.](\d{2})(?!\d|\.\d))?';
final _wordDate = RegExp(
    '(?<date>(?<!\\d)(\\d{1,2})[\\s\\u00a0]+(${_months.join('|')})'
    '(?:[\\s\\u00a0]+(\\d{4})(?:[\\s\\u00a0]*(?:года|г\\.?)(?![а-яё]))?)?)'
    '$_time',
    caseSensitive: false);
final _numDate = RegExp(
    r'(?<date>(?<!\d|\d\.)(\d{1,2})\.(\d{1,2})\.(\d{4}|\d{2})(?!\d|\.\d))'
    '$_time');

_Found? _wordDateAt(RegExpMatch m, DateTime sent) => _dateFound(
    m,
    int.parse(m[2]!),
    _months.indexOf(m[3]!.toLowerCase()) + 1,
    m[4] == null ? null : int.parse(m[4]!),
    m[5],
    m[6],
    sent);

_Found? _numDateAt(RegExpMatch m, DateTime sent) {
  final y = int.parse(m[4]!);
  return _dateFound(m, int.parse(m[2]!), int.parse(m[3]!),
      y < 100 ? 2000 + y : y, m[5], m[6], sent);
}

_Found? _dateFound(RegExpMatch m, int day, int month, int? year, String? hh,
    String? mm, DateTime sent) {
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  var y = year ?? sent.year;
  // «15 января» in a December letter is next year's.
  if (year == null &&
      DateTime(y, month, day)
          .isBefore(sent.subtract(const Duration(days: 60)))) {
    y++;
  }
  final h = hh == null ? null : int.parse(hh);
  final mi = mm == null ? null : int.parse(mm);
  final timed = h != null && mi != null && h < 24 && mi < 60;
  final when = DateTime(y, month, day, timed ? h : 0, timed ? mi : 0);
  if (when.day != day) return null; // 31 февраля
  // A time that isn't one stays out of the link.
  final end = timed ? m.end : m.start + m.namedGroup('date')!.length;
  return _Found(m.start, end, LinkKind.date, '', when: when, hasTime: timed);
}

/// [s] with its %-escapes decoded, as letters write them: Cyrillic left
/// unescaped, a stray «%», «+» meaning a plus (RFC 6068).
String uriDecode(String s) {
  final ascii = s.replaceAllMapped(
      RegExp(r'[^\x00-\x7F]+'), (m) => Uri.encodeComponent(m[0]!));
  try {
    return Uri.decodeComponent(ascii);
  } on ArgumentError {
    return s;
  }
}

/// `mailto:a@b?subject=…&body=…&cc=…` taken apart.
({String to, String cc, String subject, String body}) parseMailto(
    String mailto) {
  final rest = mailto.substring(mailto.indexOf(':') + 1);
  final q = rest.indexOf('?');
  final to = uriDecode(q < 0 ? rest : rest.substring(0, q));
  final params = q < 0
      ? const <String, String>{}
      : {
          for (final pair in rest.substring(q + 1).split('&'))
            if (pair.isNotEmpty)
              uriDecode(pair.split('=').first): uriDecode(pair.contains('=')
                  ? pair.substring(pair.indexOf('=') + 1)
                  : ''),
        };
  String p(String k) =>
      params.entries
          .where((e) => e.key.toLowerCase() == k)
          .map((e) => e.value)
          .firstOrNull ??
      '';
  return (to: to, cc: p('cc'), subject: p('subject'), body: p('body'));
}

/// Where a mailing list's `List-Unsubscribe` header says to go: its web
/// address if it gives one, else its `mailto:`.
String? unsubscribeTarget(String? header) {
  if (header == null) return null;
  final all = [
    for (final m in RegExp(r'<([^>]+)>').allMatches(header)) m[1]!.trim(),
  ];
  return all.where((u) => u.startsWith('https://')).firstOrNull ??
      all.where((u) => u.startsWith('http://')).firstOrNull ??
      all.where((u) => u.toLowerCase().startsWith('mailto:')).firstOrNull;
}

/// The letter's own text, before any quoted earlier message.
String ownText(String text) {
  final cut = _quoteStart.firstMatch(text);
  return cut == null ? text : text.substring(0, cut.start);
}

final _quoteStart = RegExp(
    r'^(?:-{2,}\s*(?:Original Message|Исходное сообщение|Пересылаемое сообщение)'
    r'|(?:От|From|Отправлено|Sent):\s.*|>.*|.*(?:написал|wrote)\s*:\s*)$',
    multiLine: true,
    caseSensitive: false);

/// The phone number in the sender's signature: the last one in the letter's
/// own text (above any quoted earlier message), as dialled.
String? signaturePhone(String text) {
  final links = <MailLink>[];
  _linkify(const HtmlEscape(HtmlEscapeMode.element).convert(ownText(text)),
      links, DateTime.now());
  return links
      .where((l) => l.kind == LinkKind.phone)
      .map((l) => l.value)
      .lastOrNull;
}

/// A dialled number as people write it: «+7 8362 68-60-00 доб. 12»,
/// «+7 900 123-45-67».
String formatPhone(String number) {
  final parts = number.split(',');
  final n = parts.first;
  final ext =
      parts.length > 1 && parts[1].isNotEmpty ? ' доб. ${parts[1]}' : '';
  final d = n.replaceAll(RegExp(r'\D'), '');
  if (!n.startsWith('+7') || d.length != 11) return '$n$ext';
  final city = d.startsWith('78362') ? 4 : 3;
  final code = d.substring(1, 1 + city);
  final rest = d.substring(1 + city);
  final local = rest.length == 7
      ? '${rest.substring(0, 3)}-${rest.substring(3, 5)}-${rest.substring(5)}'
      : '${rest.substring(0, 2)}-${rest.substring(2, 4)}-${rest.substring(4)}';
  return '+7 $code $local$ext';
}

/// A letter's text for copying, sharing or translating: blank runs folded.
String tidyText(String text) => text
    .replaceAll('\r\n', '\n')
    .replaceAll(RegExp(r'[ \t\u00a0]+\n'), '\n')
    .replaceAll(RegExp(r'\n{3,}'), '\n\n')
    .trim();

/// HTML entities decoded: numeric ones and those letters use.
String htmlUnescape(String s) => s.contains('&')
    ? s.replaceAllMapped(_entity, (m) {
        final n = m[1]!;
        if (n.startsWith('#x') || n.startsWith('#X')) {
          return String.fromCharCode(
              int.tryParse(n.substring(2), radix: 16) ?? 63);
        }
        if (n.startsWith('#')) {
          return String.fromCharCode(int.tryParse(n.substring(1)) ?? 63);
        }
        return _named[n] ?? m[0]!;
      })
    : s;

final _entity = RegExp(r'&(#[xX]?[0-9a-fA-F]+|[a-zA-Z]+);');
const _named = {
  'amp': '&',
  'lt': '<',
  'gt': '>',
  'quot': '"',
  'apos': "'",
  'nbsp': '\u00a0',
  'laquo': '«',
  'raquo': '»',
  'mdash': '—',
  'ndash': '–',
  'hellip': '…',
  'bull': '•',
  'middot': '·',
  'copy': '©',
  'reg': '®',
  'trade': '™',
  'shy': '',
};
