{{flutter_js}}
{{flutter_build_config}}

// Without serviceWorkerSettings: Flutter's own worker is deprecated (all it
// does now is unregister itself) and would take over sw.js's registration.
_flutter.loader.load();
