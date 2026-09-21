# Volgatech PRO — rebuild (Flutter)

A fast, native rebuild of the Volgatech / ПГТУ staff cabinet app, talking to the
existing backend at `https://api.volgatech.net`. **Client only — the backend is
untouched.** The API was reverse-engineered from the original Ionic app; see
[`../reverse_engineering/API_CONTRACT.md`](../reverse_engineering/API_CONTRACT.md).

Chosen for **speed + old-device support + Android *and* iOS from one codebase**:
Flutter compiles to native ARM (no WebView, no JS bridge) and runs on Android 5+
(API 21) and iOS 12+.

## Status

| Feature                                                         | State                                     |
|-----------------------------------------------------------------|-------------------------------------------|
| Login (`GetToken`) + token refresh                              | ✅ working                                 |
| Session persistence (secure)                                    | ✅                                         |
| Schedule (`GetPersonCalendar`), day navigation, pull-to-refresh | ✅                                         |
| Почта / Портал link-out                                         | ✅ (opens web logins; no password handled) |
| Exams, Requests/Обращения, Settings, Progress                   | ⏳ stubbed ("в разработке")                |

## Architecture

```
lib/
  main.dart              # DI wiring (Session, ApiClient, VolgatechApi, AuthController)
  app.dart               # MaterialApp, ru locale, AuthGate (login vs schedule)
  theme.dart             # brand palette (blue header, coral accents)
  core/
    session.dart         # secure token/personId storage (flutter_secure_storage)
    api_client.dart      # Dio + AuthInterceptor (Bearer + invalid_token→refresh→retry)
  data/
    volgatech_api.dart   # typed endpoints + error → RU message mapping
  models/                # auth, profile, schedule (fields verified vs live capture)
  state/
    auth_controller.dart      # login/logout/bootstrap
    schedule_controller.dart  # loads a week, pages day-by-day, caches
  ui/
    login_page.dart, schedule_page.dart, app_drawer.dart
```

Data flow: `UI → *Controller (ChangeNotifier) → VolgatechApi → ApiClient(Dio) → api.volgatech.net`.

## Bugs from the original, fixed here

1. **No plaintext credentials.** The original wrote `{login,password}` to `localStorage.logpassCache`. This app stores **only** the access/refresh tokens (in the OS keystore/keychain) and never persists the password.
2. **No pointless** `PageHelp` **400** on every screen — that call was dropped.
3. **Clean URLs** — no `//` double-slash quirk.
4. **Real error/empty/refresh states** instead of silent toasts.

## Run

```bash
cd app
flutter pub get
flutter run            # with an emulator/device attached
```

Backend base URL and endpoints live in `lib/core/api_client.dart` (`Api.prod` /
`Api.test`). Switch to the test server by passing `baseUrl: Api.test` to
`ApiClient(...)` in `main.dart`.