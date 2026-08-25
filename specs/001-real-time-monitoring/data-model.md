# Phase 1 Data Model: Real-time Monitoring

**Feature**: `001-real-time-monitoring` | **Date**: 2026-08-24

All types below are immutable (`@immutable`, `final` fields), define `==` and
`hashCode`, and live in `network_analyzer_platform_interface` unless noted.
`network_analyzer` re-exports every public one. Pigeon message classes are
transport DTOs and are **not** listed here — they never leave the platform
implementation packages (`CLAUDE.md` anti-pattern 7).

Traceability to the spec is given per entity.

---

## 1. Configuration — built by the host application

### `MonitorProtocol` — enum *(FR-002, FR-003)*

| Value | Internet | Gateway |
|-------|----------|---------|
| `tcp` | ✅ | ✅ |
| `udp` | ✅ | ❌ rejected |
| `icmp` | ✅ | ✅ |

### `MonitorHost` — sealed *(FR-004, FR-005)*

```
sealed class MonitorHost
  String  hostName
  String  primaryIPv4
  String? secondaryIPv4
  String? ipv6
  int     port          // default 53
```

- **`PresetHost`** — an `enum` implementing `MonitorHost`:

  | Value | `hostName` | `primaryIPv4` | `secondaryIPv4` |
  |-------|-----------|---------------|-----------------|
  | `google` | Google Public DNS | `8.8.8.8` | `8.8.4.4` |
  | `cloudflare` | Cloudflare DNS | `1.1.1.1` | `1.0.0.1` |
  | `openDns` | OpenDNS | `208.67.222.222` | `208.67.220.220` |

- **`CustomHost`** — `hostName`, required `primaryIPv4`, optional `ipv6`,
  optional `port`. `secondaryIPv4` is always `null`.

**Validation** *(FR-006)*: `hostName` non-empty after trimming;
`primaryIPv4` parses as a dotted-quad IPv4; `ipv6` when present parses as IPv6;
`port` in 1…65535. Violations throw `ArgumentError` from the constructor —
this is a programming error in host code, not a runtime failure, so it is the
one place an exception is correct. Anything reaching the *platform* is validated
again and reported as `InvalidConfigurationFailure`.

An `enum` is used for the presets rather than three constants so that host code
gets an exhaustive `switch` and a `PresetHost.values` list for building a
picker, while `sealed MonitorHost` still allows `CustomHost`.

### `MonitorInterface` — sealed *(FR-001, FR-002, FR-003, FR-008)*

```
sealed class MonitorInterface
  MonitorProtocol   protocol
  MonitorOptions    options        // default: MonitorOptions()
  HealthThresholds  thresholds     // default: HealthThresholds()
  MonitorKind       kind           // derived, not a constructor argument

final class InternetInterface extends MonitorInterface
  MonitorHost host                 // required

final class GatewayInterface extends MonitorInterface
  // no host — discovered at start (FR-007)
```

**Validation** *(FR-003, FR-006)*: `GatewayInterface` rejects
`MonitorProtocol.udp` in its constructor. Immutable once constructed (FR-008);
changing what is monitored means a new instance and a new session.

### `MonitorOptions` *(FR-009, FR-011)*

| Field | Type | Default | Bounds |
|-------|------|---------|--------|
| `probeInterval` | `Duration` | 1 s | 200 ms … 60 s |
| `probeTimeout` | `Duration` | 1 s | 100 ms … `probeInterval` |
| `sampleWindowSize` | `int` | 10 | 1 … 300 |

### `HealthThresholds` *(FR-010, FR-011, FR-023)*

| Field | Type | Default |
|-------|------|---------|
| `stableLatency` | `Duration` | 100 ms |
| `unstableLatency` | `Duration` | 250 ms |
| `stablePacketLossPercent` | `double` | 1.0 |
| `unstablePacketLossPercent` | `double` | 5.0 |
| `stableJitter` | `Duration` | 30 ms |
| `unstableJitter` | `Duration` | 50 ms |
| `spikeMultiplier` | `double` | 2.0 |
| `spikeMinDelta` | `Duration` | 50 ms |
| `minimumSamplesForVerdict` | `int` | 3 |

