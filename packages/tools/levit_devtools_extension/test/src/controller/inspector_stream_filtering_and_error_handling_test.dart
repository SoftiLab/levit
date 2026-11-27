import 'package:flutter_test/flutter_test.dart';
import 'package:levit_devtools_extension/src/client/devtools_client.dart';
import 'package:levit_devtools_extension/src/controller/inspector_controller.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:levit_monitor/spi.dart';

import '../../inspector_controller_test.dart';

void main() {
  setUpAll(Levit.enableAutoLinking);

  group('LevitRemoteSnapshotResult', () {
    test('unattached constructor exposes empty detached defaults', () {
      final result = LevitRemoteSnapshotResult.unattached();
      expect(result.attached, isFalse);
      expect(result.snapshot, isNull);
      expect(result.recentErrors, isEmpty);
      expect(result.droppedEvents, 0);
    });
  });

  group('LevitInspectorController lifecycle and filtering behavior', () {
    test(
      'handles connection changes, missing scope reconciliation, and refresh errors',
      () async {
        final client = FakeDevToolsClient(
          snapshotResult: const LevitRemoteSnapshotResult(
            attached: true,
            snapshot: {
              'scopes': [
                {
                  'id': 1,
                  'name': 'root',
                  'parentScopeId': null,
                  'progress': {}
                },
                {
                  'id': 2,
                  'name': 'feature',
                  'parentScopeId': 1,
                  'progress': {},
                },
              ],
              'dependencies': <Map<String, dynamic>>[],
              'variables': <Map<String, dynamic>>[],
              'taskTrees': <String, dynamic>{},
            },
          ),
        );

        final scope = Levit.createScope('test_devtools_connection');
        final controller = scope.put(() => LevitInspectorController(client));
        await Future<void>.delayed(Duration.zero);

        expect(controller.attached.value, isTrue);
        controller.selectedScopeId.value = 2;

        // Disconnection clears attached status.
        client.connectionStream.add(false);
        await Future<void>.delayed(Duration.zero);
        expect(controller.attached.value, isFalse);

        // Reconnection refreshes snapshot and reconciles a vanished selected scope.
        client.snapshotResult = const LevitRemoteSnapshotResult(
          attached: true,
          snapshot: {
            'scopes': [
              {'id': 3, 'name': 'next', 'parentScopeId': null, 'progress': {}},
            ],
            'dependencies': <Map<String, dynamic>>[],
            'variables': <Map<String, dynamic>>[],
            'taskTrees': <String, dynamic>{},
          },
        );
        client.connectionStream.add(true);
        await Future<void>.delayed(Duration.zero);

        expect(controller.attached.value, isTrue);
        expect(controller.selectedScopeId.value, 3);

        // Refreshing into an empty scope list clears the selected scope.
        client.snapshotResult = const LevitRemoteSnapshotResult(
          attached: true,
          snapshot: {
            'scopes': <Map<String, dynamic>>[],
            'dependencies': <Map<String, dynamic>>[],
            'variables': <Map<String, dynamic>>[],
            'taskTrees': <String, dynamic>{},
          },
        );
        await controller.refresh();
        expect(controller.selectedScopeId.value, isNull);

        // Transport failures record errorMessage and stop loading.
        client.fetchError = StateError('vm service disconnected');
        await controller.refresh();
        expect(
            controller.errorMessage.value, contains('vm service disconnected'));
        expect(controller.loading.value, isFalse);

        await scope.dispose();
      },
    );

    test(
      'auto-attaches on live events and enforces paused and error buffer bounds',
      () async {
        final client = FakeDevToolsClient(
          snapshotResult: LevitRemoteSnapshotResult.unattached(),
        );

        final scope = Levit.createScope('test_devtools_buffers');
        final controller = scope.put(() => LevitInspectorController(client));
        await Future<void>.delayed(Duration.zero);

        expect(controller.attached.value, isFalse);

        // Receiving a live event while unattached marks the inspector attached
        // and applies the event directly when unpaused.
        client.eventStream.add(
          LevitEventEnvelope.stateChange(
            sessionId: 's1',
            seq: 1,
            timestamp: '2026-11-26T00:00:01Z',
            reactiveId: '10',
            name: 'counter',
            ownerId: '1:CounterController',
            isSensitive: false,
            oldValue: '0',
            newValue: '1',
            valueType: 'int',
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(controller.attached.value, isTrue);
        expect(controller.snapshot.variables[10]?.value, '1');

        // Error ring buffer retains at most maxRecentErrors entries.
        for (var i = 0; i < LevitInspectorController.maxRecentErrors + 2; i++) {
          client.eventStream.add(
            LevitEventEnvelope({
              'sessionId': 's1',
              'seq': 10 + i,
              'timestamp': '2026-11-26T00:01:00Z',
              'type': 'reactive_error',
              'category': 'error',
              'reactiveId': '10',
              'name': 'counter',
              'ownerId': '1:CounterController',
              'error': 'boom-$i',
            }),
          );
        }
        await Future<void>.delayed(Duration.zero);

        expect(
          controller.recentErrors.length,
          LevitInspectorController.maxRecentErrors,
        );
        expect(controller.recentErrors.first['error'], 'boom-2');
        expect(controller.recentErrors.last['error'], 'boom-51');

        // Paused buffer retains at most maxTimelineEvents entries.
        controller.togglePause();
        for (var i = 0;
            i < LevitInspectorController.maxTimelineEvents + 3;
            i++) {
          client.eventStream.add(
            LevitEventEnvelope.stateChange(
              sessionId: 's1',
              seq: 100 + i,
              timestamp: '2026-11-26T00:02:00Z',
              reactiveId: '10',
              name: 'counter',
              ownerId: '1:CounterController',
              isSensitive: false,
              oldValue: '$i',
              newValue: '${i + 1}',
              valueType: 'int',
            ),
          );
        }
        await Future<void>.delayed(Duration.zero);

        expect(
          controller.pausedCount.value,
          LevitInspectorController.maxTimelineEvents,
        );

        controller.togglePause();
        expect(controller.pausedCount.value, 0);
        expect(
          controller.snapshot.variables[10]?.value,
          '${LevitInspectorController.maxTimelineEvents + 3}',
        );

        await scope.dispose();
      },
    );

    test(
      'supports focus navigation, reactive filters, and timeline search',
      () async {
        final client = FakeDevToolsClient(
          snapshotResult: const LevitRemoteSnapshotResult(
            attached: true,
            snapshot: {
              'scopes': [
                {
                  'id': 1,
                  'name': 'root',
                  'parentScopeId': null,
                  'progress': {}
                },
                {'id': 2, 'name': 'cart', 'parentScopeId': 1, 'progress': {}},
              ],
              'dependencies': <Map<String, dynamic>>[],
              'variables': [
                {
                  'id': 10,
                  'name': 'subtotal',
                  'ownerId': '2:CartController',
                  'isSensitive': false,
                  'value': '25',
                  'valueType': 'int',
                  'dependencies': <int>[],
                  'listenerCount': 2,
                },
                {
                  'id': 11,
                  'name': 'total',
                  'ownerId': '2:CartController',
                  'isSensitive': false,
                  'value': '30',
                  'valueType': 'double',
                  'dependencies': <int>[10],
                  'listenerCount': 60,
                },
                {
                  'id': 12,
                  'name': 'secretToken',
                  'ownerId': null,
                  'isSensitive': true,
                  'value': '***',
                  'valueType': 'String',
                  'dependencies': <int>[],
                  'listenerCount': 1,
                },
              ],
              'taskTrees': <String, dynamic>{},
            },
          ),
          history: [
            LevitEventEnvelope.stateChange(
              sessionId: 's1',
              seq: 1,
              timestamp: '2026-11-26T00:00:01Z',
              reactiveId: '10',
              name: 'subtotal',
              ownerId: '2:CartController',
              isSensitive: false,
              oldValue: '10',
              newValue: '25',
              valueType: 'int',
            ),
            LevitEventEnvelope({
              'sessionId': 's1',
              'seq': 2,
              'timestamp': '2026-11-26T00:00:02Z',
              'type': 'di_register',
              'category': 'di',
              'scopeId': 2,
              'scopeName': 'cart',
              'key': 'CartController',
              'isLazy': false,
              'isFactory': false,
              'isAsync': false,
            }),
            LevitEventEnvelope({
              'sessionId': 's1',
              'seq': 3,
              'timestamp': '2026-11-26T00:00:03Z',
              'type': 'reactive_error',
              'category': 'error',
              'reactiveId': '11',
              'name': 'total',
              'ownerId': '2:CartController',
              'error': 'overflow',
            }),
          ],
        );

        final scope = Levit.createScope('test_devtools_filters');
        final controller = scope.put(() => LevitInspectorController(client));
        await Future<void>.delayed(Duration.zero);

        controller.focusReactive(11);
        expect(controller.selectedReactiveId.value, 11);
        expect(controller.activeTabIndex.value, 1);

        controller.focusScope(2);
        expect(controller.selectedScopeId.value, 2);
        expect(controller.activeTabIndex.value, 0);

        controller.reactiveFilter.value = ReactiveFilterMode.unowned;
        expect(
          controller.filteredReactives.map((v) => v.name),
          ['secretToken'],
        );

        controller.reactiveFilter.value = ReactiveFilterMode.computed;
        expect(controller.filteredReactives.map((v) => v.name), ['total']);

        controller.reactiveFilter.value = ReactiveFilterMode.highListeners;
        expect(controller.filteredReactives.map((v) => v.name), ['total']);

        controller.reactiveFilter.value = ReactiveFilterMode.all;
        controller.reactiveSearch.value = 'double';
        expect(controller.filteredReactives.map((v) => v.name), ['total']);

        controller.reactiveSearch.value = '10';
        expect(controller.filteredReactives.map((v) => v.name), ['subtotal']);

        controller.reactiveSearch.value = 'controller';
        expect(
          controller.filteredReactives.map((v) => v.name),
          ['subtotal', 'total'],
        );

        controller.reactiveSearch.value = 'no-match';
        expect(controller.filteredReactives, isEmpty);

        controller.timelineCategory.value = 'di';
        expect(controller.filteredTimeline.map((e) => e.seq), [2]);

        controller.timelineCategory.value = null;
        controller.timelineSearch.value = 'overflow';
        expect(controller.filteredTimeline.map((e) => e.seq), [3]);

        controller.timelineSearch.value = 'controller';
        expect(controller.filteredTimeline.map((e) => e.seq), [3, 2, 1]);

        controller.timelineSearch.value = 'not-present';
        expect(controller.filteredTimeline, isEmpty);

        await scope.dispose();
      },
    );
  });
}
