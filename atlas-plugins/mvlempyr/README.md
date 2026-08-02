# MVLEMPYR plugin

Novel source for [www.mvlempyr.io](https://www.mvlempyr.io).

## Files

| File | Purpose |
| --- | --- |
| `plugin.json` | Manifest: template, transport, capabilities, version |
| `filters.json` | Content cleaner tweaks |
| `permissions.json` | Stealth/rate-limit tuning |
| `tests/fixtures/*.html` | Recorded pages for CI smoke tests |
| `tests/expected.json` | Expectations the fixture smoke tests assert |

## Validation

Run from the package root:

```sh
dart run tool/plugin_validator.dart
dart run tool/generate_plugin_catalog.dart   # refresh index.json checksums
dart run tool/registry_gen.dart              # refresh registry.json
```
