import 'event.dart';

/// Interface for dispatching diagnostic events to external sinks.
///
/// [LevitTransport] defines how [MonitorEvent]s are delivered to developers,
/// logs, or visualization tools. Implementations can range from simple
/// console printing to complex network-based telemetry.
abstract class LevitTransport {
  /// Dispatches the [event] to the transport destination.
  ///
  /// This method is called by the monitor whenever an event passes through
  /// the active filtering pipeline.
  void send(MonitorEvent event);

  /// Releases resources and closes any active connections.
  ///
  /// This method should be called when the transport is no longer needed,
  /// typically during [LevitMonitor.detach].
  void close() {}
}
