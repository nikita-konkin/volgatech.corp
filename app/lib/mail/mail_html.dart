import 'dart:convert';

import 'package:enough_mail/enough_mail.dart';

import 'mail_text.dart';

/// Content-Security-Policy for message bodies: no scripts, no remote loads
/// (tracking pixels, remote images), only inline styles and embedded images.
/// The reader's own scripts (find, the selection) are run by the app and
/// aren't the page's, so the policy doesn't stop them.
const _csp = "default-src 'none'; img-src data:; style-src 'unsafe-inline'; "
    'font-src data:';

final _cid = RegExp(r'''cid:([^"'\s>)]+)''', caseSensitive: false);

/// The page shown for [message] and what in it can be tapped: its HTML
/// part, or the plain text part escaped, wrapped in a locked-down document,
/// every link pointing at [kLinkScheme]. Inline images (`cid:`) are
/// embedded as data URIs. [dark] turns the page dark, pictures as they are.
PreparedBody messageBody(MimeMessage message, {bool dark = false}) {
  final html = message.decodeTextHtmlPart();
  final body = prepareBody(
    html: html == null ? null : _inlineImages(message, html),
    text: message.decodeTextPlainPart(),
    sent: message.decodeDate(),
  );
  return PreparedBody(_page(body.html, dark: dark), body.links);
}

/// [messageBody]'s page alone.
String messageHtml(MimeMessage message, {bool dark = false}) =>
    messageBody(message, dark: dark).html;

String _page(String body, {required bool dark}) =>
    '<!doctype html><html><head><meta charset="utf-8">'
    '<meta http-equiv="Content-Security-Policy" content="$_csp">'
    '<meta name="viewport" content="width=device-width, initial-scale=1">'
    '<style>'
    'body{margin:0;padding:12px 16px;font:15px/1.45 Roboto,sans-serif;'
    'color:#222;background:#fff;overflow-wrap:anywhere}'
    'img{max-width:100%;height:auto}table{max-width:100%}'
    '.plain{white-space:pre-wrap}'
    'blockquote{margin:8px 0;padding-left:10px;border-left:3px solid #ccc}'
    'a.vt-link{color:#1a5fb4}'
    'a.vt-auto{color:inherit;text-decoration:underline dotted #1a5fb4;'
    'text-underline-offset:2px}'
    'mark.vt-find{background:#ffe066;color:inherit}'
    'mark.vt-find.vt-on{background:#ff9f1c}'
    // Dark: the whole page inverted, and pictures inverted back.
    '${dark ? 'html{filter:invert(1) hue-rotate(180deg);background:#fff}'
        'img,video,picture,svg,[style*="background-image"]'
        '{filter:invert(1) hue-rotate(180deg)}' : ''}'
    '</style></head><body>$body</body></html>';

String _inlineImages(MimeMessage message, String html) =>
    html.replaceAllMapped(_cid, (m) {
      // Bracketed and lowercased: enough_mail 2.1.7 compares the raw argument.
      final part = message.getPartWithContentId('<${m[1]}>'.toLowerCase());
      final bytes = part?.decodeContentBinary();
      if (part == null || bytes == null) return m[0]!;
      final type = part.mediaType.text;
      return 'data:$type;base64,${base64Encode(bytes)}';
    });

/// The reader's find: marks every [query] in the page's text, the [index]th
/// (counted from 0, wrapping) as the current one, and scrolls to it. Its
/// result is the number found. An empty [query] clears the marks.
String findScript(String query, int index) => '''
(function(q, i) {
  document.querySelectorAll('mark.vt-find').forEach(function(m) {
    m.replaceWith(document.createTextNode(m.textContent));
  });
  document.body.normalize();
  if (!q) return 0;
  var lq = q.toLocaleLowerCase(), marks = [];
  var walk = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, {
    acceptNode: function(n) {
      var p = n.parentNode && n.parentNode.nodeName;
      return p === 'STYLE' || p === 'SCRIPT' || p === 'TITLE'
          ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT;
    }
  });
  var nodes = [];
  while (walk.nextNode()) nodes.push(walk.currentNode);
  nodes.forEach(function(n) {
    var text = n.nodeValue, low = text.toLocaleLowerCase(), at = 0, k;
    if (low.indexOf(lq) < 0) return;
    var frag = document.createDocumentFragment();
    while ((k = low.indexOf(lq, at)) >= 0) {
      frag.appendChild(document.createTextNode(text.slice(at, k)));
      var m = document.createElement('mark');
      m.className = 'vt-find';
      m.textContent = text.slice(k, k + q.length);
      frag.appendChild(m);
      marks.push(m);
      at = k + q.length;
    }
    frag.appendChild(document.createTextNode(text.slice(at)));
    n.replaceWith(frag);
  });
  if (marks.length) {
    var on = marks[((i % marks.length) + marks.length) % marks.length];
    on.classList.add('vt-on');
    on.scrollIntoView({block: 'center'});
  }
  return marks.length;
})(${jsonEncode(query)}, $index)''';

/// Run once the page is shown: keeps the last text selected, which tapping
/// outside the page may clear before [selectionScript] asks for it.
const readerScript = "document.addEventListener('selectionchange',"
    'function(){var s=String(window.getSelection());'
    'if(s.trim())window.vtSelected=s;})';

/// The text the reader has selected in the page, or selected last.
const selectionScript =
    "String(window.getSelection()).trim()||window.vtSelected||''";
