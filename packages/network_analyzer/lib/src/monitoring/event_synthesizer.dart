import 'package:network_analyzer_platform_interface/network_analyzer_platform_interface.dart';

/// Turns state changes into events, and keeps a persistent condition from
/// flooding the stream.
///
/// Two classes of event, handled differently on purpose. Edge-triggered
/// kinds describe a transition and are always emitted — suppressing one
/// would erase the only record that something changed. Level-triggered kinds
/// describe an ongoing condition and are throttled per kind, because a
/// connection that has been lossy for an hour does not need 3,600 identical
/// events. The spike *count* in every measurement stays exact regardless of
/// how many spike events were suppressed.
final class EventSynthesizer {
  /// Creates a synthesizer that throttles level-triggered kinds to one per
  /// [cooldown].
  EventSynthesizer({
    required this.thresholds,
    this.cooldown = defaultCooldown,
  });

  /// How long a level-triggered kind waits before it may repeat.
  static const Duration defaultCooldown = Duration(seconds: 30);

  /// The cutoffs that decide when a condition is worth reporting.
  final HealthThresholds thresholds;

  /// The per-kind throttle interval.
  final Duration cooldown;

  final Map<MonitorEventKind, Duration> _lastEmitted =
      <MonitorEventKind, Duration>{};

  ConnectionHealth? _lastHealth;
  NetworkInterfaceType? _lastInterface;
  String? _lastDeviceAddress;
  String? _lastTargetAddress;

  /// The event announcing that a session started.
  MonitorEvent started(SessionData session) => _event(
    session,
    MonitorEventKind.monitoringStarted,
    'Monitoring started on ${session.interfaceType.name} via '
    '${session.protocol.name} to ${session.targetAddress}.',
  );

  /// The event announcing that a session ended.
  MonitorEvent stopped(SessionData session) => _event(
    session,
    MonitorEventKind.monitoringStopped,
    'Monitoring stopped after ${session.targetName} session.',
  );

  /// Events implied by [metrics], in emission order.
  ///
  /// [wasSpike] comes from the engine, which already decided whether the
  /// sample behind these metrics spiked.
  List<MonitorEvent> fromMetrics(
    ConnectionMetrics metrics, {
    required bool wasSpike,
  }) {
    final List<MonitorEvent> events = <MonitorEvent>[];
    final SessionData session = metrics.session;

    final ConnectionHealth? previous = _lastHealth;
    if (previous != null && previous != metrics.health) {
      events.add(
        _event(
          session,
          MonitorEventKind.healthChanged,
          'Connection health changed from ${previous.name} to '
          '${metrics.health.name}.',
        ),
      );
    }
    _lastHealth = metrics.health;

    if (metrics.packetLossPercent > thresholds.stablePacketLossPercent) {
      _addThrottled(
        events,
        session,
        MonitorEventKind.packetLossDetected,
        'Packet loss is ${metrics.packetLossPercent}%.',
        metrics.uptime,
      );
    }

    final Duration? jitter = metrics.jitter;
    if (jitter != null && jitter > thresholds.stableJitter) {
      _addThrottled(
        events,
        session,
        MonitorEventKind.highJitterDetected,
        'Jitter is ${jitter.inMilliseconds} ms.',
        metrics.uptime,
      );
    }

    if (wasSpike) {
      _addThrottled(
        events,
        session,
        MonitorEventKind.latencySpikeDetected,
        'Latency spiked to ${metrics.latency?.inMilliseconds} ms.',
        metrics.uptime,
      );
    }
    return events;
  }

  /// Events implied by [change], in emission order.
  ///
  /// The session stays alive across a total loss of connectivity, so it can
  /// report the recovery rather than leaving the host wondering.
  List<MonitorEvent> fromNetworkChange(
    NetworkStateChange change,
    SessionData session,
  ) {
    final List<MonitorEvent> events = <MonitorEvent>[];
    final NetworkInterfaceType? previous = _lastInterface;

    if (previous != null && previous != change.interfaceType) {
      if (change.interfaceType == NetworkInterfaceType.none) {
        events.add(
          _event(
            session,
            MonitorEventKind.connectivityLost,
            'The device lost connectivity. The session stays open.',
          ),
        );
      } else if (previous == NetworkInterfaceType.none) {
        events.add(
          _event(
            session,
            MonitorEventKind.connectivityRestored,
            'Connectivity returned on ${change.interfaceType.name}.',
          ),
        );
      } else {
        events.add(
          _event(
            session,
            MonitorEventKind.interfaceChanged,
            'Interface changed from ${previous.name} to '
            '${change.interfaceType.name}.',
          ),
        );
      }
    }
    _lastInterface = change.interfaceType;

    final String? device = change.deviceIpAddress;
    if (device != null &&
        _lastDeviceAddress != null &&
        device != _lastDeviceAddress) {
      events.add(
        _event(
          session,
          MonitorEventKind.ipAddressChanged,
          'Device address changed from $_lastDeviceAddress to $device.',
        ),
      );
    }
    if (device != null) {
      _lastDeviceAddress = device;
    }

    final String? target = change.targetAddress;
    if (target != null &&
        _lastTargetAddress != null &&
        target != _lastTargetAddress) {
      events.add(
        _event(
          session,
          MonitorEventKind.targetAddressChanged,
          'Probing switched to $target after repeated failures.',
        ),
      );
    }
    if (target != null) {
      _lastTargetAddress = target;
    }
    return events;
  }

  /// Seeds the baselines so the first signals do not read as changes.
  void seed(SessionData session) {
    _lastInterface = session.interfaceType;
    _lastDeviceAddress = session.deviceIpAddress;
    _lastTargetAddress = session.targetAddress;
  }

  void _addThrottled(
    List<MonitorEvent> events,
    SessionData session,
    MonitorEventKind kind,
    String message,
    Duration uptime,
  ) {
    final Duration? last = _lastEmitted[kind];
    if (last != null && uptime - last < cooldown) {
      return;
    }
    _lastEmitted[kind] = uptime;
    events.add(_event(session, kind, message));
  }

  MonitorEvent _event(
    SessionData session,
    MonitorEventKind kind,
    String message,
  ) => MonitorEvent(
    session: session,
    timestamp: DateTime.now().toUtc(),
    kind: kind,
    message: message,
  );
}
