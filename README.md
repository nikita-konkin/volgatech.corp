# Волгатех.Коллектив

[![CI](https://github.com/nikita-konkin/volgatech.corp/actions/workflows/ci.yml/badge.svg)](https://github.com/nikita-konkin/volgatech.corp/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/nikita-konkin/volgatech.corp?label=release)](https://github.com/nikita-konkin/volgatech.corp/releases/latest)

A fast, native rewrite of the ПГТУ / VolgaTech staff cabinet app («Личный кабинет
работника»), built with **Flutter** for Android, iOS and the browser (on an iPhone or a
computer). Client-only — it talks to the existing `api.volgatech.net` backend and
does not change it.

The Flutter app lives in [`app/`](app/). По-русски: [README.ru.md](README.ru.md).

<p align="center">
  <img src="docs/screenshots/schedule.webp" width="18%" alt="Расписание">
  <img src="docs/screenshots/week.webp" width="18%" alt="Обзор недели">
  <img src="docs/screenshots/memo.webp" width="18%" alt="Иностранные группы">
  <img src="docs/screenshots/profile.webp" width="18%" alt="Профиль">
  <img src="docs/screenshots/menu.webp" width="18%" alt="Меню">
  <br><sub>Расписание · Обзор недели · Иностранные группы · Профиль · Меню</sub>
</p>

<p align="center">
  <img src="docs/screenshots/mail-list.webp" width="18%" alt="Почта: Входящие">
  <img src="docs/screenshots/mail-swipe.webp" width="18%" alt="Почта: удаление свайпом">
  <img src="docs/screenshots/mail-compose.webp" width="18%" alt="Почта: новое письмо">
  <img src="docs/screenshots/mail-size.webp" width="18%" alt="Почта: размер ящика">
  <img src="docs/screenshots/mail-menu.webp" width="18%" alt="Почта: меню">
  <br><sub>Почта: Входящие · Удаление свайпом · Новое письмо · Размер ящика · Меню
  (example data)</sub>
</p>

## 📥 Download

Grab the latest APK from the
**[Releases page](https://github.com/nikita-konkin/volgatech.corp/releases/latest)**
(or its copy on [GitVerse](https://gitverse.ru/nikita-konkin/volgatech.corp/releases)).
Each release has two sets of the same app; for a 64-bit phone (most modern
devices) pick the `arm64-v8a` one:

| APK | «Почта» in the app |
|---|---|
| `app-mail-arm64-v8a-release.apk` | the **built-in mail client** (new in v0.5.0) |
| `app-arm64-v8a-release.apk` | the web mail (OWA) in a WebView, as before |

Both carry the same signature, so either installs over the other. From
v0.5.1 on, the app finds new releases itself and installs them (see below);
from v0.5.0 or older, install v0.5.1 by hand once.

> **Coming from v0.4.1 or older?** Uninstall the old app once before installing
> v0.4.2 — earlier builds were signed with a different key each time. From v0.4.2
> on, new versions install over the old one.

## 🌐 In the browser: iPhone and computer

The same app runs in a browser — on an iPhone, which has no App Store build
(that takes a paid Apple Developer account), and on any computer:

**https://nikita-konkin.gitverse.site/volgatech-corp/**
(or the copy at https://konkin-nikita.ru/volgatech.corp/)

### On an iPhone

1. Open the link in Safari.
2. Tap **Поделиться** → **На экран «Домой»** → **Добавить**.
3. Start «Волгатех» from the home screen and sign in there: the home-screen app
   keeps its own data, apart from Safari's.

Every screen is laid out for every iPhone from the first SE to the 17 Pro Max,
upright or turned sideways.

### On a computer

<img src="docs/screenshots/desktop.webp" width="100%" alt="Обзор недели в браузере на компьютере">

Open the link in Chrome, Edge, Firefox, Safari or Yandex Browser and sign in.
Chrome and Edge can also install it as an app of its own (the install icon at
the right of the address bar). In a window 1000 px wide or more:

- the menu stays open on the left, and each screen stays as you left it — the
  day, the month, an open week overview;
- lessons, exams and the memo keep to a readable width, and the week overview
  shows the days side by side;
- **←** and **→** change the day, the week or the month; the week overview has
  ‹ › for the week, and the schedule, exams and memo have a ⟳ button, since
  pulling a list down to refresh takes a finger.

A narrower window gets the phone layout, with the menu behind ☰.

### Unlike on Android

Schedule, week overview, exams, profile and the foreign-groups memo all work,
but:

- «Почта» opens the web mail in a new tab: the mail server doesn't let a web page
  talk to it, so there is no built-in mail client;
- there is no lock with Face ID, a fingerprint or a PIN;
- updates need nothing: the site is rebuilt whenever the app changes, and the
  app loads the new version the next time it starts.

## Features

- **Login** with JWT + auto-refresh; tokens in the OS keystore, the password is
  never stored.
- **Расписание занятий** — day view, swipe between days, offline cache, a
  week-type accent colour (red for week 1, blue for week 2), and an **«Обзор
  недели»** overview (Пн–Вс, lessons per day, gaps «окна», total pairs, tap a
  day to jump).
- **Расписание экзаменов** — study-year picker, grouped by date, offline cache.
- **Профиль** — photo, birthday, and every appointment (main department first)
  with its **ставка / почасовая** load, department and start date, plus a
  combined-load line and work experience.
- **Иностранные группы** — the monthly «служебная записка» about classes taught
  to foreign students (groups with a 3-digit number, e.g. ИСТ-110), built from
  your schedule and shared as a .docx in the portal's own template.
- **Настройки** — theme (system / light / dark) and an optional
  fingerprint / PIN **app-lock**.
- **Обновления** — a new release on GitHub shows up as a banner in the app;
  «Обновить» downloads the right APK for the phone, checks it and opens the
  Android installer.
- **Почта** — in the `app-mail-*` APKs, a **built-in client** for the
  university's Exchange mailbox (EWS): folders, search, pinned messages,
  attachments, replies with a signature, address-book suggestions,
  «Автоответ», mailbox size and an unread badge. The mail password is kept
  in the OS keystore and deleted on «Выйти из почты». In the plain APKs,
  OWA opens in-app (WebView) as before.
- **Портал** — the corporate portal opens **in-app** (WebView), keeping only
  the site session cookie, never the password.
- Friendly Russian error/empty/retry states; honours OS font scaling.

## What's new — v0.5.1

<img src="docs/screenshots/update.webp" width="30%" align="right" alt="Обновление">

- **Updates from inside the app** — when a new release appears on GitHub, a
  banner says «Доступна версия X · N МБ» over whatever screen is open (checked
  when the app opens or comes back, at most every 6 hours). «Обновить»
  downloads the APK for this phone — with or without the mail client, for its
  CPU type — checks it against the size and SHA-256 GitHub publishes, and
  opens the Android installer. The first time, Android asks to allow installs
  from Волгатех.Коллектив.
- «Позже» hides the banner for that version; **Настройки → Обновления** still
  offers it, checks on demand and links to the release notes.
- Android installs it only if it carries the app's own signing key, so the
  update can't be swapped for someone else's file.

<br clear="right">

## What's new — v0.5.0

- **Built-in mail client** — in the new `app-mail-*` APKs, «Почта» shows your
  university mailbox natively instead of the web page. Sign in once with the
  mail password (kept in the OS keystore).
  - **The list** — Outlook-style headings («Сегодня», «Вчера», «На этой
    неделе»…), unread dots, messages pinned in Outlook on top in a folding
    «Закреплённые» group, the size of every message, and rows **tinted by
    size**: yellow from 100 KB, orange at 1 MB, red from 10 MB. Pull to
    refresh; search; the folder picker shows unread counts.
  - **Swipe** left to delete (with «Отменить» for a few seconds), right to
    mark read / unread.
  - **Reading** — HTML mail with remote images blocked; attachments open,
    save to the phone or share; tap the sender line for everyone on the
    message; move a message to another folder.
  - **Writing** — reply and forward; suggestions from the university
    address book in «Кому» / «Копия»; attachments up to 18 MB; a signature
    (imported once from the web mail); 5 seconds to cancel sending; text left
    unsent is kept as a draft.
  - **Автоответ** — out-of-office replies, set on the mail server like in
    Outlook, so they work with the phone off.
  - **Размер ящика** — space used, per folder, with a fill bar next to
    «Входящие». The server doesn't tell the app the limit, so it can be typed
    in once from the web mail («…достигнет 512.00 МБ»).
  - **Unread badge** on «Почта» and on the ☰ button.
- The plain APKs keep opening the web mail, as before.

## What's new — v0.4.2

- **Updates install in place** — releases are now signed with one permanent
  key. Before, every build carried a new key and Android refused the update
  («Приложение не установлено: конфликт пакетов»). One-time: uninstall the old
  app first; you will need to sign in again and re-enter the memo header.

## What's new — v0.4.1

- **Настройки** show the installed version (was stuck at v0.1.0).
- **Dark theme** — buttons and checkboxes are a lighter blue, so «Сформировать
  .docx» no longer looks disabled.

## What's new — v0.4.0

- **Служебная записка по иностранным группам** — Menu → «Иностранные группы»
  lists the month's classes with foreign-student groups (3-digit numbers such as
  ИСТ-110…ИСТ-410), one row per class at 2 h, and shares the memo as a .docx
  filled into the portal's template (total in the last cell, e.g. «2/78»).
  Untick classes, add ones by hand, shorten subject names; the letterhead and
  signature fields are filled once and remembered. During the first ten days the
  previous month is preselected.
- **Faster, works offline** — the schedule shows the saved copy instantly and
  refreshes in the background; the next week is prefetched; loading
  placeholders in the week overview; the profile photo is cached.
- **Fewer surprise logouts** — a network hiccup while renewing the session no
  longer signs you out; when the session really expires you get a notice and
  land on the login screen.

## What's new — v0.3.2

- **Shared lessons** — when two groups are taught together in the same room at
  the same time, the schedule now shows **one card** with a «N групп вместе»
  badge and the group chips (instead of duplicate cards); the week overview
  merges those rows and counts distinct slots.
- **Classical lesson icons** — Лекции = book, Практические = pencil,
  Лабораторные = microscope.

## What's new — v0.3.1

- **Login accepts an e-mail** — typing your full corporate address
  (`KonkinNA@volgatech.net`) now logs in: it's reduced to the bare account name
  (`konkinna`), trimmed and lowercased.

## What's new — v0.3.0

- **«Обзор недели» — swipe between weeks** (horizontal drag, like the day view),
  with a loading bar while the next week loads.
- **Auto-scrolling lesson names** — long subject titles that don't fit now gently
  scroll instead of being cut off with «…».
- **«Профиль» in the menu** — an explicit drawer entry (the header photo was
  tappable but easy to miss).
- **Почасовая appointments** show an approximate annual load («≈N ч.») alongside
  the ставка rows and the combined-load line.

## What's new — v0.2.0

- **«Обзор недели»** — a whole-week schedule overview off the Расписание screen:
  Пн–Вс day cards, lessons per day, first–last span, gaps («окна»), total pairs,
  the week colour, and tap-a-day to jump. Pure aggregation over the already-loaded
  week — no extra network calls.
- **Профиль** enriched from the real `GetInfo` data: birthday, every appointment
  ranked with the main department first (+ «основное» badge), each with its rate
  and start date, a **ставка vs почасовая** split with a «Суммарная нагрузка»
  line, and corrected Russian plurals for стаж.
- **iOS** — the build is now verified on every push by a macOS CI job
  (`flutter build ios --no-codesign`); a signed release (device / TestFlight /
  App Store) is documented in [docs/IOS_RELEASE.md](docs/IOS_RELEASE.md).
- More unit tests (schedule week-summary, profile parsing, RU pluralisation).

## What's new — v0.1.0

- First public build.
- In-app **Почта** and **Портал** (WebView) replacing the old link-outs.
- App identity: name **«Волгатех.Коллектив»**, icon = cleaned official ВОЛГАТЕХ logo.
- Biometric / PIN **app-lock** (opt-in).
- Schedule **week-type colours** + swipe-between-days + skeleton loader.
- Fixes: release builds now have network access; schedule day no longer shifts
  by a day across time zones.
- 18 unit tests; GitHub Actions CI/CD.

## Build

```bash
cd app
flutter pub get
flutter analyze
flutter test
flutter build apk --release --split-per-abi   # Android: per-ABI APKs (arm64 ≈ 20 MB)
flutter build apk --release --split-per-abi --dart-define=MAIL=true   # …with the built-in mail client
flutter build ios --release --no-codesign      # iOS: unsigned build (needs macOS + Xcode)
flutter build web --release --no-web-resources-cdn   # the browser version, in build/web
```

To see the web build as an iPhone shows it, serve `build/web` and open it with the
phone's safe-area insets (top, right, bottom, left) in the address, e.g.
`http://localhost:8099/?insets=59,0,34,0` for an iPhone 15 in a 393×852 window;
`test/iphone_layout_test.dart` checks every screen at each iPhone's size, and
`test/desktop_layout_test.dart` the computer layout in windows from 800×600 to
1920×1080.

Requirements: Flutter **stable**, JDK 17, Android SDK (compileSdk 36). minSdk is
24 (Android 7.0). For iOS: macOS with **full Xcode** + CocoaPods; deployment
target is iOS 15.0. A **signed** iOS build (device install / TestFlight / App
Store) needs an Apple Developer account — see **[docs/IOS_RELEASE.md](docs/IOS_RELEASE.md)**.

App icons are generated from `app/assets/icon/` with:

```bash
cd app && dart run flutter_launcher_icons
```

## CI/CD

GitHub Actions (Flutter **stable** channel):

- [`ci.yml`](.github/workflows/ci.yml) — on every push/PR to `main`: a Linux job
  runs `flutter analyze` + `flutter test` and builds the release APKs and the
  web version, and a macOS job builds the app for **iOS** (`--no-codesign`);
  both upload their output as workflow artifacts.
- [`release.yml`](.github/workflows/release.yml) — on a `v*` tag: builds the
  per-ABI release APKs twice (`app-mail-*` with `--dart-define=MAIL=true`,
  and the plain `app-*`), signed with the release key from the repository
  secrets `ANDROID_KEYSTORE_BASE64` / `ANDROID_KEYSTORE_PASSWORD` (it refuses to
  publish without them, or if an APK carries another certificate), and attaches
  them to a GitHub Release. (A signed iOS
  release needs an Apple Developer account — see [docs/IOS_RELEASE.md](docs/IOS_RELEASE.md).)

- [`web.yml`](.github/workflows/web.yml) — when `main` changes: builds the web
  version and publishes it twice:
  - **GitHub Pages** (Settings → Pages → Source: GitHub Actions), served as
    https://konkin-nikita.ru/volgatech.corp/;
  - **GitVerse Pages**: with the variable `GITVERSE_REPO` = `owner/repo` and the
    secret `GITVERSE_TOKEN` set, the site, [README.ru.md](README.ru.md) (as its
    README) and the screenshots replace the files on that repository's default
    branch, and GitVerse publishes the branch's root as
    https://nikita-konkin.gitverse.site/volgatech-corp/ (its Settings → Pages:
    on, from the branch — allowed once the repository has any file in it).
- [`gitverse-release.yml`](.github/workflows/gitverse-release.yml) — copies a
  GitHub Release to the GitVerse repository's releases: its APKs and the
  «Что нового» of that version from README.ru.md. `release.yml` runs it after
  every release; by hand (Actions → GitVerse release → Run workflow) it copies
  any tag, the latest when none is given. Running it again only adds what's
  missing.

Cut a release:

```bash
git tag v0.2.0 && git push origin v0.2.0
```

## Roadmap

See [IMPROVEMENTS.md](IMPROVEMENTS.md).
