# 🚀 Levit Framework Stress Test Report

> **Generated on:** 2026-01-07

## 📊 Performance Summary

### 🟦 Levit Reactive (Core)

| Scenario | Measured Action | Result |
| :--- | :--- | :--- |
| Deep Dependency Chain 10,000 nodes deep chain propagates changes correctly | Deep Chain Setup: Created 10000 computed nodes | **79ms** |
| Deep Dependency Chain 10,000 nodes deep chain propagates changes correctly | Deep Chain Propagation: Propagated change through 10000 nodes | **27ms** |
| Collection Bulk Operations LxList with 1,000,000 items and bulk mutations | Large list assign (1M items) | **20ms** |
| Collection Bulk Operations LxList with 1,000,000 items and bulk mutations | 1,000 random mutations on 1M list | **1ms** |
| Collection Bulk Operations LxMap with 100,000 unique keys | 100,000 map insertions | **55ms** |
| Collection Bulk Operations LxMap with 100,000 unique keys | 100,000 map clear | **0ms** |
| Collection Bulk Operations Collection change propagation to computed | Batch add 10,000 items + computed sum | **2ms** |
| Massive Fan-Out 100,000 observers on a single Lx source | Setup time for 100000 observers | **55ms** |
| Massive Fan-Out 100,000 observers on a single Lx source | Notification time for 100000 observers | **34ms** |
| Massive Fan-Out 100,000 observers on a single Lx source | Second notification time | **12ms** |
| Massive Fan-Out 100,000 observers on a single Lx source | Cleanup time | **18ms** |
| Rapid Mutation 1,000 rapid updates across 100 sources | Performed 1000 updates | **28ms** |
| Rapid Mutation Thundering Herd: many reactive nodes reacting to same sources | Thundering herd (100 batches, 1k nodes) | **0ms** |
| Memory Churn & Lifecycle Repeatedly create and dispose 10,000 reactive objects | Completed 10000 lifecycle iterations | **10000** |
| Memory Churn & Lifecycle Churn with cross-dependencies | Completed 5000 cross-dependency lifecycle iterations | **5000** |
| Async Race Conditions Rapidly changing source with 500 concurrent async computations | Captured 17 unique successful async results | **17** |

### 🟨 Levit DI (Dependency Injection)

| Scenario | Measured Action | Result |
| :--- | :--- | :--- |
| Deep Scoping Deeply Nested Scopes (1,000 levels) | Created 1000 nested scopes | **2ms** |
| Deep Scoping Deeply Nested Scopes (1,000 levels) | Resolved local | **2ms** |
| Deep Scoping Deep Traversal Resolution | Resolved root dependency through 1000 layers | **2ms** |
| DI Registration Massive Registration & Resolution (100,000 services) | Registered 100000 services | **61ms** |
| DI Registration Massive Registration & Resolution (100,000 services) | Resolved 100000 services | **29ms** |
| Concurrent Access Concurrent Async Resolution (10,000 futures) | Resolved 10000 concurrent requests | **325ms** |
| Memory Churn & Lifecycle Put/Delete Cycles (1,000,000 iterations) | Performed 1000000 put/delete cycles | **115ms** |

### 🟪 Levit Flutter (UI Binding)

| Scenario | Measured Action | Result |
| :--- | :--- | :--- |
| LWatch Fan-In One LWatch observing 2,000 sources | Initial build with 2000 dependencies | **31ms** |
| LWatch Fan-In One LWatch observing 2,000 sources | Update time for 2000 dependencies | **13ms** |
| LWatch Fan-In One LWatch observing 2,000 sources | Batch update (100) time | **13ms** |
| Deep Tree Scoping Resolve controller through 1,000 layers | Resolved deep scope through 1000 layers | **31ms** |
| LStatusBuilder State Switching | LStatusBuilder Setup: Built 2000 widgets (Idle) | **343ms** |
| LStatusBuilder State Switching | LStatusBuilder Switch: Switched 2000 widgets to Waiting | **24ms** |
| LStatusBuilder State Switching | LStatusBuilder Switch: Switched 2000 widgets to Success | **16ms** |
| LStatusBuilder State Switching | LStatusBuilder Switch: Switched 2000 widgets to Error | **12ms** |
| LView Churn Rapidly mount and unmount LViews | Performed 500 view churn cycles (100 views each) | **995ms** |
| LWatch Fan-Out 10,000 observers on a single Lx source | Setup time for 10000 LWatch widgets | **2347ms** |
| LWatch Fan-Out 10,000 observers on a single Lx source | Notification time for 10000 LWatch widgets | **651ms** |
| LWatch Fan-Out 10,000 observers on a single Lx source | Second notification time | **610ms** |

## 📜 Raw Execution Logs
<details>
<summary>Click to view full logs</summary>

