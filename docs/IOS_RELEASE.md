# iOS release guide

The app is **iOS-ready as a project** and builds **unsigned** in CI. Turning that
into an installable / App Store build needs an **Apple Developer account** and
signing assets that only the account owner can create. This guide covers both.

## What is already done ✅

- **Bundle identifier:** `net.volgatech.volgatechPro`
- **Display name:** «Волгатех.Коллектив» (`CFBundleDisplayName`); short name «Волгатех».
- **Version:** driven by `pubspec.yaml` (`version: 0.1.0+1` → `CFBundleShortVersionString` 0.1.0, `CFBundleVersion` 1).
- **Deployment target:** iOS 15.0 (covers iPhone 6s and newer).
- **Permissions strings:** `NSFaceIDUsageDescription` («Вход в приложение по Face ID») for the app-lock.
- **App icons:** full `AppIcon.appiconset` (all sizes incl. 1024²) generated from the brand logo.
- **CI:** the `ios` job in [`ci.yml`](../.github/workflows/ci.yml) runs
  `flutter build ios --release --no-codesign` on a macOS runner on every push/PR —
  this compiles, links, and runs CocoaPods for all iOS plugins, so a broken iOS
  build is caught automatically. It uploads the unsigned `Runner.app` as an artifact.

> **Note:** an *unsigned* `.app` cannot be installed on a real iPhone. It only
> proves the build is healthy. Installing on a device requires signing (below).

## What you need for a real release 🔑

Signing is done by **you**, the account owner — this project never handles Apple
credentials, certificates, or private keys.

1. **Apple Developer Program** membership — https://developer.apple.com/programs/ (US$99/year).
2. A Mac with **full Xcode** (not just Command Line Tools) and **CocoaPods**
   (`sudo gem install cocoapods` or `brew install cocoapods`).
3. In **App Store Connect**, create an app record with bundle id
   `net.volgatech.volgatechPro` (or change the id first if you prefer a different one).
4. A **Distribution certificate** + **provisioning profile** (Xcode can manage these
   automatically once you sign in with your Apple ID under *Signing & Capabilities*).

## Build a signed IPA locally

```bash
cd app
flutter pub get

# One-time: open the workspace and set your Team under
# Runner ▸ Signing & Capabilities ▸ Team (enable "Automatically manage signing").
open ios/Runner.xcworkspace

# Then, from the CLI:
flutter build ipa --release
# → build/ios/ipa/*.ipa  (upload with Xcode Organizer or Transporter)
```

Distribution paths:
- **TestFlight** — upload the IPA; add internal/external testers. Best for a pilot.
- **App Store** — submit for review from App Store Connect.

Ad-hoc (install on specific registered devices without the store) is also possible
with an ad-hoc provisioning profile: `flutter build ipa --export-method ad-hoc`.

## Automating signed builds in CI (later)

When you're ready, the `ios` CI job can be extended to produce a **signed** IPA. The
usual approach:

- Store signing assets as GitHub **encrypted secrets** — either a base64 `.p12` +
  provisioning profile, or (cleaner) an **App Store Connect API key** used with
  [fastlane](https://docs.fastlane.tools/) `match`/`pilot`.
- Add a step: import the cert into a temporary keychain → `flutter build ipa
  --export-options-plist ExportOptions.plist` → `xcrun altool`/`fastlane pilot` upload.

This is intentionally **not** wired up yet: it requires your Apple account, and the
secrets must be added by you. Ping to set it up once membership is in place.

## Security note

Per the project's security model, this repo and its automation never store or
handle your Apple ID, App Store Connect password, or signing private keys. You
create them; you add them to GitHub Secrets if/when we automate distribution.
