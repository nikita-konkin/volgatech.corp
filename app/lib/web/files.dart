import 'dart:typed_data';

import 'files_stub.dart' if (dart.library.js_interop) 'files_web.dart' as impl;

/// In a browser: [bytes] saved as a download named [name].
void saveInBrowser(Uint8List bytes, String name, String mime) =>
    impl.saveInBrowser(bytes, name, mime);

/// In a browser: [url] in a new tab (a home-screen app on an iPhone opens
/// Safari over itself, and stays as it was underneath).
void openInBrowser(String url) => impl.openInBrowser(url);
