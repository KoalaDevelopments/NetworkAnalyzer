# Implementation Plan: Real-time Monitoring

**Branch**: `001-real-time-monitoring` | **Date**: 2026-08-24 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-real-time-monitoring/spec.md`

## Summary

Give host applications a live, trustworthy picture of the current connection.
The host builds an immutable `MonitorInterface` — internet (protocol + host) or
gateway (protocol only, address discovered) — and starts a session. Starting
returns a `SessionData`; three streams then carry `ConnectionMetrics`,
`MonitorEvent`s, and a combined `MonitorUpdate` view.

Technical approach, in one line: **native probes, Dart mathematics.**

The native side does only what native must do — send a probe and time it with a
monotonic clock, read the interface type, read the device address, discover the
default gateway, and report interface changes. It streams raw `ProbeSample`s and
`NetworkStateChange`s over one pigeon `@EventChannelApi`. Everything derived —
rolling packet loss, jitter, spike detection, the health verdict, session
aggregates, event synthesis and throttling — is computed once in pure Dart
inside `network_analyzer`. That choice is what makes Principle II's "identical
semantics on Android and iOS" achievable (one implementation, not two) and
Principle IV's "deterministic unit tests over fixed fixtures" possible (the
engine is a pure function of a sample sequence; no test touches a live network).

No new pub.dev dependency is required.

## Technical Context

**Language/Version**: Dart 3.11 (`sdk: ^3.11.0`), Kotlin 2.4 / JVM 17,
Swift 5.9

**Primary Dependencies**: `flutter`, `plugin_platform_interface ^2.0.2`,
`meta ^1.15.0`, `pigeon ^27.3.2` (dev, codegen only). **No new runtime
dependency is added by this feature** — the metrics engine is pure Dart and the
native probes use platform SDK APIs only.

**Storage**: N/A. This feature persists nothing (FR-041). Scanner History is a
separate domain.

**Testing**: `flutter_test` + `package:checks` (Dart), JUnit 5 + Mockito
(Kotlin, already configured in `android/build.gradle.kts`), XCTest (Swift —
**a test target must be added to `Package.swift`; none exists today**),
`package:integration_test` in `packages/network_analyzer/example`.

**Target Platform**: Android `minSdk 24` / `compileSdk 36`; iOS 15.0.

**Project Type**: Federated Flutter plugin — four packages plus an example app.
No UI ships in plugin packages.

**Performance Goals**: One measurement per configured probe interval (default
1 s) with no gap exceeding twice the interval (SC-002). First measurement within
3 s of start (SC-001). Probing halts within 500 ms of stop or of the last
subscriber cancelling — comfortably inside the 2 s the spec allows (SC-005).

**Constraints**: UI isolate never blocked — native probing runs on a serial
dispatcher (Android) / serial `DispatchQueue` (iOS); the Dart engine does
O(window) arithmetic over a default 10-sample window once per interval, which is
far too small to warrant `compute()`. Memory is bounded by the rolling window
plus scalar aggregates, so a 24-hour session cannot grow without bound (SC-006).
All elapsed time comes from monotonic sources (`System.nanoTime`,
`clock_gettime(CLOCK_MONOTONIC_RAW)`, `Stopwatch`); wall-clock UTC is used only
for the `MonitorEvent.timestamp` a human reads.

**Scale/Scope**: One session at a time (FR-015). 42 functional requirements,
6 user stories. Roughly 12 new public types, 8 new failure types, 4 new contract
members, 1 new pigeon input file per platform package.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

| # | Principle | How this design satisfies it | Verdict |
|---|-----------|------------------------------|---------|
| I | Federated, API-first | Every capability lands in `network_analyzer_platform_interface` first; `network_analyzer` re-exports the public types and is the only package the example depends on; endorsement stays `default_package`; no UI in plugin packages; dartdoc on every new public member. | PASS |
| II | Typed, versioned contracts | All Dart↔native traffic goes through a new pigeon input per platform package (`pigeons/monitoring.dart`), including the stream, via `@EventChannelApi`. `NetworkAnalyzerPlatform` grows add-only members with `UnimplementedError` defaults, so neither platform package breaks. Identical semantics are structural: both platforms emit the same raw sample shape and the single Dart engine derives everything else. | PASS |
| III | Result-based errors | Every new contract member returns `Result<T, Failure>`. Eight typed failures cover FR-038. Native `PlatformException`s are caught at the platform-package boundary and mapped; stream errors are converted to `MonitorEvent`s or typed failures, never rethrown at the host. Logging via `dart:developer`. | PASS |
| IV | Test-first | The metrics engine is a pure function over a `ProbeSample` sequence, so every threshold, jitter value, spike and health transition is tested against fixed fixtures with zero network access. Contract behaviour is tested through fakes of `NetworkAnalyzerPlatform`. Kotlin probers are tested for packet construction and checksum; Swift likewise once the XCTest target exists. Integration tests run the real thing on both platforms. | PASS |
| V | Streams vs Futures | Continuous data (metrics, events, updates) is `Stream`; discrete operations (start, stop, current session) are `Future`. Cadence is documented and configurable. `onCancel` on the native stream handlers plus a Dart listener counter give the bounded stop required by FR-016/FR-018. Single-flight is enforced by the session registry, which rejects a second start with `SessionAlreadyRunningFailure`. | PASS |
| VI | Measurement integrity | Monotonic clocks only for anything timed. Probing off the UI isolate on a serial native queue. Units fixed: milliseconds for latency and jitter, percent for loss, `Duration` for uptime, each with documented rounding. Nothing is interpolated — a failed probe is recorded as a loss, never as an estimated latency. No autonomous bandwidth use: probes are tiny and only run while a session the host started is alive. | PASS |
| — | Security & permissions | Android declares only `INTERNET` and `ACCESS_NETWORK_STATE` (both normal). Cellular *generation* needs `READ_PHONE_STATE`, which the plugin deliberately does **not** declare — without it the session reports generic `cellular`, exactly the degradation FR-014 allows. iOS needs no entitlement and no Info.plist key. No PII, no device identifiers, no persistence. ICMP is documented per protocol, and a platform that cannot honour a protocol returns `UnsupportedCapabilityFailure` rather than substituting one. | PASS |
| — | Data management | Nothing durable is written. Native mutable state is confined to one serial dispatcher per platform. | PASS |
| — | Infrastructure | Targets are injected configuration with overridable defaults (presets are conveniences, never hard requirements). Every probe has an explicit timeout with a documented default. Probers sit behind a `Prober` interface on both platforms so tests inject fakes. Zero new pub.dev dependencies. | PASS |

**Result: PASS, no violations.** The Complexity Tracking table below is
therefore empty, as the template requires.

**Re-check after Phase 1 design: PASS.** The design added no shared mutable
singleton, no third-party dependency, and no hand-written channel code. The one
judgement call worth naming — computing metrics in Dart rather than twice
natively — *reduces* rather than adds complexity, and is what makes Principles
II and IV attainable. It is recorded in `research.md` as decision R-001.

## Project Structure

### Documentation (this feature)

```text
specs/001-real-time-monitoring/
├── plan.md              # This file
├── spec.md              # Feature specification (FR-001..FR-042)
├── research.md          # Phase 0 output — 14 recorded decisions
├── data-model.md        # Phase 1 output — entities, validation, state machines
├── quickstart.md        # Phase 1 output — runnable validation guide
├── contracts/
│   ├── public-api.md            # What host applications call
│   ├── platform-interface.md    # NetworkAnalyzerPlatform additions
│   └── native-messages.md       # pigeon HostApi + EventChannelApi shape
└── checklists/
    └── requirements.md  # Spec quality checklist (16/16)