**Validation**: every `stableX` must be strictly less than its `unstableX`;
percentages in 0…100; `spikeMultiplier` > 1.0; `minimumSamplesForVerdict` ≥ 1.
Each field is individually optional and falls back to its default (FR-010).

---

## 2. Session facts

### `NetworkInterfaceType` — enum *(FR-014)*

`ethernet`, `wifi`, `cellular5g`, `cellular4g`, `cellular3g`, `cellular2g`,
`cellular` (generation unavailable), `vpn`, `other`, `none`, `unknown`.

`cellular` is the honest answer on Android when `READ_PHONE_STATE` has not been
granted to the host application — see research R-005. iOS always resolves a
generation.

### `MonitorKind` — enum *(FR-013)*

`internet`, `gateway`. Present on `SessionData` so a consumer that only holds a
metrics object still knows which kind produced it.

### `SessionData` *(FR-013)*

| Field | Type | Notes |
|-------|------|-------|
| `interfaceType` | `NetworkInterfaceType` | current, updated on change (FR-014) |
| `protocol` | `MonitorProtocol` | as configured |
| `kind` | `MonitorKind` | internet or gateway |
| `deviceIpAddress` | `String` | the device's address on this network |
| `targetAddress` | `String` | what probes are actually sent to |
| `targetName` | `String` | display name; for gateway, `"Gateway"` |
| `startedAt` | `DateTime` (UTC) | wall clock, for display only |

`deviceIpAddress` and `targetAddress` are deliberately distinct fields — the
spec's Assumptions call this out explicitly. `startedAt` is the one place a
wall clock appears in session facts; every elapsed value is monotonic (R-013).

---

## 3. Measurements

### `ConnectionHealth` — enum *(FR-022)*

`stable`, `unstable`, `critical`, `unknown`. Definitions are the spec's;
thresholds are R-006.

### `ConnectionMetrics` *(FR-021, FR-025, FR-027)*

| Field | Type | Window | Null when |
|-------|------|--------|-----------|
| `session` | `SessionData` | — | never |
| `latency` | `Duration?` | latest sample | the latest probe failed |
| `packetLossPercent` | `double` | rolling | never (0.0 with no losses) |
| `jitter` | `Duration?` | rolling | fewer than 2 successful samples |
| `spikeCount` | `int` | cumulative | never |
| `health` | `ConnectionHealth` | rolling | never (`unknown` instead) |
| `uptime` | `Duration` | cumulative | never |
| `averageLatency` | `Duration?` | cumulative | no successful sample yet |
| `lowestLatency` | `Duration?` | cumulative | no successful sample yet |
| `highestLatency` | `Duration?` | cumulative | no successful sample yet |

Rounding: latency and jitter to 0.1 ms, packet loss to 0.1 % (R-013).
Nullability is the mechanism for "not yet available" (FR-027) — no sentinel
zeros.

**Window vs cumulative** *(FR-020)*: `packetLossPercent`, `jitter` and `health`
reflect only the rolling window and therefore recover. `spikeCount`, `uptime`
and the three latency aggregates span the whole session and never reset while it
runs.

---

## 4. Events

### `MonitorEventKind` — enum *(FR-031)*

Edge-triggered, always emitted: `monitoringStarted`, `monitoringStopped`,
`healthChanged`, `connectivityLost`, `connectivityRestored`,
`interfaceChanged`, `ipAddressChanged`, `targetAddressChanged`.

Level-triggered, 30 s per-kind cooldown (R-012): `packetLossDetected`,
`highJitterDetected`, `latencySpikeDetected`.

### `MonitorEvent` *(FR-030, FR-032)*

| Field | Type | Notes |
|-------|------|-------|
| `session` | `SessionData` | facts at the moment of the event |
| `timestamp` | `DateTime` | **always UTC** — asserted in the constructor |
| `kind` | `MonitorEventKind` | machine-readable |
| `message` | `String` | human-readable, includes the triggering value |