```text
[lib/levit_flutter/massive_fan_in_stress_test.dart] [Stress Test: LWatch Fan-In One LWatch observing 2,000 sources] Initial build with 2000 dependencies: 31ms
[lib/levit_flutter/massive_fan_in_stress_test.dart] [Stress Test: LWatch Fan-In One LWatch observing 2,000 sources] Update time for 2000 dependencies: 13ms
[lib/levit_flutter/massive_fan_in_stress_test.dart] [Stress Test: LWatch Fan-In One LWatch observing 2,000 sources] Batch update (100) time: 13ms
[lib/levit_flutter/deep_tree_scope_stress_test.dart] [Stress Test: Deep Tree Scoping Resolve controller through 1,000 layers] Resolved deep scope through 1000 layers in 31ms
[lib/levit_flutter/status_builder_stress_test.dart] [Stress Test: LStatusBuilder State Switching] LStatusBuilder Setup: Built 2000 widgets (Idle) in 343ms
[lib/levit_flutter/status_builder_stress_test.dart] [Stress Test: LStatusBuilder State Switching] LStatusBuilder Switch: Switched 2000 widgets to Waiting in 24ms
[lib/levit_flutter/status_builder_stress_test.dart] [Stress Test: LStatusBuilder State Switching] LStatusBuilder Switch: Switched 2000 widgets to Success in 16ms
[lib/levit_flutter/status_builder_stress_test.dart] [Stress Test: LStatusBuilder State Switching] LStatusBuilder Switch: Switched 2000 widgets to Error in 12ms
[lib/levit_reactive/deep_chain_stress_test.dart] [Stress Test: Deep Dependency Chain 10,000 nodes deep chain propagates changes correctly] Deep Chain Setup: Created 10000 computed nodes in 79ms
[lib/levit_reactive/deep_chain_stress_test.dart] [Stress Test: Deep Dependency Chain 10,000 nodes deep chain propagates changes correctly] Deep Chain Propagation: Propagated change through 10000 nodes in 27ms
[lib/levit_reactive/collection_stress_test.dart] [Stress Test: Collection Bulk Operations LxList with 1,000,000 items and bulk mutations] Large list assign (1M items) took 20ms
[lib/levit_reactive/collection_stress_test.dart] [Stress Test: Collection Bulk Operations LxList with 1,000,000 items and bulk mutations] 1,000 random mutations on 1M list took 1ms
[lib/levit_reactive/collection_stress_test.dart] [Stress Test: Collection Bulk Operations LxMap with 100,000 unique keys] 100,000 map insertions took 55ms
[lib/levit_reactive/collection_stress_test.dart] [Stress Test: Collection Bulk Operations LxMap with 100,000 unique keys] 100,000 map clear took 0ms
[lib/levit_reactive/collection_stress_test.dart] [Stress Test: Collection Bulk Operations Collection change propagation to computed] Batch add 10,000 items + computed sum took 2ms
[lib/levit_flutter/view_churn_stress_test.dart] [Stress Test: LView Churn Rapidly mount and unmount LViews] Performed 500 view churn cycles (100 views each) in 995ms
[lib/levit_reactive/fan_out_stress_test.dart] [Stress Test: Massive Fan-Out 100,000 observers on a single Lx source] Setup time for 100000 observers: 55ms
[lib/levit_reactive/fan_out_stress_test.dart] [Stress Test: Massive Fan-Out 100,000 observers on a single Lx source] Notification time for 100000 observers: 34ms
[lib/levit_reactive/fan_out_stress_test.dart] [Stress Test: Massive Fan-Out 100,000 observers on a single Lx source] Second notification time: 12ms
[lib/levit_reactive/fan_out_stress_test.dart] [Stress Test: Massive Fan-Out 100,000 observers on a single Lx source] Cleanup time: 18ms
[lib/levit_reactive/rapid_mutation_stress_test.dart] [Stress Test: Rapid Mutation 1,000 rapid updates across 100 sources] Performed 1000 updates in 28ms
[lib/levit_reactive/rapid_mutation_stress_test.dart] [Stress Test: Rapid Mutation Thundering Herd: many reactive nodes reacting to same sources] Thundering herd (100 batches, 1k nodes) took 0ms
[lib/levit_reactive/memory_churn_stress_test.dart] [Stress Test: Memory Churn & Lifecycle Repeatedly create and dispose 10,000 reactive objects] Completed 10000 lifecycle iterations
[lib/levit_reactive/memory_churn_stress_test.dart] [Stress Test: Memory Churn & Lifecycle Churn with cross-dependencies] Completed 5000 cross-dependency lifecycle iterations
[lib/levit_di/deep_scope_stress_test.dart] [Stress Test: Deep Scoping Deeply Nested Scopes (1,000 levels)] Created 1000 nested scopes in 2ms
[lib/levit_di/deep_scope_stress_test.dart] [Stress Test: Deep Scoping Deeply Nested Scopes (1,000 levels)] Resolved local in deep scope in 2ms
[lib/levit_di/deep_scope_stress_test.dart] [Stress Test: Deep Scoping Deep Traversal Resolution] Resolved root dependency through 1000 layers in 2ms
[lib/levit_di/registration_stress_test.dart] [Stress Test: DI Registration Massive Registration & Resolution (100,000 services)] Registered 100000 services in 61ms
[lib/levit_di/registration_stress_test.dart] [Stress Test: DI Registration Massive Registration & Resolution (100,000 services)] Resolved 100000 services in 29ms
[lib/levit_di/concurrent_access_stress_test.dart] [Stress Test: Concurrent Access Concurrent Async Resolution (10,000 futures)] Resolved 10000 concurrent requests in 325ms
[lib/levit_flutter/massive_fan_out_stress_test.dart] [Stress Test: LWatch Fan-Out 10,000 observers on a single Lx source] Setup time for 10000 LWatch widgets: 2347ms
[lib/levit_di/churn_stress_test.dart] [Stress Test: Memory Churn & Lifecycle Put/Delete Cycles (1,000,000 iterations)] Performed 1000000 put/delete cycles in 115ms
[lib/levit_flutter/massive_fan_out_stress_test.dart] [Stress Test: LWatch Fan-Out 10,000 observers on a single Lx source] Notification time for 10000 LWatch widgets: 651ms
[lib/levit_reactive/async_race_stress_test.dart] [Stress Test: Async Race Conditions Rapidly changing source with 500 concurrent async computations] Captured 17 unique successful async results
[lib/levit_flutter/massive_fan_out_stress_test.dart] [Stress Test: LWatch Fan-Out 10,000 observers on a single Lx source] Second notification time: 610ms
```
</details>