```

### Source Code (repository root)

```text
packages/network_analyzer_platform_interface/
├── lib/
│   ├── network_analyzer_platform_interface.dart   # barrel — add monitoring exports
│   └── src/
│       ├── network_analyzer_platform.dart         # + 4 add-only contract members
│       ├── failures/
│       │   └── monitoring_failures.dart           # library + 8 parts (typed failures)
│       └── types/monitoring/
│           ├── monitor_protocol.dart              # enum tcp | udp | icmp
│           ├── monitor_kind.dart                  # enum internet | gateway
│           ├── monitor_host.dart                  # sealed + parts: PresetHost, CustomHost
│           ├── monitor_interface.dart             # sealed + parts: Internet, Gateway
│           ├── monitor_options.dart               # interval, timeout, window + validation
│           ├── health_thresholds.dart             # defaults + validation
│           ├── connection_health.dart             # enum stable|unstable|critical|unknown
│           ├── network_interface_type.dart        # enum ethernet|wifi|cellular*|vpn|none|unknown
│           ├── session_data.dart
│           ├── connection_metrics.dart
│           ├── monitor_event.dart                 # + MonitorEventKind
│           ├── monitor_update.dart                # sealed: MetricsUpdate | EventUpdate
│           └── monitor_signal.dart                # sealed: ProbeSample | NetworkStateChange
│                                                  #   (raw native input to the engine)
└── test/src/
    ├── types/monitoring/…                          # one test file per type
    └── failures/monitoring_failures_test.dart

