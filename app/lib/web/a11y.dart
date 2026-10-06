import 'a11y_stub.dart' if (dart.library.js_interop) 'a11y_web.dart' as impl;

/// The browser asks for solid surfaces: «Reduce transparency» or «Increase
/// contrast» in the system settings (Safari, Chrome and Firefox pass them
/// on as media queries).
bool prefersSolidSurfaces() => impl.prefersSolidSurfaces();
