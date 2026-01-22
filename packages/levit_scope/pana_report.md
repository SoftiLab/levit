
## ✗ Follow Dart file conventions (20 / 30)
### [x] 0/10 points: Provide a valid `pubspec.yaml`

<details>
<summary>
Failed to verify repository URL.
</summary>

*Repository has no matching `pubspec.yaml` with `name: levit_scope`.*

Please provide a valid [`repository`](https://dart.dev/tools/pub/pubspec#repository) URL in `pubspec.yaml`, such that:

 * `repository` can be cloned,
 * a clone of the repository contains a `pubspec.yaml`, which:,
    * contains `name: levit_scope`,
    * contains a `version` property, and,
    * does not contain a `publish_to` property.
</details>

### [*] 5/5 points: Provide a valid `README.md`

### [*] 5/5 points: Provide a valid `CHANGELOG.md`

### [*] 10/10 points: Use an OSI-approved license

Detected license: `MIT`.


## ✓ Provide documentation (20 / 20)
### [*] 10/10 points: 20% or more of the public API has dartdoc comments

46 out of 47 API elements (97.9 %) have documentation comments.

Some symbols that are missing documentation: `levit_scope.LevitScopeToBuilderExtension.toBuilder`.

### [*] 10/10 points: Package has an example


## ✓ Platform support (20 / 20)
### [*] 20/20 points: Supports 6 of 6 possible platforms (**iOS**, **Android**, **Web**, **Windows**, **macOS**, **Linux**)

* ✓ Android

* ✓ iOS

* ✓ Windows

* ✓ Linux

* ✓ macOS

* ✓ Web

### [*] 0/0 points: WASM compatibility

This package is compatible with runtime `wasm`, and will be rewarded additional points in a future version of the scoring model.

See https://dart.dev/web/wasm for details.


## ✓ Pass static analysis (50 / 50)
### [*] 50/50 points: code has no errors, warnings, lints, or formatting issues


## ✓ Support up-to-date dependencies (40 / 40)
### [*] 10/10 points: All of the package dependencies are supported in the latest version

|Package|Constraint|Compatible|Latest|Notes|
|:-|:-|:-|:-|:-|
|[`meta`]|`^1.17.0`|1.18.0|1.18.0||

To reproduce run `dart pub outdated --no-dev-dependencies --up-to-date --no-dependency-overrides`.

[`meta`]: https://pub.dev/packages/meta

### [*] 10/10 points: Package supports latest stable Dart and Flutter SDKs

### [*] 20/20 points: Compatible with dependency constraint lower bounds

`pub downgrade` does not expose any static analysis error.


Points: 150/160.
