import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

void saveInBrowser(Uint8List bytes, String name, String mime) {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  final a = web.HTMLAnchorElement()
    ..href = url
    ..download = name;
  web.document.body?.append(a);
  a.click();
  a.remove();
  // Once the browser has taken it.
  Future<void>.delayed(
      const Duration(seconds: 30), () => web.URL.revokeObjectURL(url));
}

void openInBrowser(String url) => web.window.open(url, '_blank');
