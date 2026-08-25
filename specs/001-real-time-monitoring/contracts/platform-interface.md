# Contract: `NetworkAnalyzerPlatform` additions

**Feature**: `001-real-time-monitoring` | **Date**: 2026-08-24

Four **add-only** members join the existing abstract class. Existing members are
untouched, so neither platform package breaks and Principle II's add-only rule
holds. Each new member keeps the established default body — throw
`UnimplementedError` — so a platform that has not yet implemented it fails
loudly in development rather than silently at runtime.

```dart
abstract class NetworkAnalyzerPlatform extends PlatformInterface {
  // ... existing getBridgeInfo() ...

  /// Starts a monitoring session against [target].
  Future<Result<SessionData, Failure>> startMonitoring(
    MonitorInterface target,
  ) => throw UnimplementedError('startMonitoring() has not been implemented.');

  /// Stops the running session, halting native probing within 500 ms.
  Future<Result<void, Failure>> stopMonitoring() =>
      throw UnimplementedError('stopMonitoring() has not been implemented.');

  /// The facts about the running session, or [NoActiveSessionFailure].
  Future<Result<SessionData, Failure>> currentSession() =>
      throw UnimplementedError('currentSession() has not been implemented.');

  /// Raw probe samples and network-state changes from the native side.
  ///
  /// The last cancellation stops native probing. Consumers derive metrics
  /// from this; host applications never see it.
  Stream<MonitorSignal> monitorSignals() =>
      throw UnimplementedError('monitorSignals() has not been implemented.');
}
```

## Obligations on an implementation

| # | Obligation | Traces to |
|---|-----------|-----------|
| 1 | Never let an exception escape. Catch `PlatformException` and map it to a typed `Failure`. | Principle III, FR-037 |
| 2 | Validate the incoming `MonitorInterface` again on the platform side and return `InvalidConfigurationFailure` rather than trusting the caller. | FR-006, FR-011 |
| 3 | Reject a protocol the platform cannot honour with `UnsupportedCapabilityFailure`. Never substitute another protocol. | FR-039, Security section |
| 4 | Discover the gateway when `target` is a `GatewayInterface`; return `GatewayDiscoveryFailure` when there is no default route. | FR-007 |
| 5 | Measure round-trip time with a monotonic clock. Never a wall clock. | Principle VI, FR-024 |
| 6 | Run all probing off the platform's main thread, on one serial dispatcher/queue. | Principle VI |
| 7 | Emit one `ProbeSample` per completed probe, with a monotonically increasing sequence starting at 0. A probe that times out is a sample with `outcome: timeout` and a null `roundTrip` — never a dropped emission. | FR-019, FR-024 |
| 8 | Emit a `NetworkStateChange` whenever interface type or device address changes. | FR-014, US6 |
| 9 | Stop probing within 500 ms of `stopMonitoring()` **or** of the signal stream being cancelled, and leave nothing running. | Principle V, FR-016, FR-018 |
| 10 | Report the actual reached address in `SessionData.targetAddress`, including after a primary→secondary fallback. | FR-013, R-010 |
| 11 | Persist nothing, and collect no PII or device identifier. | FR-041 |
| 12 | Declare only the permissions the feature needs, and degrade honestly when an optional one is absent. | Security section, FR-014 |

## Semantic parity

Both platforms must produce identical results for identical conditions, within
the documented tolerance (SC-010). Parity is achieved structurally rather than
by discipline: the only values native code decides are the raw round-trip time,
the interface type, the device address and the gateway address. Every derived
value — loss, jitter, spikes, health, aggregates, events — is computed once in
Dart, so it cannot diverge between platforms (research R-001).

## Testing the contract

Implementations are verified against a `FakeNetworkAnalyzerPlatform` that
replays a fixed `MonitorSignal` sequence. Because the fake drives the same
engine the real platforms drive, engine tests and contract tests share fixtures
and no test requires a live network (Principle IV).
