import 'dart:convert';

import 'package:enough_mail/enough_mail.dart';

/// Content-Security-Policy for message bodies: no scripts, no remote loads
/// (tracking pixels, remote images), only inline styles and embedded images.
const _csp = "default-src 'none'; img-src data:; style-src 'unsafe-inline'; "
    'font-src data:';

final _cid = RegExp(r'''cid:([^"'\s>)]+)''', caseSensitive: false);

/// The page shown for [message]: its HTML part, or the plain text part
/// escaped, wrapped in a locked-down document. Inline images (`cid:`) are
/// embedded as data URIs.
String messageHtml(MimeMessage message) {
  final html = message.decodeTextHtmlPart();
  final body = html != null
      ? _inlineImages(message, html)
      : '<div class="plain">'
          '${const HtmlEscape().convert(message.decodeTextPlainPart() ?? '')}'
          '</div>';
  return '<!doctype html><html><head><meta charset="utf-8">'
      '<meta http-equiv="Content-Security-Policy" content="$_csp">'
      '<meta name="viewport" content="width=device-width, initial-scale=1">'
      '<style>'
      'body{margin:0;padding:12px 16px;font:15px/1.45 Roboto,sans-serif;'
      'color:#222;background:#fff;overflow-wrap:anywhere}'
      'img{max-width:100%;height:auto}table{max-width:100%}'
      '.plain{white-space:pre-wrap}'
      'blockquote{margin:8px 0;padding-left:10px;border-left:3px solid #ccc}'
      '</style></head><body>$body</body></html>';
}

String _inlineImages(MimeMessage message, String html) =>
    html.replaceAllMapped(_cid, (m) {
      // Bracketed and lowercased: enough_mail 2.1.7 compares the raw argument.
      final part = message.getPartWithContentId('<${m[1]}>'.toLowerCase());
      final bytes = part?.decodeContentBinary();
      if (part == null || bytes == null) return m[0]!;
      final type = part.mediaType.text;
      return 'data:$type;base64,${base64Encode(bytes)}';
    });