## 📊 Benchmark Report

### Headless Benchmarks (macOS)
*Timestamp: 2026-01-07T12:51:57*

> **Summary**: 15 passed, 0 failed.

| Benchmark | Status | Key Metric | Additional Info |
| :--- | :--- | :--- | :--- |
| **Deep Scope Resolution** | ✅ PASSED | 0.701µs / resolve | Depth: 2000 |
| **Controller Churn** | ✅ PASSED | 47.78µs / controller | 5000 iterations |
| **Navigation Memory** | ✅ PASSED | 0.5ms / cycle | 200 cycles |
| **Nested Scope** | ✅ PASSED | 30ms total | 21,845 created/disposed |
| **Async Computed** | ✅ PASSED | 526ms total | 1001 computations, 1 success |
| **Batch Update** | ✅ PASSED | 8ms (vs 6ms) | Batching overhead: 2ms |
| **Collection Operations** | ✅ PASSED | 4.1x speedup | Bulk vs individual adds |
| **Computed Chain** | ✅ PASSED | 0.29µs / op | 2000 nodes deep |
| **Fan-out** | ✅ PASSED | 55ms total | 50,000 calls |
| **Mass Update** | ✅ PASSED | 69ms total | 100,000 updates |
| **Stream Lifecycle** | ✅ PASSED | 11.04µs / cycle | 20,000 cycles |
| **Worker Transforms** | ✅ PASSED | 99.9% reduction | Debounce |
| **Navigation Jank** | ✅ PASSED | 59.2 FPS | **20% Jank** (Headless artifact) |
| **Rebuild Isolation** | ✅ PASSED | Perfect | Exact updates received |
| **LStatusBuilder Switching** | ✅ PASSED | 0.5µs / widget | 2000 widgets |

### UI Benchmarks (macOS)
*Timestamp: 2026-01-07T12:52:38*

> **Summary**: 15 passed, 0 failed.

| Benchmark | Status | Key Metric | Additional Info |
| :--- | :--- | :--- | :--- |
| **Deep Scope Resolution** | ✅ PASSED | 0.500µs / resolve | Depth: 2000 |
| **Controller Churn** | ✅ PASSED | 51.24µs / controller | 5000 iterations |
| **Navigation Memory** | ✅ PASSED | 38.38ms / cycle | 200 cycles |
| **Nested Scope Churn** | ✅ PASSED | 24,865ms total | 21,845 items |
| **Async Computed** | ✅ PASSED | 551ms total | 1 success |
| **Batch Update** | ✅ PASSED | 20% improvement | Saved 2ms |
| **Collection Operations** | ✅ PASSED | 4.6x speedup | Bulk operations |
| **Computed Chain** | ✅ PASSED | 0.08µs / node | 2000 nodes |
| **Fan-out** | ✅ PASSED | 832ms total | 5000 expected rebuilds |
| **Mass Update** | ✅ PASSED | 2.2M upd/sec | 100,000 updates |
| **LxStream Lifecycle** | ✅ PASSED | 6.36µs / cycle | 5000 iterations |
| **Worker Transforms** | ✅ PASSED | 99.9% reduction | Debounce |
| **Navigation Jank** | ✅ PASSED | 60.2 FPS | **0% Jank** (Smooth) |
| **Rebuild Isolation** | ✅ PASSED | Isolated | Perfect isolation |
| **LStatusBuilder Switching** | ✅ PASSED | 0.0µs / widget | Instant |
