# Волгатех.Коллектив

A fast, native rewrite of the ПГТУ / VolgaTech staff cabinet app («Личный кабинет
работника»), built with **Flutter** for Android and iOS. Client-only — it talks to
the existing `api.volgatech.net` backend and does not change it.

The Flutter app lives in [`app/`](app/).

## Features

- **Login** with JWT + auto-refresh; tokens in the OS keystore, the password is
  never stored.
- **Расписание занятий** — day view, swipe between days, offline cache, and a
  week-type accent colour (red for week 1, blue for week 2).
- **Расписание экзаменов** — study-year picker, grouped by date, offline cache.
- **Профиль** — photo, position/department, experience.
- **Настройки** — theme (system / light / dark) and an optional
  fingerprint / PIN **app-lock**.
- **Почта** and **Портал** — the OWA mail and the corporate portal open **in-app**
  (WebView), keeping only the site session cookie, never the password.
- Friendly Russian error/empty/retry states; honours OS font scaling.

## Build

```bash
cd app
flutter pub get
flutter analyze
flutter test
flutter build apk --release --split-per-abi   # per-ABI APKs (arm64 ≈ 20 MB)
```

Requirements: Flutter **3.47.5** (stable), JDK 17, Android SDK (compileSdk 36).
minSdk is 24 (Android 7.0).

App icons are generated from `app/assets/icon/` with:

```bash
cd app && dart run flutter_launcher_icons
```

## CI/CD

GitHub Actions:

- [`ci.yml`](.github/workflows/ci.yml) — on every push/PR to `main`: `flutter
  analyze`, `flutter test`, and a release APK build, uploaded as a workflow
  artifact.
- [`release.yml`](.github/workflows/release.yml) — on a `v*` tag: builds the
  per-ABI release APKs and attaches them to a GitHub Release.

Tag a release:

```bash
git tag v0.1.0 && git push origin v0.1.0
```

## Roadmap

See [IMPROVEMENTS.md](IMPROVEMENTS.md).
