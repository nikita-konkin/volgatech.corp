# Volgatech PRO rebuild — improvements & roadmap

Grounded in the reverse-engineered original (see `reverse_engineering/API_CONTRACT.md`)
and the stated goals: **fix the bugs, be fast, run on old devices, Android + iOS.**

Priority: **P0** = do before/with core screens · **P1** = soon · **P2** = later.
Effort: **S** ≤½day · **M** ~1–2 days · **L** ≥3 days. Status as of scaffold.

---

## 1. Security & privacy  *(the original's worst problems)*

| # | Item | P | Effort | Status |
|---|------|---|--------|--------|
| 1.1 | **Never store the password.** Original wrote `{login,password}` to `localStorage.logpassCache`. New app keeps only tokens in the OS keystore. | P0 | — | ✅ done |
| 1.2 | **Never log tokens.** Original did `console.log(accessToken/refreshToken)`. Ensure no token/PII in logs or crash reports. | P0 | S | ✅ by design |
| 1.3 | **App-open lock (biometric/PIN).** Staff data (schedule, salary-adjacent) on a phone — optional lock via `local_auth`. | P1 | M | todo |
| 1.4 | **Refresh-token rotation.** Persist the new refresh token each refresh (already saved); confirm server rotates and old tokens invalidate. | P1 | S | ✅ interceptor saves |
| 1.5 | **Certificate pinning (optional).** Original had none. Pinning adds defense but raises maintenance/breakage risk on cert rotation — recommend *leaving off* unless IT commits to a stable cert. | P2 | M | decide |

## 2. Reliability & correctness

| # | Item | P | Effort | Status |
|---|------|---|--------|--------|
| 2.1 | **Drop the failing `PageHelp` call** (returned 400 every screen). | P0 | — | ✅ not ported |
| 2.2 | **Real loading / empty / error+retry states** on every screen (original swallowed errors into toasts). | P0 | M | ✅ schedule; apply to all |
| 2.3 | **Offline cache.** Persist last schedule/exams/profile so the app opens usefully with no network (old devices, spotty 3G). Add a small cache layer (Hive/Drift or JSON-in-secure-prefs). | P1 | M | todo |
| 2.4 | **Refresh-race safety** (one refresh at a time, queue retries). | P0 | — | ✅ QueuedInterceptor |
| 2.5 | **Timezone correctness.** API returns Moscow offsets (`+03:00`). Parse/display using the event's offset, not the device TZ, so schedules are right for users in other zones. | P1 | S | verify |
| 2.6 | **Handle QRATOR/5xx/HTML challenge** responses distinctly from data errors. | P2 | S | todo |

## 3. Performance & old-device support  *(core goal)*

| # | Item | P | Effort | Status |
|---|------|---|--------|--------|
| 3.1 | **Native Flutter (no WebView).** Root cause of the old app's jank. | P0 | — | ✅ chosen |
| 3.2 | **Ship a small release build.** Debug APK is ~160 MB; release with `--split-per-abi` (arm64 + armeabi-v7a) lands ≈ 8–15 MB. Old 32-bit devices need `armeabi-v7a`. | P0 | S | todo |
| 3.3 | **Lower `minSdk` to 21** (Android 5.0) for maximum reach — Flutter default is 24. Verify plugins (secure_storage/url_launcher/dio all OK ≤21). | P1 | S | todo |
| 3.4 | **Impeller check on old GPUs.** Impeller/GLES is on and good for weak GPUs, but test on a real old device; keep a Skia fallback option if artifacts appear. | P1 | S | test |
| 3.5 | **Cut network chatter.** Cache dictionaries; conditional/parallel fetches; avoid re-fetching a week already loaded. | P1 | S | ✅ week cache; extend |
| 3.6 | **Const widgets / minimal rebuilds** — cheap wins for low-end CPUs. | P2 | S | ongoing |

## 4. UX improvements  *(beyond 1:1 parity)*

