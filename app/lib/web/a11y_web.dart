import 'package:web/web.dart' as web;

bool prefersSolidSurfaces() =>
    web.window.matchMedia('(prefers-reduced-transparency: reduce)').matches ||
    web.window.matchMedia('(prefers-contrast: more)').matches;
