# 🚀 Levit Framework Stress Test Report

> **Generated on:** 2026-01-12

## 📊 Performance Summary

### 🟦 Levit Reactive (Core)

| Scenario | Description | Measured Action | Result |
| :--- | :--- | :--- | :--- |
| Collection Bulk Operations LxList with 1,000,000 items and bulk mutations | Measures performance of bulk assignments and rapid random mutations on very large reactive lists. | Large list assign (1M items) | **31ms** |
| Collection Bulk Operations LxList with 1,000,000 items and bulk mutations | Measures performance of bulk assignments and rapid random mutations on very large reactive lists. | 1,000 random mutations on 1M list | **1ms** |
| Deep Dependency Chain 10,000 nodes deep chain propagates changes correctly | Stresses the notification system by propagating a single change through a 10,000-node deep synchronous dependency chain. | Deep Chain Setup: Created 10000 computed nodes | **77ms** |
| Deep Dependency Chain 10,000 nodes deep chain propagates changes correctly | Stresses the notification system by propagating a single change through a 10,000-node deep synchronous dependency chain. | Deep Chain Propagation: Propagated change through 10000 nodes | **38ms** |
| Collection Bulk Operations LxMap with 100,000 unique keys | Benchmarks insertion and clearing speed for reactive maps with a large number of unique entries. | 100,000 map insertions | **66ms** |
| Collection Bulk Operations LxMap with 100,000 unique keys | Benchmarks insertion and clearing speed for reactive maps with a large number of unique entries. | 100,000 map clear | **78us** |
| Collection Bulk Operations Collection change propagation to computed | Validates that bulk mutations in reactive collections correctly and efficiently propagate to dependent computed values. | Batch add 10,000 items + computed sum | **6ms** |
| Error Recovery Flood System remains stable under flood of errors | Validates stability and recovery when thousands of synchronous errors are triggered simultaneously. | Error Flood: 5000 errors triggered | **24ms** |
| Error Recovery Flood System remains stable under flood of errors | Validates stability and recovery when thousands of synchronous errors are triggered simultaneously. | Recovery Flood: 5000 nodes recovered | **6ms** |
| Massive Fan-Out 100,000 observers on a single Lx source | Measures notification and cleanup overhead when 100,000 individual observers are attached to a single reactive source. | Setup time for 100000 observers | **64ms** |
| Massive Fan-Out 100,000 observers on a single Lx source | Measures notification and cleanup overhead when 100,000 individual observers are attached to a single reactive source. | Notification time for 100000 observers | **27ms** |
| Massive Fan-Out 100,000 observers on a single Lx source | Measures notification and cleanup overhead when 100,000 individual observers are attached to a single reactive source. | Second notification time | **25ms** |
| Massive Fan-Out 100,000 observers on a single Lx source | Measures notification and cleanup overhead when 100,000 individual observers are attached to a single reactive source. | Cleanup time | **19ms** |
| Rapid Mutation 1,000 rapid updates across 100 sources | Measures propagation speed of a massive volume of individual updates across many parallel sources. | Performed 1000 updates | **31ms** |
| Rapid Mutation Thundering Herd: many reactive nodes reacting to same sources | Tests the scalability of the notification system when a single update triggers thousands of dependent reactive nodes simultaneously. | Thundering herd (100 batches, 1k nodes) | **485us** |
| Memory Churn & Lifecycle Repeatedly create and dispose 10,000 reactive objects | Stresses the memory and lifecycle management by iteratively creating and specifically disposing 10,000 reactive nodes. | Completed 10000 lifecycle iterations | **10000** |
| Memory Churn & Lifecycle Churn with cross-dependencies | Tests lifecycle stability and memory cleanup when complex dependency subgraphs are rapidly created and disposed. | Completed 5000 cross-dependency lifecycle iterations | **5000** |
| Dynamic Graph Churn Subscription graph changes rapidly under load | Stresses subscriber management by rapidly reconfiguring the dependency graph under load. | Dynamic Graph Churn: 10000 iterations with 1000 nodes | **13260ms** |

### 🟨 Levit DI (Dependency Injection)

