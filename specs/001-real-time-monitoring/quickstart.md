# Quickstart: Validating Real-time Monitoring

**Feature**: `001-real-time-monitoring` | **Date**: 2026-08-24

How to prove this feature works, from a clean checkout to a device. Details of
what each type contains live in [data-model.md](./data-model.md); the call
signatures live in [contracts/public-api.md](./contracts/public-api.md).

## Prerequisites

- Flutter SDK with Dart `^3.11.0`
- Android SDK: `compileSdk 36`, `minSdk 24`, JDK 17
- Xcode with an iOS 15+ simulator or device
- An Android emulator or device with working connectivity

## Setup

```bash
./tool/bootstrap.sh
```

This resolves the workspace, adds `pigeon` where missing, **regenerates every
`pigeons/*.dart` input** (the loop replacing the old hard-coded single input —
research R-003), formats, analyzes, and runs the Dart tests.

Confirm codegen produced the new files — if any is missing, pigeon did not run:

```bash
ls packages/network_analyzer_android/lib/src/monitoring.g.dart \
   packages/network_analyzer_android/android/src/main/kotlin/com/koaladevelopments/network_analyzer_android/Monitoring.g.kt \
   packages/network_analyzer_ios/lib/src/monitoring.g.dart \
   packages/network_analyzer_ios/ios/network_analyzer_ios/Sources/network_analyzer_ios/Monitoring.g.swift
```

## Gate 1 — the gates the constitution requires

```bash
dart format --set-exit-if-changed .
dart fix --apply
flutter analyze                       # must be zero diagnostics
```

## Gate 2 — deterministic engine tests, no network

The heart of the feature. Every threshold, jitter value, spike and health
transition is asserted against fixed `ProbeSample` fixtures — nothing here
touches a live network, per Principle IV.

```bash
cd packages/network_analyzer && flutter test test/src/monitoring/
```

Expect coverage of, at minimum:

| Scenario | Expected |
|----------|----------|
| 10 samples at 20 ms, no losses | `health == stable`, `packetLossPercent == 0.0` |
| 1 sample only | `jitter == null`, `averageLatency == lowestLatency == highestLatency` |
| 2 samples | `jitter` becomes non-null |
| fewer than 3 successful samples | `health == unknown` |
| window of 10 with 1 failure | `packetLossPercent == 10.0` |
| loss recovers over the next 10 samples | `packetLossPercent` returns to `0.0` (rolling) |
| 20 ms baseline then a 300 ms sample | `spikeCount == 1`; count never decreases |
| 20 ms baseline then a 45 ms sample | `spikeCount == 0` — under the 50 ms minimum delta |
| rolling mean latency 300 ms | `health == critical` |
| all probes fail, interface present | `packetLossPercent == 100.0`, `health == critical` |
| interface type becomes `none` | `health == unknown`, `connectivityLost` emitted |
| same fixture replayed twice | byte-identical metrics both times (SC-004) |
| custom thresholds supplied | verdicts shift accordingly; omitted fields keep defaults |
| 86 400 samples (24 h at 1 s) | retained samples stay at the window size (SC-006) |

## Gate 3 — contract and mapper tests

```bash
cd packages/network_analyzer_platform_interface && flutter test
cd ../network_analyzer_android && flutter test
cd ../network_analyzer_ios && flutter test
```

Covers construction validation (`GatewayInterface` rejecting UDP, bad IPv4,
`stableLatency` not below `unstableLatency`, out-of-range interval or window),
failure mapping, and pigeon message ⇄ domain conversion in both directions.

## Gate 4 — compile the iOS module

Do this **before** reaching for a device. Dart tooling cannot see Swift type
errors, and `swiftc -parse` only checks syntax — it resolves no symbols, so it
will happily accept a type the iOS SDK does not ship.

```bash
cd packages/network_analyzer/example
flutter build ios --no-codesign --debug
```

The trap this catches: the iOS SDK ships **no `<net/route.h>`**, so
`rt_msghdr`, `RTF_*` and `RTA_*` cannot be imported by Swift or by C, even
though `CTL_NET`, `PF_ROUTE` and `NET_RT_DUMP` are all present in
`<sys/socket.h>`. `RouteTable` therefore declares those constants itself and
reads the message by byte offset. Any drift there shows up here.

For a faster loop while editing Swift, the Monitoring sources typecheck
standalone against the SDK, since only `Foundation`, `Network` and
`CoreTelephony` are involved:

