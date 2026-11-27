import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:levit_flutter/levit_flutter.dart';

import '../client/devtools_client.dart';
import '../controller/inspector_controller.dart';
import 'diagnostics_view.dart';
import 'reactive_graph_view.dart';
import 'scope_tree_view.dart';
import 'task_tree_view.dart';
import 'timeline_view.dart';

/// Main Flutter DevTools screen for inspecting a live Levit application.
///
/// Owns a dedicated [LScope] hosting [LevitInspectorController], allowing all
/// child views to resolve the controller via [LView] and `context.levit.find`.
class LevitDevToolsScreen extends LScopedView<LevitInspectorController> {
  /// Optional pre-constructed transport client.
  final LevitDevToolsClient? client;

  /// Optional lazy transport client factory invoked once when configuring the scope.
  final LevitDevToolsClient Function()? createClient;

  /// Whether [LevitInspectorController] should dispose the client when closed.
  final bool ownsClient;

  /// Creates the Levit DevTools inspector screen.
  const LevitDevToolsScreen({
    super.key,
    this.client,
    this.createClient,
    this.ownsClient = false,
  })  : assert(client != null || createClient != null),
        super(autoWatch: false, scopeName: 'levit_devtools');

  @override
  void onConfigureScope(LevitScope scope) {
    final resolvedClient = client ?? createClient!();
    scope.put(
      () => LevitInspectorController(resolvedClient, ownsClient: ownsClient),
    );
  }

  @override
  Widget buildView(
    BuildContext context,
    LevitInspectorController controller,
  ) {
    return Scaffold(
      body: Column(
        children: [
          const _HeaderToolbar(),
          const Divider(height: 1),
          Expanded(
            child: LWatch(() {
              if (!controller.attached()) {
                return const _UnattachedEmptyState();
              }
              return const Column(
                children: [
                  _InspectorTabBar(),
                  Divider(height: 1),
                  Expanded(child: _ActiveInspectorTab()),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _InspectorTabBar extends LView<LevitInspectorController> {
  const _InspectorTabBar();

  @override
  Widget buildView(
    BuildContext context,
    LevitInspectorController controller,
  ) {
    controller.revision();
    final activeIndex = controller.activeTabIndex();
    final findings = controller.findings;

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Align(
        alignment: Alignment.centerLeft,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _InspectorTabButton(
                label: 'Scopes (${controller.snapshot.scopes.length})',
                selected: activeIndex == 0,
                onTap: () => controller.selectTab(0),
              ),
              _InspectorTabButton(
                label: 'Reactives (${controller.snapshot.variables.length})',
                selected: activeIndex == 1,
                onTap: () => controller.selectTab(1),
              ),
              _InspectorTabButton(
                label: 'Tasks (${controller.snapshot.taskTrees.length})',
                selected: activeIndex == 2,
                onTap: () => controller.selectTab(2),
              ),
              _InspectorTabButton(
                label: 'Timeline (${controller.snapshot.events.length})',
                selected: activeIndex == 3,
                onTap: () => controller.selectTab(3),
              ),
              _InspectorTabButton(
                label: 'Diagnostics',
                selected: activeIndex == 4,
                onTap: () => controller.selectTab(4),
                trailing: findings.isEmpty
                    ? null
                    : _CountBadge(
                        count: findings.length,
                        hasError: controller.hasErrorFindings,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InspectorTabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? trailing;

  const _InspectorTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground =
        selected ? colorScheme.primary : colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? colorScheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 6),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

class _ActiveInspectorTab extends LView<LevitInspectorController> {
  const _ActiveInspectorTab();

  @override
  Widget buildView(
    BuildContext context,
    LevitInspectorController controller,
  ) {
    return switch (controller.activeTabIndex()) {
      0 => const ScopeTreeView(),
      1 => const ReactiveGraphView(),
      2 => const TaskTreeView(),
      3 => const TimelineView(),
      _ => const DiagnosticsView(),
    };
  }
}

class _HeaderToolbar extends LView<LevitInspectorController> {
  const _HeaderToolbar() : super(autoWatch: false);

  @override
  Widget buildView(
    BuildContext context,
    LevitInspectorController controller,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.hub_outlined,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'Levit Inspector',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          LWatch(() {
            final isAttached = controller.attached();
            return Chip(
              avatar: Icon(
                isAttached ? Icons.check_circle : Icons.link_off,
                size: 16,
                color: isAttached ? Colors.green : Colors.orange,
              ),
              label: Text(
                isAttached ? 'Connected (Read-Only)' : 'Not Attached',
              ),
              visualDensity: VisualDensity.compact,
            );
          }),
          LWatch(() {
            if (!controller.attached()) {
              return const SizedBox.shrink();
            }
            final isPaused = controller.paused();
            final queued = controller.pausedCount();
            final findings = controller.findings;

            return Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: controller.togglePause,
                  icon: Icon(
                    isPaused ? Icons.play_arrow : Icons.pause,
                    size: 16,
                  ),
                  label: Text(
                    isPaused
                        ? 'Resume${queued > 0 ? ' (+$queued)' : ''}'
                        : 'Pause',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: controller.loading() ? null : controller.refresh,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh'),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final json = controller.exportRedactedJson();
                    await Clipboard.setData(ClipboardData(text: json));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Copied redacted snapshot JSON.'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.copy_all, size: 16),
                  label: const Text('Copy JSON'),
                ),
                if (findings.isNotEmpty)
                  ActionChip(
                    avatar: Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: controller.hasErrorFindings
                          ? Colors.red
                          : Colors.amber.shade700,
                    ),
                    label: Text('${findings.length} finding(s)'),
                    onPressed: controller.openDiagnosticsTab,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  final bool hasError;

  const _CountBadge({required this.count, required this.hasError});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: hasError ? Colors.red.shade700 : Colors.amber.shade800,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _UnattachedEmptyState extends LView<LevitInspectorController> {
  const _UnattachedEmptyState() : super(autoWatch: false);

  static const _snippet =
      '''import 'package:levit_devtools/levit_devtools.dart';

Future<void> main() async {
  Levit.enableAutoLinking();
  await LevitDevTools.attach();
  runApp(const MyApp());
}''';

  @override
  Widget buildView(
    BuildContext context,
    LevitInspectorController controller,
  ) {
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'LevitDevTools is not attached in the running app',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Attach LevitDevTools in main() before runApp() to stream '
                    'redacted scopes, reactives, tasks, timeline events, and '
                    'diagnostics over the Dart VM Service.',
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const SelectableText(
                      _snippet,
                      style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                  LWatch(() {
                    final error = controller.errorMessage();
                    if (error == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'Last error: $error',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      LWatch(() {
                        final loading = controller.loading();
                        return FilledButton.icon(
                          onPressed: loading ? null : controller.refresh,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: Text(
                            loading ? 'Checking...' : 'Retry Connection',
                          ),
                        );
                      }),
                      OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                            const ClipboardData(text: _snippet),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy Snippet'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