packages/network_analyzer/
├── lib/
│   ├── network_analyzer.dart                      # facade + exports (loses `const` ctor)
│   └── src/monitoring/
│       ├── monitoring_controller.dart             # single-flight, stream fan-out, listeners
│       ├── metrics_engine.dart                    # ProbeSample → ConnectionMetrics
│       ├── rolling_window.dart                    # fixed-capacity sample window
│       ├── health_evaluator.dart                  # thresholds → ConnectionHealth
│       ├── spike_detector.dart
│       ├── jitter_calculator.dart
│       └── event_synthesizer.dart                 # state transitions → MonitorEvent + throttle
├── test/
│   ├── network_analyzer_test.dart                 # facade against a fake platform
│   └── src/monitoring/…                            # engine fixtures, one file per unit
└── example/
    ├── lib/…                                       # monitoring screen (StreamBuilder)
    └── integration_test/monitoring_test.dart

packages/network_analyzer_android/
├── pigeons/monitoring.dart                        # NEW input (feature-scoped)
├── lib/
│   ├── network_analyzer_android.dart              # implements the 4 new members
│   └── src/
│       ├── monitoring.g.dart                      # generated — never hand-edited
│       └── monitoring/monitor_mapper.dart         # pigeon DTO ↔ domain model
├── android/src/main/
│   ├── AndroidManifest.xml                        # + INTERNET, ACCESS_NETWORK_STATE
│   └── kotlin/com/koaladevelopments/network_analyzer_android/
│       ├── NetworkAnalyzerAndroidPlugin.kt        # wires the new APIs
│       ├── Monitoring.g.kt                        # generated
│       └── monitoring/
│           ├── MonitorSessionController.kt        # serial dispatcher, lifecycle
│           ├── MonitorStreamHandler.kt            # onListen / onCancel
│           ├── NetworkInspector.kt                # type, address, default gateway
│           └── probe/{Prober,TcpProber,UdpProber,IcmpProber,IcmpPacket}.kt
└── android/src/test/kotlin/…                       # JUnit 5 per unit

packages/network_analyzer_ios/
├── pigeons/monitoring.dart                        # NEW input (mirrors Android)
├── lib/{network_analyzer_ios.dart, src/monitoring.g.dart, src/monitoring/monitor_mapper.dart}
└── ios/network_analyzer_ios/
    ├── Package.swift                              # + XCTest target (does not exist yet)
    ├── Sources/network_analyzer_ios/
    │   ├── NetworkAnalyzerIosPlugin.swift
    │   ├── Monitoring.g.swift                     # generated
    │   └── Monitoring/
    │       ├── MonitorSessionController.swift     # serial DispatchQueue
    │       ├── MonitorStreamHandler.swift
    │       ├── NetworkInspector.swift             # getifaddrs + route sysctl
    │       └── Probe/{Prober,TcpProber,UdpProber,IcmpProber,IcmpPacket}.swift
    └── Tests/network_analyzer_iosTests/…

tool/bootstrap.sh                                  # loop pigeons/*.dart, not just messages.dart
```

**Structure Decision**: the existing federated four-package layout is kept
unchanged; this feature adds directories inside it rather than reshaping it.
Three rules drove the file split:

1. **Domain models live in the platform interface**, because Principle I
   requires the capability to be declared there before either platform
   implements it, and because both platform packages and the facade need the
   same types.
2. **Derived mathematics lives in the app-facing package**, not in the platform
   interface and not in native code. The platform interface stays what the
   constitution calls it — the contract — while `network_analyzer` becomes the
   controller that turns raw samples into the three streams.
3. **Everything is split small.** The 300-line ceiling in `CLAUDE.md` is met by
   construction: sealed hierarchies use a library file plus parts, and each
   native concern (inspection, each protocol, stream handling, lifecycle) is its
   own file. No file in this plan is projected to approach the limit.

## Complexity Tracking

> Fill ONLY if Constitution Check has violations that must be justified.

No violations. This feature introduces no new dependency, no new package, and no
deviation from the constitution, so this table is intentionally empty.
