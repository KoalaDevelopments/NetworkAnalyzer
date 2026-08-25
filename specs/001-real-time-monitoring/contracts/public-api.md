# Contract: Public API (`network_analyzer`)

**Feature**: `001-real-time-monitoring` | **Date**: 2026-08-24

This is the only surface a host application touches. Types come from
`network_analyzer_platform_interface` and are re-exported here; the host never
depends on that package or on either implementation package.

## Entry point

```dart
class NetworkAnalyzer {
  NetworkAnalyzer({MonitoringController? controller});

  // --- discrete operations -------------------------------------------------
  Future<Result<SessionData, Failure>> startMonitoring(MonitorInterface target);
  Future<Result<void, Failure>>        stopMonitoring();
  Result<SessionData, Failure>         get currentSession;

  // --- continuous data -----------------------------------------------------
  Stream<ConnectionMetrics> get metrics;
  Stream<MonitorEvent>      get events;
  Stream<MonitorUpdate>     get updates;
}
```

The constructor is no longer `const` — the analyzer holds session state, and the
controller is injectable so tests run without a platform channel (research
R-014). `const NetworkAnalyzer()` call sites must drop `const`.

## Semantics

### `startMonitoring`

| Aspect | Contract |
|--------|----------|
| Requires | a fully constructed `MonitorInterface`; options and thresholds default if omitted |
| Returns | `SessionData` describing the live session (FR-012, FR-013) |
| Fails with | `SessionAlreadyRunningFailure`, `PermissionFailure`, `UnsupportedCapabilityFailure`, `GatewayDiscoveryFailure`, `InvalidConfigurationFailure`, `TargetUnreachableFailure` |
| Throws | never (FR-037) |
| Side effects | starts native probing; emits `monitoringStarted` on `events` before the first metrics emission |

A second call while a session is live is rejected and leaves the running session
untouched (FR-015). Switching between an internet and a gateway monitor means
`stopMonitoring()` then `startMonitoring()`.

### `stopMonitoring`

Completes all three streams, halts native probing within 500 ms (R-011), and
emits `monitoringStopped` before the streams close. Calling it with nothing
running succeeds as a no-op (FR-016) — the host never has to guard the call.

### `currentSession`

Synchronous, because the analyzer already holds the facts. Returns
`NoActiveSessionFailure` when nothing is running (FR-017) — never a fabricated
session.

### The three streams

| Getter | Emits | Cadence |
|--------|-------|---------|
| `metrics` | `ConnectionMetrics` | one per completed probe = the configured `probeInterval` (FR-019) |
| `events` | `MonitorEvent` | on transitions; level-triggered kinds throttled to one per 30 s (FR-033) |
| `updates` | `MonitorUpdate` | the union of both, in production order (FR-034) |

All three are broadcast views over one internal source. Subscribing to any
combination changes no emitted value and starts no second session (FR-036).
When the **last** subscriber across all three cancels, native probing stops
within 500 ms (FR-018); a session that has never been subscribed to keeps
running.

Streams never emit errors. A condition that would be an error becomes a
`MonitorEvent`, or a typed failure from a discrete operation.

## Usage

```dart
final analyzer = NetworkAnalyzer();

final result = await analyzer.startMonitoring(
  InternetInterface(
    protocol: MonitorProtocol.icmp,
    host: PresetHost.cloudflare,
  ),
);

result.fold(
  onFailure: (failure) => developer.log('start failed: ${failure.message}'),
  onSuccess: (success) {
    final SessionData session = success.value;
    developer.log('${session.interfaceType} via ${session.targetAddress}');
  },
);

final subscription = analyzer.metrics.listen((m) {
  developer.log('${m.latency} · ${m.packetLossPercent}% · ${m.health}');
});

// later
await subscription.cancel();   // last listener → probing stops
await analyzer.stopMonitoring();
```

Tuning is optional; supplying nothing gets the documented defaults (FR-009,
FR-010):

```dart
GatewayInterface(
  protocol: MonitorProtocol.tcp,
  options: const MonitorOptions(
    probeInterval: Duration(milliseconds: 500),
    sampleWindowSize: 20,
  ),
  thresholds: const HealthThresholds(stableLatency: Duration(milliseconds: 40)),
);
```

## Exports added to `network_analyzer.dart`

`ConnectionHealth`, `ConnectionMetrics`, `CustomHost`, `EventUpdate`,
`GatewayDiscoveryFailure`, `GatewayInterface`, `HealthThresholds`,
`InternetInterface`, `InvalidConfigurationFailure`, `MetricsUpdate`,
`MonitorEvent`, `MonitorEventKind`, `MonitorHost`, `MonitorInterface`,
`MonitorKind`, `MonitorOptions`, `MonitorProtocol`, `MonitorUpdate`,
`NetworkInterfaceType`, `NoActiveSessionFailure`, `PermissionFailure`,
`PresetHost`, `ProbeOutcome`, `ProbeSample`, `ProbeTimeoutFailure`,
`SessionData`, `TargetUnreachableFailure`, `UnsupportedCapabilityFailure`.
