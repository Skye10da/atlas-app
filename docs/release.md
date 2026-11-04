# Releasing Atlas (self-updating, no app store)

Atlas distributes itself through GitHub Releases. The in-app updater
(`lib/updater/`) polls the *latest* GitHub Release of `Skye10da/atlas-app`
on start and in Settings → **App updates**, compares versions, then downloads
and installs the right artifact:

| Platform | Artifact | Update mechanism |
|---|---|---|
| Android | `atlas-v<tag>-android.apk` | system "Install update?" dialog |
| Windows | `atlas-v<tag>-windows.zip` | swap-on-restart (updater script) |
| macOS   | — | not implemented yet (needs Apple Developer decision) |
| iOS     | — | not possible outside TestFlight/MDM |

## 1. One-time setup: signing & secrets

The Android release build is signed with a keystore generated once locally and
delivered to CI through repo **secrets**.

```powershell
# 1) Generate the keystore (keep this file + passwords safe forever; losing it
#    means users can no longer install newer builds over the old one).
keytool -genkey -v -keystore atlas-release.jks `
  -keyalg RSA -keysize 2048 -validity 10000 `
  -alias atlas

# 2) Base64-encode it for the GitHub secret
[Convert]::ToBase64String([IO.File]::ReadAllBytes("atlas-release.jks")) | Set-Clipboard
```

Then on <https://github.com/Skye10da/atlas-app/settings/secrets/actions> add:

| Secret | Value |
|---|---|
| `ANDROID_KEYSTORE_B64` | the base64 output above |
| `ANDROID_STORE_PASSWORD` | keystore password |
| `ANDROID_KEY_ALIAS` | `atlas` |
| `ANDROID_KEY_PASSWORD` | key password |

Never commit `android/key.properties` or any `*.jks` (both are gitignored).

To also sign locally: copy the `.jks` into `android/app/`, and create
`android/key.properties`:

```
storeFile=atlas-release.jks
storePassword=<password>
keyAlias=atlas
keyPassword=<password>
```

Without those files the app keeps falling back to debug signing — CI errors out
instead (`ANDROID_KEYSTORE_B64` secret is required).

## 2. Cut a release

1. Bump `version:` in `pubspec.yaml` (e.g. `1.0.8+8`).
2. Promote the changelog: move everything under `## [Unreleased]` in
   `CHANGELOG.md` to `## [1.0.8] - <today>` (version without the `+build`
   suffix). The GitHub Release body is generated from that section — see
   `.agents/rules/commit-changelog.md`.
3. Commit both files with the full changelog in the commit body, then tag
   **with the identical version** and push:

   ```bash
   git tag v1.0.8+8
   git push origin v1.0.8+8
   ```

   The version after `+` is the `versionCode`; the updater compares it, so it
   must always increase. Tags containing `-` (e.g. `v1.0.9-rc.1+9`) publish as
   prereleases — visible only on the beta channel.

4. The workflow (`.github/workflows/release.yml`) builds the Android APK and
   Windows zip, hashes every artifact, and publishes a GitHub Release with a
   generated `manifest.json` — the feed the app consumes. The release body is
   produced by `tool/build_release_notes.py` from `CHANGELOG.md` (falling back
   to commit messages between releases); it never uses GitHub's
   `--generate-notes` compare link. The workflow also runs
   `flutter analyze`/`flutter test` as a zero-warning gate before building.

5. Dry-running: start the workflow manually from the **Actions** tab
   (`workflow_dispatch`, `dry_run: true`) — everything builds but the release
   stays a draft.

## 4. Publish-chain hardening (in place)

Defense layers protecting the self-update feed, in the order an attacker has
to defeat them:

| Layer | What it stops |
|---|---|
| Actions pinned to commit SHAs (`actions/*`, `subosito/flutter-action`) | CI supply-chain: a hacked action repo/@major tag being hijacked cannot inject code into builds |
| Tag ruleset `protect-release-tags` (ruleset 26266275, `target: tag`, active) | Anyone *except* the repo owner can create `/ update / delete `v*` tags — leaked collaborator tokens cannot cut a rogue release tag |
| `production` environment on the publish job (id 25870159633) | Deployment history/audit of every release + deploy-policy: only the `v*` tag pattern (and `main` for dry-runs) may deploy to it |
| Release APK signed with the local-only keystore | Android refuses to install a foreign-signed update over an existing install, so even a fully compromised repo cannot poison existing Android devices |
| SHA-256 manifest check | Network tampering, truncated/corrupted downloads |
| HTTPS-only GitHub API/CDN | On-path tampering of feed or artifacts |

Remaining known gap: a full compromise of the *owner's* GitHub account could
publish a rogue Windows artifact (Android is still protected by the keystore
signature). Mitigations when the update fleet is real:
Authenticode-sign the Windows build; require 2FA/hardware key on the GitHub
account; consider splitting tag-push rights to a protected runner identity.

When a second maintainer joins, upgrade the `production` environment in
repo **Settings → Environments** with *Required reviewers* (the deployer
cannot self-approve) so publishing needs one human "Approve" click beyond
pushing the tag.

## 3. Verify

* Draft release has `atlas-v…-android.apk`, `atlas-v…-windows.zip` and
  `manifest.json`.
* The release body is the promoted `CHANGELOG.md` section (real Added/Changed/
  Fixed entries). It must not be empty and must not consist of a
  `Full Changelog: .../compare/...` link.
* Install old APK → receive new tag → app shows the update → install works.
