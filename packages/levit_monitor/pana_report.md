
## ✓ Follow Dart file conventions (30 / 30)
### [*] 10/10 points: Provide a valid `pubspec.yaml`

### [*] 5/5 points: Provide a valid `README.md`

### [*] 5/5 points: Provide a valid `CHANGELOG.md`

### [*] 10/10 points: Use an OSI-approved license

Detected license: `MIT`.


## ✗ Provide documentation (10 / 20)
### [x] 0/10 points: 20% or more of the public API has dartdoc comments

Dependency resolution failed, unable to run `dartdoc`.

### [*] 10/10 points: Package has an example


## ✓ Platform support (20 / 20)
### [*] 20/20 points: Supports 5 of 6 possible platforms (**iOS**, **Android**, Web, **Windows**, **macOS**, **Linux**)

* ✓ Android

* ✓ iOS

* ✓ Windows

* ✓ Linux

* ✓ macOS


These platforms are not supported:

<details>
<summary>
Package not compatible with platform Web
</summary>

Because:
* `package:levit_monitor/levit_monitor.dart` that imports:
* `package:levit_monitor/src/transports/file_transport.dart` that imports:
* `dart:io`
</details>


## ✗ Pass static analysis (0 / 50)
### [x] 0/50 points: code has no errors, warnings, lints, or formatting issues

* Running `dart pub outdated` failed with the following output:

```
Because levit_monitor depends on levit_reactive ^0.0.4 which doesn't match any versions, version solving failed.
You can try the following suggestion to make the pubspec resolve:
```


## ✗ Support up-to-date dependencies (10 / 40)
### [x] 0/10 points: All of the package dependencies are supported in the latest version

* Could not run `dart pub outdated`: `dart pub get` failed:

```
OUT:
Resolving dependencies...
ERR:
Because levit_monitor depends on levit_reactive ^0.0.4 which doesn't match any versions, version solving failed.


You can try the following suggestion to make the pubspec resolve:
* Try updating the following constraints: dart pub add levit_dart:^0.0.3 levit_reactive:^0.0.3 logger:^2.6.2 meta:^1.17.0 web_socket_channel:^3.0.3
```

### [*] 10/10 points: Package supports latest stable Dart and Flutter SDKs

### [x] 0/20 points: Compatible with dependency constraint lower bounds

`dart pub downgrade` failed with:

```
OUT:
Resolving dependencies...
ERR:
Because levit_monitor depends on levit_reactive ^0.0.4 which doesn't match any versions, version solving failed.


You can try the following suggestion to make the pubspec resolve:
* Try updating the following constraints: dart pub add levit_dart:^0.0.1 levit_reactive:^0.0.1 logger:^1.0.0 meta:^1.3.0 web_socket_channel:^2.0.0
```

Run `dart pub downgrade` and then `dart analyze` to reproduce the above problem.

You may run `dart pub upgrade --tighten` to update your dependency constraints, see [dart.dev/go/downgrade-testing](https://dart.dev/go/downgrade-testing) for details.


Points: 70/160.