| Scenario | Description | Measured Action | Result |
| :--- | :--- | :--- | :--- |
| Deep Scoping Deeply Nested Scopes (1,000 levels) | Measures the manual setup cost and memory overhead of creating a massive scope hierarchy. | Created 1000 nested scopes | **5ms** |
| Deep Scoping Deeply Nested Scopes (1,000 levels) | Measures the manual setup cost and memory overhead of creating a massive scope hierarchy. | Resolved local | **2ms** |
| Deep Scoping Deep Traversal Resolution | Benchmarks the resolution speed when a dependency must be found by traversing multiple levels of parent scopes. | Resolved root dependency through 1000 layers | **2ms** |
| Concurrent Access Concurrent Async Resolution (10,000 futures) | Validates thread-safety and resolution consistency when thousands of concurrent async requests hit the same provider. | Resolved 10000 concurrent requests | **543ms** |
| DI Registration Massive Registration & Resolution (100,000 services) | Measures basic registration and resolution speed for a massive number of unique services in the root container. | Registered 100000 services | **82ms** |
| DI Registration Massive Registration & Resolution (100,000 services) | Measures basic registration and resolution speed for a massive number of unique services in the root container. | Resolved 100000 services | **63ms** |
| Provider Shadowing Resolution remains efficient with deep shadowing | Benchmarks resolution efficiency in deeply nested scopes with local overrides. | Deep Shadowing Setup: Created 1000 nested scopes | **4ms** |
| Provider Shadowing Resolution remains efficient with deep shadowing | Benchmarks resolution efficiency in deeply nested scopes with local overrides. | Deep Shadowing Resolution: Performed 10000 resolutions at depth 1000 | **4ms** |
| Memory Churn & Lifecycle Put/Delete Cycles (1,000,000 iterations) | Stresses the DI container and lifecycle hooks with continuous massive registration and deletion cycles. | Performed 1000000 put/delete cycles | **517ms** |
| Provider Shadowing Resolving root dependency through many layers of shadowing | Measures performance of root dependency lookups traversing many nested scope layers. | Root Resolution: Resolved through 1000 layers 10000 times | **4ms** |

### 🟪 Levit Flutter (UI Binding)

| Scenario | Description | Measured Action | Result |
| :--- | :--- | :--- | :--- |
| LWatch Fan-In One LWatch observing 2,000 sources | Tests a single LWatch widget dependent on 2,000 sources, measuring rebuild performance for both single and batch updates. | Initial build with 2000 dependencies | **26ms** |
| LWatch Fan-In One LWatch observing 2,000 sources | Tests a single LWatch widget dependent on 2,000 sources, measuring rebuild performance for both single and batch updates. | Update time for 2000 dependencies | **11ms** |
| LWatch Fan-In One LWatch observing 2,000 sources | Tests a single LWatch widget dependent on 2,000 sources, measuring rebuild performance for both single and batch updates. | Batch update (100) time | **4ms** |
| LStatusBuilder State Switching | Benchmarks the performance of 2,000 LStatusBuilder widgets switching through all possible async states. | LStatusBuilder Setup: Built 2000 widgets (Idle) | **371ms** |
| LStatusBuilder State Switching | Benchmarks the performance of 2,000 LStatusBuilder widgets switching through all possible async states. | LStatusBuilder Switch: Switched 2000 widgets to Waiting | **34ms** |
| LStatusBuilder State Switching | Benchmarks the performance of 2,000 LStatusBuilder widgets switching through all possible async states. | LStatusBuilder Switch: Switched 2000 widgets to Success | **16ms** |
| LStatusBuilder State Switching | Benchmarks the performance of 2,000 LStatusBuilder widgets switching through all possible async states. | LStatusBuilder Switch: Switched 2000 widgets to Error | **20ms** |
| LStatusBuilder Flood Switching 10,000 status builders in a single frame | Measures the UI overhead of switching 10,000 LStatusBuilder widgets between states simultaneously. | LStatusBuilder Flood (Success): 10,000 widgets switched | **34ms** |
| LStatusBuilder Flood Switching 10,000 status builders in a single frame | Measures the UI overhead of switching 10,000 LStatusBuilder widgets between states simultaneously. | LStatusBuilder Flood (Error): 10,000 widgets switched | **24ms** |
| Deep Tree Scoping Resolve controller through 1,000 layers | Measures the time to resolve a controller from a deep widget tree, testing LScope traversal efficiency. | Resolved deep scope through 1000 layers | **24ms** |
| LView Churn Rapidly mount and unmount LViews | Tests the lifecycle efficiency of LView and its controllers by rapidly mounting and unmounting 50,000 instances. | Performed 500 view churn cycles (100 views each) | **1766ms** |
| LWatch Fan-Out 10,000 observers on a single Lx source | Measures notification overhead when 10,000 LWatch widgets observe and react to a single shared source change. | Setup time for 10000 LWatch widgets | **4956ms** |
| LWatch Fan-Out 10,000 observers on a single Lx source | Measures notification overhead when 10,000 LWatch widgets observe and react to a single shared source change. | Notification time for 10000 LWatch widgets | **1351ms** |
| LWatch Fan-Out 10,000 observers on a single Lx source | Measures notification overhead when 10,000 LWatch widgets observe and react to a single shared source change. | Second notification time | **1239ms** |