| # | Item | P | Effort | Notes |
|---|------|---|--------|-------|
| 4.1 | Password visibility toggle | P0 | — | ✅ done |
| 4.2 | **Surface week type** (`weekTypeName` «Красная/зелёная неделя», `weekNumber`) — the API gives it; the schedule should show it. | P1 | S | data ready |
| 4.3 | **Swipe between days** + "Сегодня" jump + a week/agenda overview. | P1 | M | |
| 4.4 | **Color-code by lesson type** (Лекции/Практические/Лабораторные) with clear icons. | P1 | S | icons in place |
| 4.5 | **Dark mode** — battery win on old AMOLED, accessibility. | P1 | M | |
| 4.6 | **Skeleton loaders** instead of spinners. | P2 | S | |
| 4.7 | **Accessibility**: honor OS font scaling, adequate contrast/hit targets. | P1 | S | |
| 4.8 | **Push notifications** for news/deadlines (original used Firebase). Needs a Firebase project from IT — can't reuse theirs. | P2 | L | needs IT |

## 5. Feature roadmap  *(build order)*

- **P0 (done):** Login · Schedule (day nav, refresh).
- **P1:** **Exams** (+ study-year picker — models captured) · **News/notifications** list · **Profile** screen (photo via `GetPersonPhotoByName`).
- **P2:** **Обращения / Requests** (full CRUD + dictionaries + comments + attachments — models in `IAppeal.ts`) · **Progress/grades** (`GetProgressSemestrWithAtt`) · **Settings** (start page, theme, language).

## 6. External integrations (mail & portal)

- **Now:** link-out buttons to `mail.volgatech.net/owa` and `portal.volgatech.net` — no password handled, nothing scraped. ✅ done.
- **Needs VolgaTech IT** (enterprise systems, admin-gated): mail data via **EWS/IMAP/ActiveSync**; portal via its API (likely Bitrix webhook or SharePoint/Graph). Then we can add e.g. an unread-mail badge or portal announcements. **Draft an IT request** covering: API docs + test account for `api.volgatech.net`, and whether mail/portal APIs can be enabled. Never store the corporate password.

## 7. Engineering hygiene

| # | Item | P | Effort |
|---|------|---|--------|
| 7.1 | **Prod/Test flavors** — toggle `api.volgatech.net` ↔ `test-api.volgatech.net`. | P1 | S |
| 7.2 | **Tests**: JSON parsing for all models, interceptor refresh logic, login/schedule widget tests. | P1 | M |
| 7.3 | **Crash monitoring** (Sentry/Crashlytics) with PII/token scrubbing. | P2 | S |
| 7.4 | **CI** to build APK/IPA on push. | P2 | M |
| 7.5 | **Finish the API contract**: capture `News`, `GetProfiles`, `GetInfo`, `GetProgressSemestrWithAtt` bodies. | P1 | S |
| 7.6 | **iOS pass**: signing, run on old iOS/simulator (app is Android-verified only so far). | P1 | M |

## 8. To send VolgaTech IT (backend — we don't touch it, but they might fix)