---

## 5. Combined stream

### `MonitorUpdate` — sealed *(FR-034, FR-035)*

```
sealed class MonitorUpdate
  SessionData session

final class MetricsUpdate extends MonitorUpdate   { ConnectionMetrics metrics }
final class EventUpdate   extends MonitorUpdate   { MonitorEvent      event   }
```

Sealed so host code can `switch` exhaustively with no default branch, which is
what FR-035's "unambiguously identifiable" means in Dart terms.

---

## 6. Raw native input — the engine's domain

### `MonitorSignal` — sealed

```
sealed class MonitorSignal

final class ProbeSample extends MonitorSignal
  int         sequence          // monotonic, from 0
  Duration?   roundTrip         // null when the probe failed
  ProbeOutcome outcome          // success | timeout | unreachable | error
  Duration    sinceSessionStart // monotonic elapsed, native-measured

final class NetworkStateChange extends MonitorSignal
  NetworkInterfaceType interfaceType
  String?              deviceIpAddress
  String?              targetAddress
```

`ProbeOutcome` — `success`, `timeout`, `unreachable`, `error`.

This pair is the only thing native code produces. It is public but documented as
an advanced surface: host applications consume `ConnectionMetrics`, while
`ProbeSample` exists so the metrics engine can be tested against fixed fixtures
with no platform channel (Principle IV), and so a future platform can be added
without redefining the boundary.

---

## 7. Failures *(FR-037, FR-038)*

All implement `Failure` from the existing `lib/src/core/result/`, carry
`message` and optional `details`, and are grouped in one library with parts.

| Type | Raised when |
|------|-------------|
| `PermissionFailure` | an OS permission needed to inspect the network is denied; carries remediation guidance (FR-040) |
| `UnsupportedCapabilityFailure` | the platform cannot honour the requested protocol — e.g. ICMP on an IPv6-only network (FR-039, R-009) |
| `GatewayDiscoveryFailure` | no default route could be found (FR-007, US3 scenario 2) |
| `InvalidConfigurationFailure` | a configuration reached the platform that violates FR-006 or FR-011 |
| `TargetUnreachableFailure` | the target could not be reached at all at start time |
| `ProbeTimeoutFailure` | a discrete operation exceeded its documented timeout |
| `SessionAlreadyRunningFailure` | `startMonitoring` called while a session is live (FR-015) |
| `NoActiveSessionFailure` | `currentSession` called with nothing running (FR-017) |

Named `ProbeTimeoutFailure` rather than `TimeoutFailure` to leave the shorter
name free for the diagnostic-tools domain, which will need its own.

---

## 8. State transitions

### Session lifecycle

```
        idle ──start──▶ starting ──ok──▶ running ──stop─────────▶ stopping ──▶ idle
          ▲                 │                │  ▲                     ▲
          └────failure──────┘                └──┴──last listener──────┘
                                                     cancels
```

- `start` while `running` → `SessionAlreadyRunningFailure`, running session
  untouched (FR-015).
- `stop` while `idle` → success, no-op (FR-016).
- `stopping` completes within 500 ms (R-011).
- Auto-stop fires only on a 1 → 0 subscriber transition, never at 0 → 0, so a
  never-subscribed session keeps running as the spec's edge case requires.

### Health verdict

Recomputed on every sample. `unknown` until the window holds
`minimumSamplesForVerdict` successful samples, or whenever `interfaceType` is
`none`. Otherwise the worst of the three independently graded inputs (R-006).
Every transition emits `healthChanged` carrying both the previous and the new
verdict.

### Connectivity

`connectivityLost` on the first `NetworkStateChange` to `none`;
`connectivityRestored` on the first change away from it. The session stays alive
throughout (US6 scenario 2) so it can report the recovery.

### Target address

Primary → secondary after 3 consecutive failed probes, once per session, only if
a secondary exists. Emits `targetAddressChanged`. Never switches back (R-010).
