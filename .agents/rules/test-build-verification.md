# Rule: Test and Build Verification for Every Change

**Effective:** 2026-09-24
**Scope:** All code changes in `atlas-app` (lib/, test/, plugins, native).

## Requirement
For **every** change implemented (feature, fix, refactor, config):
1. **Write/Update Tests** — unit, widget, or integration covering the changed behavior.
   - Location: `test/<area>/<feature>_test.dart` mirroring `lib/` structure.
   - Use `package:test` / `flutter_test` + `mocktail` as in existing suite.
   - Run: `dart test` or `flutter test <path>` — must pass.

2. **Build Verification** — prove the app still builds on all targets.
   - `dart analyze` — 0 issues (scoped to changed files if full analyze hangs on `sherpa_onnx` code_assets).
   - `flutter build <platform>` as applicable: `flutter build apk --debug` (Android), `flutter build windows --debug` (Windows), `flutter build ios --no-codesign` (iOS), `flutter build macos` (macOS). At minimum `flutter analyze` + `flutter test`.

3. **Evidence** — attach in PR/commit message:
   ```
   Test: flutter test test/speech/... — 6 passed
   Build: dart analyze lib/... — No issues; flutter build windows — Built
   ```

## Enforcement
- Agent harness: After each `Edit`/`Write`, call `register_edit` and then run `flutter test` + `dart analyze` for changed files before marking done.
- CI: `tool/ci_check.sh` (to be added) will run `dart analyze` + `flutter test` on PR.

## Template
When implementing a change, agent must output:
- Files changed
- Tests added/updated + result
- Build verification commands + result
