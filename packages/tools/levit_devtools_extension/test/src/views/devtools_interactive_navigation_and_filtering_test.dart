import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:levit_devtools_extension/src/client/devtools_client.dart';
import 'package:levit_devtools_extension/src/views/levit_devtools_screen.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:levit_monitor/spi.dart';

import '../../inspector_controller_test.dart';

FakeDevToolsClient _buildInteractiveClient() {
  return FakeDevToolsClient(
    snapshotResult: const LevitRemoteSnapshotResult(
      attached: true,
      snapshot: {
        'scopes': [
          {
            'id': 1,
            'name': 'root',
            'parentScopeId': null,
            'progress': {
              'isClosing': true,
              'pendingInitializations': 2,
              'registrations': [
                {
                  'key': 'AuthService',
                  'type': 'singleton',
                  'isInstantiated': true,
                  'aliasOf': 'BaseAuth',
                  'permanent': true,
                  'isFactory': false,
                },
                {
                  'key': 'TokenFactory',
                  'type': 'factory',
                  'isInstantiated': false,
                  'isFactory': true,
                },
              ],
            },
          },
          {
            'id': 2,
            'name': 'checkout',
            'parentScopeId': 1,
            'progress': <String, dynamic>{},
          },
        ],
        'dependencies': [
          {
            'scopeId': 2,
            'key': 'CartController',
            'isLazy': false,
            'isFactory': false,
            'isAsync': false,
            'status': 'active',
            'type': 'controller',
            'value': 'CartController',
          },
        ],
        'variables': [
          {
            'id': 10,
            'name': 'subtotal',
            'ownerId': '2:CartController',
            'isSensitive': false,
            'value': '99',
            'valueType': 'int',
            'dependencies': <int>[],
            'listenerCount': 15,
          },
          {
            'id': 11,
            'name': 'total',
            'ownerId': '2:CartController',
            'isSensitive': false,
            'value': '109',
            'valueType': 'int',
            'dependencies': <int>[10],
            'listenerCount': 1,
          },
          {
            'id': 12,
            'name': 'orphanFlag',
            'ownerId': null,
            'isSensitive': false,
            'value': 'true',
            'valueType': 'bool',
            'dependencies': <int>[],
            'listenerCount': 0,
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
        oldValue: '50',
        newValue: '99',
        valueType: 'int',
      ),
      LevitEventEnvelope({
        'sessionId': 's1',
        'seq': 2,
        'timestamp': '2026-11-26T00:00:02Z',
        'type': 'di_register',
        'category': 'di',
        'scopeId': 2,
        'scopeName': 'checkout',
        'key': 'CartController',
        'isLazy': false,
        'isFactory': false,
        'isAsync': false,
      }),
      LevitEventEnvelope({
        'sessionId': 's1',
        'seq': 3,
        'timestamp': '2026-11-26T00:00:03Z',
        'type': 'scope_create',
        'category': 'di',
        'scopeId': 2,
        'scopeName': 'checkout',
        'parentScopeId': 1,
      }),
      LevitEventEnvelope({
        'sessionId': 's1',
        'seq': 4,
        'timestamp': '2026-11-26T00:00:04Z',
        'type': 'reactive_error',
        'category': 'error',
        'reactiveId': '11',
        'name': 'total',
        'ownerId': '2:CartController',
        'error': 'divide by zero',
      }),
      LevitEventEnvelope({
        'sessionId': 's1',
        'seq': 5,
        'timestamp': '2026-11-26T00:00:05Z',
        'type': 'custom',
        'category': 'custom',
        'namespace': 'app',
        'name': 'checkout_started',
      }),
      LevitEventEnvelope({
        'sessionId': 's1',
        'seq': 6,
        'timestamp': '2026-11-26T00:00:06Z',
        'type': 'log',
        'category': 'log',
        'level': 'info',
        'data': 'heartbeat',
      }),
    ],
  );
}

void main() {
  group('LevitDevTools interactive workflows', () {
    testWidgets(
      'displays connection error and copies attach snippet when unattached',
      (tester) async {
        String? copiedText;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            final args = call.arguments as Map<dynamic, dynamic>;
            copiedText = args['text'] as String?;
          }
          return null;
        });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null);
        });

        final client = FakeDevToolsClient(
          snapshotResult: const LevitRemoteSnapshotResult.unattached(),
          fetchError: StateError('socket closed'),
        );
        addTearDown(client.dispose);

        await tester.pumpWidget(
          MaterialApp(home: LevitDevToolsScreen(client: client)),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Last error: Bad state: socket closed'),
          findsOneWidget,
        );

        await tester.tap(find.text('Copy Snippet'));
        await tester.pump();
        expect(copiedText, contains('await LevitDevTools.attach();'));
      },
    );

    testWidgets(
      'supports header actions, scope progress details, reactive graph jumps, '
      'timeline filters, and diagnostics threshold actions',
      (tester) async {
        String? copiedJson;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            final args = call.arguments as Map<dynamic, dynamic>;
            copiedJson = args['text'] as String?;
          }
          return null;
        });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null);
        });

        final client = _buildInteractiveClient();
        addTearDown(client.dispose);

        tester.view.physicalSize = const Size(1400, 1800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(home: LevitDevToolsScreen(client: client)),
        );
        await tester.pumpAndSettle();

        // Scope #1 displays closing/pending chips and progress registrations.
        expect(find.text('Closing'), findsOneWidget);
        expect(find.text('Pending Init: 2'), findsOneWidget);
        expect(find.text('AuthService (singleton)'), findsOneWidget);
        expect(find.text('TokenFactory (factory)'), findsOneWidget);

        // Header Pause -> queues incoming event -> Resume flushes.
        await tester.tap(find.text('Pause'));
        await tester.pumpAndSettle();
        expect(find.text('Resume'), findsOneWidget);

        client.eventStream.add(
          LevitEventEnvelope.stateChange(
            sessionId: 's1',
            seq: 7,
            timestamp: '2026-11-26T00:00:07Z',
            reactiveId: '10',
            name: 'subtotal',
            ownerId: '2:CartController',
            isSensitive: false,
            oldValue: '99',
            newValue: '105',
            valueType: 'int',
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Resume (+1)'), findsOneWidget);

        await tester.tap(find.text('Resume (+1)'));
        await tester.pumpAndSettle();
        expect(find.text('Pause'), findsOneWidget);

        // Header Copy JSON copies snapshot and shows SnackBar.
        await tester.tap(find.text('Copy JSON'));
        await tester.pumpAndSettle();
        expect(copiedJson, contains('CartController'));
        expect(find.text('Copied redacted snapshot JSON.'), findsOneWidget);

        // Select checkout scope and jump to owned reactive via ListTile tap.
        await tester.tap(find.text('checkout (#2)'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('subtotal'));
        await tester.pumpAndSettle();

        // Now on Reactives tab with subtotal selected: inspect downstream -> upstream -> scope.
        expect(find.text('subtotal (#10)'), findsOneWidget);
        expect(find.text('Downstream Dependents (1)'), findsOneWidget);

        // Tap downstream dependent 'total' in the detail pane.
        await tester.tap(find.text('total').last);
        await tester.pumpAndSettle();
        expect(find.text('total (#11)'), findsOneWidget);
        expect(find.text('Upstream Dependencies (1)'), findsOneWidget);

        // Tap upstream dependency 'subtotal' in the detail pane.
        await tester.tap(find.text('subtotal').last);
        await tester.pumpAndSettle();
        expect(find.text('subtotal (#10)'), findsOneWidget);

        // Exercise reactive list tap, ChoiceChip filter, and search TextField.
        await tester.tap(find.text('orphanFlag').first);
        await tester.pumpAndSettle();
        expect(find.text('orphanFlag (#12)'), findsOneWidget);

        await tester.tap(find.widgetWithText(ChoiceChip, 'Computed'));
        await tester.pumpAndSettle();
        expect(find.text('total (#11)'), findsOneWidget);

        await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField).first, 'subtotal');
        await tester.pumpAndSettle();
        expect(find.text('subtotal (#10)'), findsOneWidget);
        await tester.enterText(find.byType(TextField).first, '');
        await tester.pumpAndSettle();

        // Select subtotal and jump back to scope #2 from the reactive detail pane.
        await tester.tap(find.text('subtotal').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Inspect Scope #2'));
        await tester.pumpAndSettle();
        expect(find.text('checkout (scope #2)'), findsOneWidget);

        // Switch to Timeline tab and verify all summary shapes, selection, search, and category chips.
        await tester.tap(find.textContaining('Timeline ('));
        await tester.pumpAndSettle();
        expect(find.text('scope: checkout • CartController'), findsOneWidget);
        expect(find.text('scope: checkout'), findsOneWidget);
        expect(find.text('error: divide by zero'), findsOneWidget);
        expect(find.text('checkout_started'), findsOneWidget);
        expect(find.text('2026-11-26T00:00:06Z'), findsOneWidget);

        await tester.tap(find.text('#2 • di_register'));
        await tester.pumpAndSettle();
        expect(find.text('Event #2 (di_register)'), findsOneWidget);

        await tester.enterText(
            find.byType(TextField).first, 'checkout_started');
        await tester.pumpAndSettle();
        expect(find.text('#5 • custom'), findsOneWidget);
        await tester.enterText(find.byType(TextField).first, '');
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(ChoiceChip, 'di'));
        await tester.pumpAndSettle();
        expect(find.text('#2 • di_register'), findsOneWidget);
        await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
        await tester.pumpAndSettle();

        // Jump to Diagnostics tab via the header findings ActionChip.
        await tester.tap(find.textContaining('finding(s)'));
        await tester.pumpAndSettle();
        expect(find.text('unowned_reactives'), findsOneWidget);
        expect(find.text('closing_scopes'), findsOneWidget);
        expect(find.text('pending_initializations'), findsOneWidget);

        // Lower high listener threshold to 10 so subtotal (15 listeners) triggers high_listener_count.
        await tester.tap(find.text('50 (default)'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('10').last);
        await tester.pumpAndSettle();
        expect(find.text('high_listener_count'), findsOneWidget);

        // Exercise each finding action button.
        await tester.tap(find.text('Show Unowned'));
        await tester.pumpAndSettle();
        expect(find.text('orphanFlag (#12)'), findsOneWidget);

        await tester.tap(find.textContaining('finding(s)'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Show High Listeners'));
        await tester.pumpAndSettle();
        expect(find.text('subtotal (#10)'), findsOneWidget);

        await tester.tap(find.textContaining('finding(s)'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Open Scopes').first);
        await tester.pumpAndSettle();
        expect(find.text('checkout (scope #2)'), findsOneWidget);

        // Verify direct tab-bar navigation back to Scopes tab.
        await tester.tap(find.textContaining('Tasks ('));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Scopes ('));
        await tester.pumpAndSettle();
        expect(find.text('checkout (scope #2)'), findsOneWidget);
      },
    );

    testWidgets(
      'resolves client from enclosing LScope and disposes it when unmounted',
      (tester) async {
        late FakeDevToolsClient scopedClient;
        var factoryCalls = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: LScope.put<LevitDevToolsClient>(
              () {
                factoryCalls++;
                scopedClient = FakeDevToolsClient(
                  snapshotResult: const LevitRemoteSnapshotResult.unattached(),
                );
                return scopedClient;
              },
              child: const LevitDevToolsScreen(ownsClient: true),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(factoryCalls, 1);
        expect(scopedClient.disposed, isFalse);

        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
        await tester.pumpAndSettle();

        expect(scopedClient.disposed, isTrue);
      },
    );
  });
}