```bash
swiftc -typecheck \
  -sdk "$(xcrun --sdk iphoneos --show-sdk-path)" \
  -target arm64-apple-ios15.0 \
  packages/network_analyzer_ios/ios/network_analyzer_ios/Sources/network_analyzer_ios/Monitoring/RouteTable.swift
```

## Gate 5 — native unit tests

```bash
cd packages/network_analyzer_android/android && ./gradlew test
```

```bash
cd packages/network_analyzer_ios/ios/network_analyzer_ios && swift test
```

The Swift command requires the XCTest target that this feature adds to
`Package.swift` — none exists today.

Both suites cover ICMP echo packet construction and checksum, prober timeout
behaviour against a fake socket, interface-type mapping, gateway extraction from
a fixed route table, and that stopping halts the timer.

## Gate 6 — on a device

```bash
cd packages/network_analyzer/example
flutter run                                    # Android and iOS
flutter test integration_test/monitoring_test.dart
```

Walk each user story:

1. **US1** — start an internet monitor on `PresetHost.google` over TCP. A
   session appears within 3 s (SC-001) reporting interface type, device IP and
   target address; metrics tick once a second.
2. **US2** — watch the event list: `monitoringStarted` first, then transitions
   as conditions change.
3. **US3** — start a gateway monitor with no address. The discovered gateway
   appears as the target.
4. **US4** — cycle all three presets, then a custom host. The target name and
   address track the selection.
5. **US5** — the combined view shows metrics and events interleaved in order.
6. **US6** — toggle Wi-Fi off with mobile data available. The interface type
   updates and `interfaceChanged` is emitted within one interval (SC-007).
   Toggle airplane mode: health goes `unknown`, `connectivityLost` fires, the
   session survives, and `connectivityRestored` fires on recovery.

Then the negative and lifecycle paths:

- Start twice → `SessionAlreadyRunningFailure`, first session unaffected.
- Stop when idle → succeeds, no error.
- Cancel every subscription → probing stops within 2 s (SC-005); verify with the
  platform's network inspector that no traffic continues.
- ICMP on an IPv6-only/NAT64 network → `UnsupportedCapabilityFailure`, while TCP
  and UDP keep working (research R-009).
- Background the app, return → documented behaviour, no crash.

## Gate 7 — parity

Run Gate 6 on Android and iOS against the same target and options. Reported
values must agree within the documented tolerance (SC-010). They should: only
raw round-trip time, interface type, device address and gateway address are
decided natively — every derived value comes from the one shared Dart engine
(research R-001).

## Known environment behaviours — not defects

Observed during device validation (2026-08-24). Each is the environment
telling the truth; none is a measurement error.

### Android emulator

- **Internet ICMP shows 100% loss.** QEMU's user-mode NAT (slirp) does not
  forward ICMP echo to external hosts — only the virtual addresses
  (10.0.2.1, 10.0.2.2) answer pings from inside the emulator. This is a
  long-standing emulator limitation. Gateway ICMP works (the virtual router
  answers in ~1 ms); internet ICMP needs a physical device.
- **Latency numbers are emulator artifacts.** All emulator traffic funnels
  through the slirp NAT stack in the host process; "Wi-Fi" is fully
  emulated and never joins the host's LAN, and the emulator's signal-quality
  setting shapes reported RSSI, not timing. High internet latency and odd
  values like a ~300 ms TCP "refusal" from the virtual gateway are slirp
  behaviours. Treat emulator runs as functional checks only; latency claims
  (SC-001, SC-002, SC-010) need physical hardware.

### Cellular networks (physical devices)

- **ICMP runs high and unstable by design of the carrier.** Mobile networks
  give ICMP echo the lowest priority and rate-limit it; several hundred ms
  with early drops while the radio wakes is normal, on the same connection
  where TCP shows ~100 ms. The gap is the carrier's ICMP policy, measured.
- **Gateway monitoring reports loss on most carriers.** The discovered
  "gateway" is the carrier's first hop, which usually drops probes
  silently. Gateway monitoring answers "is my router OK", which is a
  Wi-Fi/Ethernet question; on cellular use an internet monitor.

## Done when

Every gate above is green, `flutter analyze` reports zero diagnostics, each new
public member carries dartdoc, and both the local map
(`maps/real_time_monitoring/map.json`) and the root `domains_map.json` reflect
the delivered files — the Map Protocol check that closes the task.
