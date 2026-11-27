# Contributing to Levit

First off, thank you for considering contributing to Levit! It's people like you that make Levit such a great tool for the community.

## Code of Conduct

By participating in this project, you are expected to uphold our Code of Conduct. Please act professionally and respectfully at all times.

## How Can I Contribute?

### Reporting Bugs

-   **Ensure the bug was not already reported** by searching on GitHub under [Issues](https://github.com/softilab/levit/issues).
-   If you're unable to find an open issue addressing the problem, [open a new one](https://github.com/softilab/levit/issues/new). Be sure to include a **title and clear description**, as well as as much relevant information as possible, and a **code sample** or an **executable test case** demonstrating the expected behavior that is not occurring.

### Suggesting Enhancements

-   Open a new issue with the **enhancement** label.
-   Explain why this enhancement would be useful to most Levit users.

### Pull Requests

1.  Fork the repo and create your branch from `main`.
2.  If you've added code that should be tested, add tests.
3.  If you've changed APIs, update the relevant documentation (`README.md`, package READMEs, and inline DartDoc as needed).
4.  Ensure formatting, analysis, and tests pass before opening the PR.

## Development Setup

Levit is a monorepo managed by **Melos**.

### Prerequisites

Use FVM to select the repository’s Flutter version from `.fvmrc` and Melos 6.3.3 to run workspace commands.

| What you want to do | Minimum SDK | Why |
| --- | --- | --- |
| Use `levit` in a pure Dart app | Dart 3.2.0 | The reactive runtime uses Dart 3.2’s type promotion for private final fields. |
| Use `levit_flutter` in a Flutter app | Flutter 3.16.0 | It bundles Dart 3.2.0 and provides the bottom-sheet sizing API the Flutter kit uses. |
| Build the DevTools extension UI on its own | Flutter 3.22.0 | It provides the Material surface colors the UI uses and bundles Dart 3.4.0 for `levit_monitor`. |
| Start a new app with all Levit tools (recommended) | **Dart 3.10.0** for pure Dart apps or **Flutter 3.38.1** for Flutter apps | The `levit_lints` plugin requires Dart 3.10.0. Flutter 3.38.1 is the first stable Flutter release to bundle stable Dart 3.10.0. |
| Run all repository checks | **Flutter 3.38.1** | The workspace runs Flutter tests and loads `levit_lints` with Flutter’s bundled Dart SDK. |

### Standalone workspace projects

For library and tool requirements, see the [minimums by package](README.md#minimums-by-package).

| Standalone workspace project | Minimum Dart | Minimum Flutter | Reason |
| --- | --- | --- | --- |
| Nexus Studio shared | 3.2.0 | — | Depends on the Dart core runtime. |
| Bundled widget examples, task board, async catalog, scope playground, stress tests | 3.2.0 | 3.16.0 | Depend on the Flutter runtime. |
| Nexus Studio server | 3.5.0 | — | Uses `shelf_web_socket` 3.x. |
| Route scopes and Nexus Studio app | 3.6.0 | 3.27.0 | Use Flutter's `Color.withValues` API. |
| Benchmarks | 3.9.0 | 3.35.0 | `fl_chart` requires `vector_math` 2.2, which Flutter first pins in 3.35. |

### Bootstrap

Run these commands from the repository root so Melos and Pub use the same SDK.

```bash
fvm install
export PATH="$PWD/.fvm/flutter_sdk/bin:$PATH"
dart pub global activate melos 6.3.3
dart pub get
melos bootstrap
```

If you manage Flutter directly, set `MELOS_SDK_PATH` to your Flutter SDK
directory and use its `bin` directory on `PATH` before bootstrapping.

### Running Checks

Use the workspace scripts from the repository root:

```bash
melos run ci --no-select
melos run coverage --no-select
melos run publish:dry-run --no-select
```

For focused local checks, use:

```bash
melos run analyze --no-select
melos run test --no-select
melos run test:flutter --no-select
```

### Development tools and reports

Keep `scripts/` limited to maintained development, CI, build and release checks.
Use Dart for reusable tooling; use Melos directly when a command needs no script.
Temporary migrations and one-off investigation tools belong outside the repository.

The two retained reports can be regenerated from the repository root:

```bash
melos run stress --no-select
melos run report:benchmarks --no-select
```

These write [stress results](reports/stress_test_report.md) and
[benchmark results](reports/benchmark_report.md). Run performance measurements
on an idle machine, separately from other checks. The benchmark report uses a
headless test profile; see [the benchmark guide](benchmarks/README.md) for its limits.

For an optional local test-coverage summary, run
`dart run scripts/check_coverage.dart --fail-under=100 --generate-report`.
It writes `coverage/packages_test_coverage.md`, which is ignored by Git along with
raw coverage data. Keep ongoing design guidance in `docs/`; historical audits,
release investigations and their tooling remain available in Git history.

## Style Guide

-   We follow the official [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style).
-   We value **explicit over implicit**. Code should be easy to read and understand.
-   We prioritize **correctness over convenience**.

## License

By contributing, you agree that your contributions will be licensed under its MIT License.
