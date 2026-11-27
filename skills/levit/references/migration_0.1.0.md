# Migrating to Levit 0.1.0

Levit `0.1.0` is a coordinated breaking release. Upgrade all Levit packages together. The runtime kits require Dart 3.2+ or Flutter 3.16+. We recommend Dart 3.10.0+ or Flutter 3.38.1+ for projects adopting all Levit tools.

## High-Impact Renames & Surface Changes

| Before | 0.1.0 Replacement |
| :--- | :--- |
| `autoDispose(res)` | `own(res)` (add `dispose:` callback for unknown types) |
| `Lx.*` / `Ls.*` in app kits | `Levit.*` (`Levit.batch`, `Levit.untracked`, `Levit.isBatching`, `Levit.currentScope`, `Levit.put`/`find`) |
| `count(5)` to write | `count.value = 5` (`call()` is read-only) |
| `.toBuilder` | Construct inside the registration builder |
| `.levitPut` / `.levitLazyPut` / `.levitLazyPutAsync` | Explicit `scope.put(...)` or `Levit.put(...)` |
| `LView.put` / `LAsyncView.put` | `LScopedView.put` / `LScope` (or `LAsyncScope`) + `LAsyncView` |
| `initialized` | `isInitialized` |
| `computedValue` | `requireValue` |
| `runGuardedAsync(cancelOnClose:)` | `runGuardedAsync(discardResultOnClose:)` |
| `LevitQueryFamily<K, T>` / `LxFamilyHandle<T, R>` | `LevitAsyncMap<K, T>` (`queries.entry(k)`, `await queries.refresh(k)`, `await queries.fetch(k)`) or `LxStream.defer` + `restartDeferred` |
| Plain value families | `map.entry(key)` or `list.entry(index)` |
| `LStatusBuilder` `onWaiting: () => ...` | `onWaiting: (status) => ...` |
| `LStatusBuilder` `onError: (e, st) => ...` | `onError: (status) => ...` (`status.error`, `status.stackTrace`) |
| `findStoreAsync` / `*.findAsync` | `findAsyncStore` / `findAsync` |
| `retries` / `retryDelay` / `useExponentialBackoff` | Explicit `LevitRetryPolicy` |
| `package:logger` `Level` in `levit_monitor` | `LevitLogLevel` |
| Unprefixed monitor transports/events | `Levit*` prefixed (`LevitConsoleTransport`, `LevitWebSocketTransport`, `LevitFileTransport`, `LevitMultiTransport`, `LevitMonitorEvent`, etc.) |
| Advanced task engine/groups/cache/middleware from default kit barrel | Import `package:levit_flutter/tasks.dart` or `package:levit/tasks.dart` |
| Legacy `levit_devtools_ui` / custom server DevTools | Use the read-only `levit_devtools` (`LevitDevTools.attach()` over Dart VM Service), `levit_mcp`, and `levit_lints` |

## Behavioral Contracts to Audit During Migration

1. **Awaited disposal:** `close()`, `delete()`, `reset()`, `scope.dispose()`, and `stop()` are async and must be awaited.
2. **Factories:** `isFactory: true` no longer implies `permanent: true`; release owned instances with `await scope.releaseFactoryInstance(...)`.
3. **Store lookup:** Inherits ancestor instances by default; pass `localOnly: true` for fresh local state. Install overrides via `scope.applyOverrides([store.overrideWith(...)])`.
4. **View re-resolution:** Changing a closure passed to `LView` / `LAsyncView` does not refetch; pass captured inputs in `args: [...]`.
5. **Tasks:** Task calls return `Future<T>` and signal cancellation/drop/supersession via typed exceptions rather than returning `null`.
6. **Optional DI lookup:** `findOrNull<T>()` only returns `null` when unregistered; construction/type failures now propagate.
