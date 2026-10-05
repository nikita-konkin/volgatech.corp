{{flutter_js}}
{{flutter_build_config}}

// Without serviceWorkerSettings: Flutter's own worker is deprecated (all it
// does now is unregister itself) and would take over sw.js's registration.
// Each step moves the splash's bar (index.html).
_flutter.loader.load({
  onEntrypointLoaded: async function (engineInitializer) {
    try {
      window.splash.step(0.65, 0.85, 'Запуск…');
      const appRunner = await engineInitializer.initializeEngine();
      window.splash.step(0.85, 0.97);
      await appRunner.runApp();
    } catch (e) {
      window.splash.fail();
      throw e;
    }
  },
}).catch(function (e) {
  window.splash.fail();
  throw e;
});
