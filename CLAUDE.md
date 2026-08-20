## Dart MCP Tool Preferences

Prefer Dart MCP tools over shell commands for all Dart/Flutter operations:

- **Testing:** Use `run_tests` instead of `flutter test` or `dart test`. It provides structured output, built-in filters, sharding, and reporters.
- **Analysis:** Use `analyze_files` instead of `flutter analyze`. It returns structured error results.
- **Formatting:** Use `dart_format` instead of `dart format`.
- **Auto-fix:** Use `dart_fix` instead of `dart fix --apply`.
- **Dependencies:** Use `pub` instead of `flutter pub` / `dart pub`.
- **App debugging:** Use `launch_app`, `hot_reload`, `get_runtime_errors`, `get_widget_tree` for live app inspection.
- **UI testing:** Use `flutter_driver` for automated UI interactions (tap, scroll, screenshot) instead of writing ad-hoc driver tests.
- **Package discovery:** Use `pub_dev_search` instead of searching pub.dev manually.

Only fall back to shell commands when an MCP equivalent does not exist or for one-off commands.

## Pre-Commit Rule

Before ANY `git commit`, you MUST:

1. Run `analyze_files` and verify zero errors and zero warnings.
2. If issues exist, fix them:
   - Run `dart_fix` for mechanical fixes first.
   - Manually fix remaining issues: remove all `print()` and `debugPrint()` calls (replace with `logger` if logging is needed), fix unused imports, resolve type errors, etc.
3. Re-run `analyze_files` after each fix batch until completely clean.
4. Only commit when analysis passes with NO errors and NO warnings.

NEVER commit with `--no-verify` or any flag that bypasses checks.
NEVER commit if `analyze_files` reports even a single warning.

## Code Style

- Use `logger` from the `logger` package instead of `print` or `debugPrint`.
- All code must pass `analyze_files` with zero issues at all times.
- Follow existing patterns in the codebase.