- `GET /api/PageHelp/person` → 400 (server can't find `…\Files\PageHelpFiles\person`).
- Provide API documentation + a **test account** to support an official rewrite.
- Confirm token TTLs / refresh rotation behavior.
- If integration is wanted: enable mail (EWS/IMAP) and/or a portal API.

---

### Sprint 1 — DONE ✅
1. **Release build + minSdk** — `--split-per-abi` release APKs: **16 MB** (armeabi-v7a, 32-bit) / **19 MB** (arm64) / 20 MB (x86_64), vs the 153 MB debug. `minSdk = 23` (Android 6.0). *Note: Flutter's "Upgrading build.gradle.kts" step resets manual `minSdk` edits — re-check after `flutter build`.*
2. **Exams screen** — study-year dropdown, exams grouped by date, offline cache; wired into the drawer. Models `StudyYear`/`Exam` captured live.
3. **Offline cache** (`lib/core/cache.dart`, path_provider) — schedule & exams save each successful load and fall back to it on network failure, with an "Нет сети — сохранённые данные" banner.
4. **Friendly RU errors** — Dio timeouts/connection errors → «Нет соединения с сервером» / «Превышено время ожидания» instead of raw English; longer timeouts (connect 40s / receive 60s).

*Verified on emulator: build+install+run, login (session persists), schedule real data, drawer, Exams navigation, RU error/retry states. Live exam data + the offline-cache banner still need one successful fetch to seed — blocked intermittently by the sandbox's slow NL→RU emulator network, not by app code (host reaches the API instantly).*

### Sprint 2 — DONE ✅
1. **Credential autofill** — login fields use the OS autofill framework (`AutofillGroup` + username/password hints + `finishAutofillContext()`), so the device's password manager saves & fills both securely. Plus a **"Запомнить логин"** checkbox that stores only the username (SharedPreferences). *The raw password is still never stored by the app* — session persistence + the system vault cover re-entry.
2. **Profile screen** — avatar (`GetInfo.fileName`), `personFIO`, position/department (`actualSalaries`), experience (`personExperiences`). Also fills the **drawer** name/photo (fetched on login + bootstrap, cached for offline). Fields verified from the original templates.
3. **Dark mode + Settings** — de-stubbed «Настройки»: theme toggle (Системная/Светлая/Тёмная), persisted; all surfaces made theme-aware.
4. **Week type on schedule** — «Красная/зелёная неделя · неделя N» chip (data was already in the calendar response).

**News deferred:** `/api/News/2/0` has no recoverable list template in the bundle, so the item model is unconfirmed. Build it after a live capture of the response body (needs a moment when the emulator↔RU backend is up, or capture on a real device).

### Sprint 3 — DONE ✅ (bug-fix + hardening focus)
1. **🔴 Fixed: release build had no network.** `INTERNET` permission was only in the debug/profile manifests (Flutter default); added it to `src/main/AndroidManifest.xml`. This was the "нет соединения с сервером" on real devices. Also added a `VIEW https` query so Почта/Портал launch on Android 11+.
2. **🔴 Fixed: schedule day shifted (Sun instead of Mon).** API timestamps carry `+03:00`; `DateTime.parse` re-anchored them to the device zone, pushing lessons to the previous day. New `lib/core/date_utils.dart` (`apiWallClock`/`apiCalendarDate`) treats API times as the institution's wall-clock — day & time stay correct on any device. Applied to schedule + exams.
3. **Tests added** (`flutter test`, 10 passing): TZ/day-shift regression, model parsing + cache round-trips, RU error mapping.

**Deferred (need a live API capture — not in the original UI, so no model to recover):**
- **News** (`/api/News/2/0`) — fetched but no list template in the bundle.
- **Progress/grades** (`GetProgressSemestrWithAtt`) — defined in the service but **never called** by any screen; likely a student-only feature absent from the staff app.

### Sprint 4 — Polish & hardening — DONE ✅
1. **Week-type colour theming** (user ask). The date bar, lesson-card accent stripe and the week chip now take the week's colour — **red for week 1, blue for week 2**, grey when unknown — mirroring the original `schedule.ts` rule (`weekNumber == 1 ? 'red' : 'blue'`). Pure helper `Brand.weekAccentFor` (unit-tested); the week is resolved across the *loaded* week so the colour is stable on days with no lessons (and never bleeds in from the adjacent, opposite-numbered week).
2. **Swipe between days** — horizontal fling on the schedule pages forward/back, matching the arrows.
3. **Skeleton loader** — shimmering placeholder cards on first load instead of a bare spinner (no plugin; a moving gradient).
4. **Biometric / PIN app-lock** (1.3) — opt-in in Настройки → Безопасность (`local_auth`). Off by default. Re-locks on background; prompts on open. **Safe by design:** enabling performs a real auth first (so a device that can't authenticate can't self-lock-out), `biometricOnly:false` allows a device PIN on phones with no sensor, and the lock screen has a **«Выйти»** escape (disables the lock + clears the session → login). Native: `MainActivity : FlutterFragmentActivity`, `USE_BIOMETRIC`, iOS `NSFaceIDUsageDescription`.
5. **Accessibility** — confirmed no `textScale` overrides anywhere, so OS font-scaling is already honoured.

Tests now **18 passing** (added week-accent mapping ×4, app-lock start-state/disable ×4).

### Backlog
- **Обращения / Requests** — full CRUD + dictionaries + comments + attachments (models in `IAppeal.ts`). *Deferred by request.*
- **Native mail inbox** — *backlogged.* Mail is **on-prem Exchange 2016** (`webmail.marstu.net`, forest `marstu.net`, build 15.1.2507.61), **not M365** → no OAuth/Graph, so a native client needs **Basic auth with the AD domain password** (EWS or IMAP). ActiveSync is enabled (native phone Mail works). If built: **opt-in, single-user only**, password in Keystore + app-lock, never default. Confirm IMAP is enabled (webmail.marstu.net:993) first. Superseded for now by the in-app OWA WebView tab.
- iOS signing pass (7.6), CI (7.4), week/agenda overview + "Сегодня" jump (4.3).

### Sprint 5 — Branding + in-app web — DONE ✅
1. **App identity** — display name **«Волгатех.Коллектив»** (Russian primary; Latin «Volgatech.CORP» retired), icon = the **official ВОЛГАТЕХ logo** upscaled + denoised (background whitened), generated for Android adaptive/legacy + iOS.
2. **In-app «Почта»** — OWA opens inside the app (WebView): progress bar, refresh, open-in-browser, in-webview back. Cookie-only, never the password.
3. **In-app «Портал»** — same generic `WebViewScreen` now also powers `portal.volgatech.net` (was a link-out).
4. **Easter egg** — Настройки → tap the version footer 7× reveals the РТФ (Радиотехнический факультет) crest.

---

## Future roadmap (planned)

### A. Schedule — the next focus
- **A1. Whole-week summary view** *(user ask, P1, M)* — an overview of the entire week on one screen (Mon–Sun columns/rows), lesson counts per day, gaps/"окна", first/last pair, total hours, and the week colour. Tap a day → jump to it. Data is already loaded per-week (`ScheduleController._byDay`), so this is a UI/aggregation layer, no new API.
- **A2. Group level badge** *(user ask, P1, S — feasible)* — the **education level is encoded in the group-name suffix**, not in any API field. Parse `fullDescription`/`groupName`: suffix **«м» → магистр**, **«а» → аспирант** *(letter to confirm)*, otherwise **бакалавр**. Show a small badge on each lesson/exam. Pure client-side helper + unit tests. ⚠️ Confirm the аспирант suffix letter before shipping.
- **A3. Group mode of study (форма обучения)** *(user ask, P2, BLOCKED)* — очная / заочная / очно-заочная is **not present in any captured response** and **not obviously encoded** in the group names we have ("ИСТ-110", "ИСТ-41", "ИТСм"). To build it we need one of: (a) the **naming convention** that distinguishes заочная/очно-заочная groups (e.g. a letter/prefix — user to provide), or (b) confirmation of a field via a fresh live capture. Until then, can't be derived reliably.
- **A4. Week/agenda niceties** — "Сегодня" jump, colour-by-lesson-type already partly done (4.4), skeletons done.

### B. Data-blocked features (need a live capture)
- **B1. News** (`/api/News/2/0`) — no list template recovered; capture the body on a real device, then build.
- **B2. Progress/grades** (`GetProgressSemestrWithAtt`) — defined but never called in the original; likely student-only. Confirm via capture before building.

### C. Bigger features
- **C1. Обращения / Requests** — full CRUD + dictionaries + comments + attachments (models in `IAppeal.ts`). Largest remaining feature; buildable without new capture.
- **C2. Native mail inbox** — backlogged (on-prem Exchange 2016, no OAuth → Basic auth only). Opt-in/single-user/Keystore+app-lock if ever built; confirm IMAP `webmail.marstu.net:993` first.

### D. Engineering
- **D1. iOS pass** — signing + run on device/simulator (Android-verified only so far).
- **D2. CI** — build APK/IPA on push. **D3. Crash monitoring** (Sentry, token/PII-scrubbed). **D4. Prod/Test flavor toggle** (`api` ↔ `test-api`).

### Recommended order
**A1 (week summary) → A2 (level badge)** next — both are pure client-side, high value, and directly requested. Then **A3** once the naming convention is known, and **B1 News** on the next live capture.