## 📜 Raw Execution Logs
<details>
<summary>Click to view full logs</summary>

```text
[lib/levit_reactive/collection_stress_test.dart] [Stress Test: Collection Bulk Operations LxList with 1,000,000 items and bulk mutations] Large list assign (1M items) took 31ms
[lib/levit_reactive/collection_stress_test.dart] [Stress Test: Collection Bulk Operations LxList with 1,000,000 items and bulk mutations] 1,000 random mutations on 1M list took 1ms
[lib/levit_reactive/deep_chain_stress_test.dart] [Stress Test: Deep Dependency Chain 10,000 nodes deep chain propagates changes correctly] Deep Chain Setup: Created 10000 computed nodes in 77ms
[lib/levit_reactive/deep_chain_stress_test.dart] [Stress Test: Deep Dependency Chain 10,000 nodes deep chain propagates changes correctly] Deep Chain Propagation: Propagated change through 10000 nodes in 38ms
[lib/levit_reactive/collection_stress_test.dart] [Stress Test: Collection Bulk Operations LxMap with 100,000 unique keys] 100,000 map insertions took 66ms
[lib/levit_reactive/collection_stress_test.dart] [Stress Test: Collection Bulk Operations LxMap with 100,000 unique keys] 100,000 map clear took 78us
[lib/levit_reactive/collection_stress_test.dart] [Stress Test: Collection Bulk Operations Collection change propagation to computed] Batch add 10,000 items + computed sum took 6ms
[lib/levit_reactive/error_recovery_flood_stress_test.dart] [Stress Test: Error Recovery Flood System remains stable under flood of errors] Error Flood: 5000 errors triggered in 24ms
[lib/levit_reactive/error_recovery_flood_stress_test.dart] [Stress Test: Error Recovery Flood System remains stable under flood of errors] Recovery Flood: 5000 nodes recovered in 6ms
[lib/levit_reactive/fan_out_stress_test.dart] [Stress Test: Massive Fan-Out 100,000 observers on a single Lx source] Setup time for 100000 observers: 64ms
[lib/levit_reactive/fan_out_stress_test.dart] [Stress Test: Massive Fan-Out 100,000 observers on a single Lx source] Notification time for 100000 observers: 27ms
[lib/levit_reactive/fan_out_stress_test.dart] [Stress Test: Massive Fan-Out 100,000 observers on a single Lx source] Second notification time: 25ms
[lib/levit_reactive/fan_out_stress_test.dart] [Stress Test: Massive Fan-Out 100,000 observers on a single Lx source] Cleanup time: 19ms
[lib/levit_reactive/rapid_mutation_stress_test.dart] [Stress Test: Rapid Mutation 1,000 rapid updates across 100 sources] Performed 1000 updates in 31ms
[lib/levit_reactive/rapid_mutation_stress_test.dart] [Stress Test: Rapid Mutation Thundering Herd: many reactive nodes reacting to same sources] Thundering herd (100 batches, 1k nodes) took 485us
[lib/levit_reactive/memory_churn_stress_test.dart] [Stress Test: Memory Churn & Lifecycle Repeatedly create and dispose 10,000 reactive objects] Completed 10000 lifecycle iterations
[lib/levit_reactive/memory_churn_stress_test.dart] [Stress Test: Memory Churn & Lifecycle Churn with cross-dependencies] Completed 5000 cross-dependency lifecycle iterations
[lib/levit_di/deep_scope_stress_test.dart] [Stress Test: Deep Scoping Deeply Nested Scopes (1,000 levels)] Created 1000 nested scopes in 5ms
[lib/levit_di/deep_scope_stress_test.dart] [Stress Test: Deep Scoping Deeply Nested Scopes (1,000 levels)] Resolved local in deep scope in 2ms
[lib/levit_di/deep_scope_stress_test.dart] [Stress Test: Deep Scoping Deep Traversal Resolution] Resolved root dependency through 1000 layers in 2ms
[lib/levit_di/concurrent_access_stress_test.dart] [Stress Test: Concurrent Access Concurrent Async Resolution (10,000 futures)] Resolved 10000 concurrent requests in 543ms
[lib/levit_di/registration_stress_test.dart] [Stress Test: DI Registration Massive Registration & Resolution (100,000 services)] Registered 100000 services in 82ms
[lib/levit_di/registration_stress_test.dart] [Stress Test: DI Registration Massive Registration & Resolution (100,000 services)] Resolved 100000 services in 63ms
[lib/levit_di/provider_shadowing_stress_test.dart] [Stress Test: Provider Shadowing Resolution remains efficient with deep shadowing] Deep Shadowing Setup: Created 1000 nested scopes in 4ms
[lib/levit_di/provider_shadowing_stress_test.dart] [Stress Test: Provider Shadowing Resolution remains efficient with deep shadowing] Deep Shadowing Resolution: Performed 10000 resolutions at depth 1000 in 4ms
[lib/levit_di/churn_stress_test.dart] [Stress Test: Memory Churn & Lifecycle Put/Delete Cycles (1,000,000 iterations)] Performed 1000000 put/delete cycles in 517ms
[lib/levit_di/provider_shadowing_stress_test.dart] [Stress Test: Provider Shadowing Resolving root dependency through many layers of shadowing] Root Resolution: Resolved through 1000 layers 10000 times in 4ms
[lib/levit_flutter/massive_fan_in_stress_test.dart] [Stress Test: LWatch Fan-In One LWatch observing 2,000 sources] Initial build with 2000 dependencies: 26ms
[lib/levit_flutter/massive_fan_in_stress_test.dart] [Stress Test: LWatch Fan-In One LWatch observing 2,000 sources] Update time for 2000 dependencies: 11ms
[lib/levit_flutter/massive_fan_in_stress_test.dart] [Stress Test: LWatch Fan-In One LWatch observing 2,000 sources] Batch update (100) time: 4ms
[lib/levit_flutter/status_builder_stress_test.dart] [Stress Test: LStatusBuilder State Switching] LStatusBuilder Setup: Built 2000 widgets (Idle) in 371ms
[lib/levit_flutter/status_builder_stress_test.dart] [Stress Test: LStatusBuilder State Switching] LStatusBuilder Switch: Switched 2000 widgets to Waiting in 34ms
[lib/levit_flutter/status_builder_stress_test.dart] [Stress Test: LStatusBuilder State Switching] LStatusBuilder Switch: Switched 2000 widgets to Success in 16ms
[lib/levit_flutter/status_builder_stress_test.dart] [Stress Test: LStatusBuilder State Switching] LStatusBuilder Switch: Switched 2000 widgets to Error in 20ms
[lib/levit_flutter/status_builder_flood_stress_test.dart] [Stress Test: LStatusBuilder Flood Switching 10,000 status builders in a single frame] LStatusBuilder Flood (Success): 10,000 widgets switched in 34ms
[lib/levit_flutter/status_builder_flood_stress_test.dart] [Stress Test: LStatusBuilder Flood Switching 10,000 status builders in a single frame] LStatusBuilder Flood (Error): 10,000 widgets switched in 24ms
[lib/levit_flutter/deep_tree_scope_stress_test.dart] [Stress Test: Deep Tree Scoping Resolve controller through 1,000 layers] Resolved deep scope through 1000 layers in 24ms
[lib/levit_flutter/view_churn_stress_test.dart] [Stress Test: LView Churn Rapidly mount and unmount LViews] Performed 500 view churn cycles (100 views each) in 1766ms
[lib/levit_flutter/massive_fan_out_stress_test.dart] [Stress Test: LWatch Fan-Out 10,000 observers on a single Lx source] Setup time for 10000 LWatch widgets: 4956ms
[lib/levit_flutter/massive_fan_out_stress_test.dart] [Stress Test: LWatch Fan-Out 10,000 observers on a single Lx source] Notification time for 10000 LWatch widgets: 1351ms
[lib/levit_flutter/massive_fan_out_stress_test.dart] [Stress Test: LWatch Fan-Out 10,000 observers on a single Lx source] Second notification time: 1239ms
[lib/levit_reactive/dynamic_graph_churn_stress_test.dart] [Stress Test: Dynamic Graph Churn Subscription graph changes rapidly under load] Dynamic Graph Churn: 10000 iterations with 1000 nodes in 13260ms
```
</details>
