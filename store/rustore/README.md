# RuStore submission checklist

Everything the RuStore console asks for, and where it comes from. Fill the test account and the e-mail address in the console only; never commit them here.

1. Ask the university's IT department for a test staff account that works in the cabinet, the mail and the portal.
2. Register in the [RuStore console](https://console.rustore.ru) as «Физическое лицо» with VK ID.
3. Check that [PRIVACY.md](../../PRIVACY.md) opens at `https://github.com/nikita-konkin/volgatech.corp/blob/main/PRIVACY.md`.
4. Run the **RuStore** workflow (Actions → RuStore → Run workflow, ref `main`). Download its artifact, `volgatech-rustore-<version>-<build + 5000>.apk` (for 0.5.10: `volgatech-rustore-0.5.10-5027.apk`), signed with the release key, without the in-app updater.
5. Create the app and upload that APK. The package is `net.volgatech.volgatech_pro`.
6. Fill the card:
   - name, short and full description, category, age rating, tags, «Что нового» and FAQ: [listing.md](listing.md);
   - icon: [icon-512.png](icon-512.png) (512×512, the launcher icon);
   - screenshots: [screenshots/](screenshots/), ten 1080×1920 PNGs with made-up data, in upload order. They must be 9:16, because RuStore crops other ratios (moderation rule 6.6);
   - privacy policy: the URL from step 3;
   - contact: your support e-mail.
7. «Безопасность данных пользователя»: data types from [data-safety.md](data-safety.md); a justification for each permission from [permissions.md](permissions.md).
8. Moderator comment: [moderator-note.md](moderator-note.md) with the test account filled in, and the university's permission attached.
9. Submit for moderation.

Later versions: every `v*` tag runs the RuStore workflow too; upload its artifact as the new version with the release's «Что нового».

The RuStore build's version code is the build number plus 5000, so it installs over any GitHub APK (same key, higher code), while a GitHub APK cannot replace it. RuStore users get updates from RuStore only.
