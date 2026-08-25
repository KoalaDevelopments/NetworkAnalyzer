# Contract: Native messages (pigeon)

**Feature**: `001-real-time-monitoring` | **Date**: 2026-08-24

One new pigeon input per platform package — `pigeons/monitoring.dart` — per the
`CLAUDE.md` rule of one input file per feature. The existing
`pigeons/messages.dart` is untouched. **No channel code is written by hand and
no generated file is edited by hand** (Principle II; `CLAUDE.md` anti-patterns
1 and 2).

## Generation

```text
packages/network_analyzer_android/pigeons/monitoring.dart
  → lib/src/monitoring.g.dart
  → android/src/main/kotlin/com/koaladevelopments/network_analyzer_android/Monitoring.g.kt

packages/network_analyzer_ios/pigeons/monitoring.dart
  → lib/src/monitoring.g.dart
  → ios/network_analyzer_ios/Sources/network_analyzer_ios/Monitoring.g.swift
```

Both new inputs set `includeErrorClass: false` in their Kotlin and Swift
options, because `messages.dart` already emits the error class into the same
Kotlin package and Swift module; a second copy would not compile (research
R-003).

`tool/bootstrap.sh` currently hard-codes `--input pigeons/messages.dart`. It
changes to iterate `pigeons/*.dart` so every feature input regenerates.

## Shape

```dart
// --- enums ---------------------------------------------------------------
enum ProtocolMessage { tcp, udp, icmp }
enum KindMessage { internet, gateway }
enum InterfaceTypeMessage {
  ethernet, wifi, cellular5g, cellular4g, cellular3g, cellular2g,
  cellular, vpn, other, none, unknown,
}
enum OutcomeMessage { success, timeout, unreachable, error }

// --- session control (HostApi) -------------------------------------------
class MonitorConfigMessage {
  ProtocolMessage protocol;
  KindMessage kind;
  String? targetIPv4;        // null for gateway — discovered natively
  String? fallbackIPv4;
  String? targetName;
  int port;
  int probeIntervalMillis;
  int probeTimeoutMillis;
}

class SessionDataMessage {
  InterfaceTypeMessage interfaceType;
  ProtocolMessage protocol;
  KindMessage kind;
  String deviceIpAddress;
  String targetAddress;
  String targetName;
  int startedAtUtcMillis;
}

@HostApi()
abstract class MonitoringHostApi {
  SessionDataMessage startSession(MonitorConfigMessage config);
  void stopSession();
  SessionDataMessage? currentSession();
}

// --- signal stream (EventChannelApi) -------------------------------------
sealed class MonitorSignalMessage {}

class ProbeSampleMessage extends MonitorSignalMessage {
  int sequence;
  int? roundTripMicros;          // null unless outcome == success
  OutcomeMessage outcome;
  int elapsedMicros;             // monotonic, since session start
}

class NetworkStateMessage extends MonitorSignalMessage {
  InterfaceTypeMessage interfaceType;
  String? deviceIpAddress;
  String? targetAddress;
}

@EventChannelApi()
abstract class MonitoringEventApi {
  MonitorSignalMessage streamMonitorSignals();
}
```

## Why the shape is what it is

**Thresholds and window size are absent from `MonitorConfigMessage` on
purpose.** They are consumed exclusively by the Dart engine, so sending them
across the boundary would imply native code uses them — and would invite a
second, divergent implementation. Native receives only what native needs: what
to probe, how, how often, and how long to wait.

**`sealed class MonitorSignalMessage`** gives one channel carrying two signal
kinds. Pigeon requires every event-channel method to live in a single
`@EventChannelApi` and forbids parameters on those methods
(`pigeon_lib_internal.dart` lines 685 and 714), so configuration necessarily
travels via `startSession` instead. The Dart implementation subscribes to the
stream **before** calling `startSession`, so no sample is lost in the gap.

**Microseconds, not milliseconds**, for anything measured: the wire carries the
raw monotonic value at full useful precision and the Dart layer does the
documented rounding to 0.1 ms once (research R-013). Rounding on the native side
would round twice, differently, on two platforms.

**`startedAtUtcMillis` is the only wall clock on the wire.** Every elapsed value
is monotonic (`System.nanoTime` on Android, `clock_gettime(CLOCK_MONOTONIC_RAW)`
on iOS), which is what makes FR-024's "device clock changes cannot distort it"
true rather than aspirational.

**`currentSession()` returns a nullable message** rather than throwing; the Dart
side maps `null` to `NoActiveSessionFailure` (FR-017).

## Mapping

Generated message classes never leave the implementation package
(`CLAUDE.md` anti-pattern 7). Each platform package owns a
`lib/src/monitoring/monitor_mapper.dart` that converts message ⇄ domain model in
both directions. The mapper is pure Dart with no platform dependency, so it is
unit-tested directly.

## Native obligations behind the channel

| Kotlin / Swift | Requirement |
|----------------|-------------|
| `MonitorSessionController` | owns the probe timer and all mutable state, confined to one serial dispatcher (Android) / serial `DispatchQueue` (iOS) |
| `MonitorStreamHandler` | `onListen` attaches the sink; `onCancel` stops probing within 500 ms |
| `NetworkInspector` | interface type, device address, default gateway, and change notifications |
| `Prober` | one implementation per protocol; all take an explicit timeout; all time with a monotonic clock |

Android additionally declares `INTERNET` and `ACCESS_NETWORK_STATE` in the
plugin manifest — and deliberately **not** `READ_PHONE_STATE`, which would
otherwise be forced onto every host application merely to refine a cellular
generation label (research R-005). iOS requires no entitlement and no
`Info.plist` key.
