import 'package:flutter/widgets.dart';
import 'package:levit_flutter/levit_flutter.dart';

/// A mixin for [LevitController] that manages a [ScrollController] for pagination.
///
/// Features:
/// *   Automatically creates and disposes a [ScrollController].
/// *   Detects when the user scrolls near the bottom of the list.
/// *   Triggers [onLoadNextPage] when threshold is reached.
mixin LevitPagingScrollMixin on LevitController {
  late final ScrollController scrollController;

  /// The distance from the bottom in pixels to trigger [onLoadNextPage].
  double get scrollThreshold => 200.0;

  @override
  void onInit() {
    super.onInit();
    scrollController = ScrollController();
    scrollController.addListener(_onScroll);

    // Using autoDispose for cleanup (though onClose does it too, extra safety)
    autoDispose(scrollController);
  }

  void _onScroll() {
    if (!scrollController.hasClients) return;

    final maxScroll = scrollController.position.maxScrollExtent;
    final currentScroll = scrollController.position.pixels;

    if (maxScroll - currentScroll <= scrollThreshold) {
      onLoadNextPage();
    }
  }

  /// Called when the scroll position is within [scrollThreshold] of the bottom.
  /// Implement this to load more data.
  void onLoadNextPage();

  @override
  void onClose() {
    scrollController.removeListener(_onScroll);
    // dispose is handled by autoDispose if registered, or manually if needed.
    // Since autoDispose handles Dispose-able items (including ScrollController in Flutter context?),
    // actually LevitController base handles `dispose()` method.
    // ScrollController has `dispose()`.
    super.onClose();
  }
}
