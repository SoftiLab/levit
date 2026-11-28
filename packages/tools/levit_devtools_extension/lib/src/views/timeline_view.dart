import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:levit_flutter/levit_flutter.dart';
import 'package:levit_monitor/spi.dart';

import '../controller/inspector_controller.dart';

/// Live filterable timeline of redacted [LevitEventEnvelope]s.
class TimelineView extends LView<LevitInspectorController> {
  /// Creates the event timeline inspector view.
  const TimelineView({super.key}) : super(autoWatch: false);

  static const _categories = <String?>[
    null,
    'state',
    'di',
    'log',
    'custom',
    'error',
  ];

  @override
  Widget buildView(
    BuildContext context,
    LevitInspectorController controller,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 240,
                child: TextField(
                  controller: controller.timelineSearchController,
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.search, size: 16),
                    hintText: 'Search timeline events...',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => controller.timelineSearch.value = v,
                ),
              ),
              LWatch(() {
                final selected = controller.timelineCategory();
                return Wrap(
                  spacing: 6,
                  children: [
                    for (final category in _categories)
                      ChoiceChip(
                        label: Text(category ?? 'All'),
                        selected: selected == category,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) =>
                            controller.timelineCategory.value = category,
                      ),
                  ],
                );
              }),
              OutlinedButton.icon(
                onPressed: controller.clearLocalTimeline,
                icon: const Icon(Icons.delete_sweep_outlined, size: 16),
                label: const Text('Clear'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: LWatch(() {
            final events = controller.filteredTimeline;
            if (events.isEmpty) {
              return const Center(
                child: Text('No timeline events match the current filter.'),
              );
            }

            final selectedSeq = controller.selectedEventSeq();
            final selected =
                events.where((e) => e.seq == selectedSeq).firstOrNull ??
                    events.first;

            return Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ListView.separated(
                    itemCount: events.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final envelope = events[index];
                      return ListTile(
                        dense: true,
                        selected: envelope.seq == selected.seq,
                        title: Text(
                          '#${envelope.seq} • ${envelope.type}',
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          controller.summarizeEvent(envelope),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Chip(
                          label: Text(
                            envelope.category,
                            style: const TextStyle(fontSize: 10),
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        onTap: () =>
                            controller.selectedEventSeq.value = envelope.seq,
                      );
                    },
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(flex: 2, child: _EventDetailPane(envelope: selected)),
              ],
            );
          }),
        ),
      ],
    );
  }
}

class _EventDetailPane extends StatelessWidget {
  final LevitEventEnvelope envelope;

  const _EventDetailPane({required this.envelope});

  @override
  Widget build(BuildContext context) {
    const encoder = JsonEncoder.withIndent('  ');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Event #${envelope.seq} (${envelope.type})',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        SelectableText(
          encoder.convert(envelope.toJson()),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
      ],
    );
  }
}
