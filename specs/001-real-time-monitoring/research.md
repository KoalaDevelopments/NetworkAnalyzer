# Phase 0 Research: Real-time Monitoring

**Feature**: `001-real-time-monitoring` | **Date**: 2026-08-24

Every decision below was verified against the installed toolchain or the real
platform SDKs on this machine — not recalled. Verification notes say how.

Two items the spec deliberately deferred to planning are resolved here:
concrete health thresholds (R-006) and the bounded stop time (R-011).

---

## R-001: Where the metrics mathematics lives

**Decision**: Native code produces only raw `ProbeSample`s (sequence number,
monotonic round-trip time or a failure reason) and `NetworkStateChange`s.
Rolling packet loss, jitter, spike detection, health evaluation, session
aggregates and event synthesis are computed in pure Dart, in
`packages/network_analyzer/lib/src/monitoring/`.

**Rationale**: Principle II demands identical semantics on Android and iOS. The
cheapest way to guarantee that is to have one implementation rather than two
that must be kept in agreement. Principle IV demands that measurement logic be
covered by deterministic tests over fixed fixtures with no live network — which
is trivially satisfiable when the engine is a pure function from a sample list
to a metrics list, and awkward otherwise. The arithmetic is O(window) over a
10-sample default, once per second: far below the threshold where an isolate or
`compute()` would earn its keep.

**Alternatives considered**:
- *Compute natively, emit finished metrics*: rejected — duplicates every
  threshold rule in Kotlin and Swift, doubles the test surface, and makes
  cross-platform drift a matter of when rather than whether.
- *Compute in a Dart isolate*: rejected as premature. Ten additions and a sort
  per second do not justify isolate setup or message-passing overhead. If a
  future window size makes this false, the engine is already a pure function and
  moves behind `compute()` without changing its contract.

---

## R-002: Streaming Dart↔native without hand-written channel code

**Decision**: Use pigeon's `@EventChannelApi` with a **sealed** message
hierarchy — one channel carrying `ProbeSampleMessage | NetworkStateMessage`.
Session control (`startSession`, `stopSession`, `currentSession`) stays on a
plain `@HostApi()`.

**Rationale**: `CLAUDE.md` forbids hand-written `EventChannel` code outright,
and pigeon 27.3.2 generates typed event channels for Dart, Kotlin and Swift,
including sealed-class unions. The generated Swift/Kotlin stream handlers expose
`onListen`/`onCancel`, which is precisely the hook FR-018 needs to stop native
probing when the last subscriber goes away.

**Verification**: read `pigeon-27.3.2/example/app/pigeons/event_channel_messages.dart`
and `example/README.md` — sealed `PlatformEvent` with `IntEvent`/`StringEvent`
subclasses, `@EventChannelApi() abstract class EventChannelMethods { PlatformEvent streamEvents(); }`,
generating a Dart `Stream<PlatformEvent>` and a Swift
`StreamEventsStreamHandler` with a `PigeonEventSink`.

**Constraint discovered**: pigeon rejects parameters on event-channel methods —
`pigeon_lib_internal.dart:714` raises *"event channel methods must not be
contain parameters"* — and requires all event-channel methods to sit in a single
`@EventChannelApi` (same file, line 685). Hence one parameterless stream, with
configuration passed separately through `startSession` on the `HostApi`. The
Dart platform implementation subscribes to the stream **before** calling
`startSession`, so no sample can be missed in the gap.

**Alternatives considered**:
- *Poll a `HostApi` method on a Dart timer*: rejected — moves cadence control to
  the wrong side of the boundary and wastes a round-trip per probe.
- *Two separate event channels*: not available; pigeon requires a single
  `@EventChannelApi`. The sealed union delivers the same thing on one channel.

---

## R-003: Two pigeon input files in one package

**Decision**: Add `pigeons/monitoring.dart` alongside the existing
`pigeons/messages.dart` in each platform package, per the `CLAUDE.md` rule of
one input file per feature. The new file sets
`KotlinOptions(includeErrorClass: false)` and
`SwiftOptions(includeErrorClass: false)`, and `tool/bootstrap.sh` changes from a
single hard-coded `--input pigeons/messages.dart` to a loop over
`pigeons/*.dart`.

**Rationale**: each pigeon input emits its own error class by default; a second
input in the same Kotlin package or Swift module would redeclare it and fail to
compile. Suppressing it on the *second* file reuses the one the bootstrap file
already generates.

**Verification**: `pigeon-27.3.2/example/app/pigeons/event_channel_messages.dart`
uses exactly this pairing — `KotlinOptions(includeErrorClass: false)` and
`SwiftOptions(includeErrorClass: false)` — for its second input file.

---

## R-004: How each probe protocol is actually sent

**Decision**: one `Prober` interface per platform with three implementations.

| Protocol | Android | iOS | Measures |
|----------|---------|-----|----------|
| TCP | `SocketChannel` non-blocking connect to the target port, timed | `getaddrinfo` + BSD `connect` on a non-blocking socket, timed | connect round-trip |
| UDP | `DatagramChannel`: send a DNS query for `.` to port 53, await reply | BSD `SOCK_DGRAM` send/recv, same payload | request-to-reply round-trip |
| ICMP | `android.system.Os.socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)` — unprivileged ICMP datagram socket | `socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)`, the Apple `SimplePing` approach | echo request/reply round-trip |

Default port for TCP and UDP is 53, because every preset target is a DNS
resolver; the port is overridable on a custom target.

**Amendments from device testing (2026-08-24):**

- **A refused TCP connection is a success, not a loss.** The RST that refuses
  it round-tripped from the target: reachability proven, timing real. Without
  this, gateway monitoring reports 100% loss against any router that listens
  on no TCP port — including the Android emulator's virtual gateway.
- **Darwin delivers the IPv4 header on ICMP datagram sockets; Linux strips
  it.** The reply parser must strip a leading IPv4 header on iOS or every
  genuine echo reply reads as malformed (observed as 100% loss). Receiving
  also loops until the matching sequence arrives — the socket delivers every
  ICMP message addressed to it, not only ours.
- **`SO_SNDTIMEO` does not bound a blocking `connect()` on Darwin.** The iOS
  TCP probe uses a non-blocking connect completed with `poll` and read back
  through `SO_ERROR`; a blackholing gateway would otherwise hang the probe
  queue for the kernel's ~75 s timeout and the session would emit nothing.

**Rationale**: ICMP was the one protocol at risk of being impossible on
Android without an NDK component. It is not: unprivileged ICMP *datagram*
sockets have been permitted since Android 5, and `android.system.Os` exposes the
whole BSD socket surface needed to drive one from Kotlin — no JNI, no shelling
out to `/system/bin/ping`, no `InetAddress.isReachable()` (which silently falls
back to TCP port 7 and cannot report a clean round-trip time).

**Verification**: disassembled
`$ANDROID_HOME/platforms/android-36/android.jar` on this machine.
`android.system.OsConstants` declares `IPPROTO_ICMP`, `IPPROTO_ICMPV6`,
`SOCK_DGRAM`, `AF_INET`, `AF_INET6`; `android.system.Os` declares
`socket(int,int,int)`, `sendto`, `recvfrom`, `poll`, `setsockoptTimeval` and
`close`. On iOS the same call is Apple's own documented `SimplePing` technique
and is App Store safe.

**Alternatives considered**:
- *NDK/JNI ICMP on Android*: rejected — a C toolchain, a build hook and a second
  ABI matrix to maintain, for an API that already exists in the SDK.
- *`InetAddress.isReachable()`*: rejected — protocol is not under our control, so
  the reported protocol in `SessionData` would be a guess. That is precisely the
  "silently degraded result" the constitution forbids.
- *Declaring ICMP unsupported on Android*: rejected once the SDK check above
  came back positive. Would have been the honest fallback, not a shortcut.

---

## R-005: Reading interface type, device address and default gateway

**Decision**:

| Fact | Android | iOS |
|------|---------|-----|
| Interface type | `ConnectivityManager.NetworkCapabilities.hasTransport(TRANSPORT_WIFI / CELLULAR / ETHERNET / VPN)` | `NWPathMonitor.currentPath.usesInterfaceType` |
| Cellular generation | `TelephonyManager.getDataNetworkType()` — **best effort**, see below | `CTTelephonyNetworkInfo.serviceCurrentRadioAccessTechnology` |
| Device address | `LinkProperties.getLinkAddresses()` | `getifaddrs`, filtered to the active interface |
| Default gateway | `LinkProperties.getRoutes()`, first `RouteInfo` where `isDefaultRoute()`, then `getGateway()` | route table via `sysctl(CTL_NET, PF_ROUTE, NET_RT_DUMP)`, first entry with `RTF_GATEWAY \| RTF_UP` |
| Change notification | `ConnectivityManager.registerDefaultNetworkCallback` | `NWPathMonitor.pathUpdateHandler` |

**Rationale**: all public, all permission-light. iOS has no public gateway API,
but reading the BSD route table through `sysctl` is a public interface, is what
every shipping implementation uses, and passes App Store review.

**Verification**: `android.net.RouteInfo` declares `isDefaultRoute()` and
`getGateway()`; `android.net.LinkProperties` declares `getRoutes()` and
`getLinkAddresses()`; `android.net.NetworkCapabilities` declares `hasTransport`
and the four transport constants — all confirmed against `android-36/android.jar`.

**Cellular generation is deliberately best-effort.** From API 30,
`getDataNetworkType()` requires `READ_PHONE_STATE`, a *dangerous* runtime
permission. Declaring it in the plugin manifest would push that permission onto
every host application that adds this plugin, which violates least privilege for
a field FR-014 already qualifies with "where the platform exposes it". So: the
plugin declares only `INTERNET` and `ACCESS_NETWORK_STATE`; if the host has
independently been granted `READ_PHONE_STATE` the session reports `cellular5g`,
`cellular4g`, `cellular3g` or `cellular2g`, and otherwise reports plain
`cellular`. Documented in the package README and in the `dartdoc` for
`NetworkInterfaceType`. iOS needs no permission for this and always reports the
generation.

---

## R-006: Concrete health thresholds *(deferred from the spec)*

**Decision**: defaults below, all overridable per `HealthThresholds` (FR-010).
Each of the three inputs is graded independently and **the worst grade wins**.

| Input | Stable | Unstable | Critical |
|-------|--------|----------|----------|
| Rolling mean latency | ≤ 100 ms | ≤ 250 ms | > 250 ms |
| Rolling packet loss | ≤ 1 % | ≤ 5 % | > 5 % |
| Rolling jitter | ≤ 30 ms | ≤ 50 ms | > 50 ms |

`unknown` is returned when the window holds fewer than **3 successful samples**,
or when the interface type is `none` (no connectivity at all).

**Rationale**: the numbers are the widely used interactive/VoIP quality bands —
ITU-T G.114 puts acceptable one-way delay at 150 ms, which is ~100 ms round-trip
for a healthy path; 30 ms jitter is the common ceiling for acceptable voice; and
1 % / 5 % loss are the standard good/degraded/unusable boundaries. Worst-of-three
is chosen because a connection with 0 ms jitter and 20 % loss is not healthy;
averaging the three grades would hide exactly the failure the feature exists to
surface.

**This also resolves the apparent tension inside the spec** between FR-022
("unknown = insufficient data *or* the target is unreachable") and the edge case
that says sustained total loss must report 100 % loss and the most severe level.
The rule that satisfies both: *unreachable target while the device has
connectivity* is `critical` with 100 % loss — the network is up and the target is
not answering, which is real, measured information. `unknown` is reserved for
"we do not have enough information to judge": too few samples, or no network
interface at all.

**Alternatives considered**:
- *Fixed, non-overridable thresholds*: rejected at spec time by the author
  (Q2 → option B). A satellite link and a LAN cannot share one definition of
  "stable".
- *Weighted score across the three inputs*: rejected — harder to explain, harder
  to test, and it lets one very good input mask one very bad one.

---

## R-007: Jitter, spikes and packet loss definitions

**Decision**:

- **Jitter** = the mean absolute difference between consecutive *successful*
  samples in the rolling window. Requires ≥ 2 successful samples, otherwise
  reported as not-yet-available.
- **Packet loss** = failed probes ÷ total probes in the rolling window × 100.
- **Spike** = a sample whose latency exceeds the window mean by a factor of
  `spikeMultiplier` (default 2.0) **and** by at least `spikeMinDelta`
  (default 50 ms). Requires ≥ 3 samples in the window. The spike count is
  cumulative for the session (FR-020, FR-026).

**Rationale**: mean absolute consecutive difference is trivially deterministic,
window-scoped as FR-020 requires, and explainable in one sentence — all three
matter for a value that appears in a public API. The two-condition spike rule
exists because a multiplier alone makes a 3 ms → 7 ms wobble on a LAN a "spike",
which is noise, not signal; the absolute floor suppresses that without weakening
detection on a slow link.

**Alternatives considered**:
- *RFC 3550 smoothed jitter* (`J += (|D| − J)/16`): rejected — it is an
  exponentially weighted value with unbounded history, which contradicts the
  rolling-window semantics the author chose in Q1, and it is materially harder to
  assert against a fixture.
- *Standard deviation for spikes*: rejected — needs a larger window to be stable
  and is far less intuitive in documentation.

---

## R-008: Probe timeout and option bounds

**Decision**: `MonitorOptions` carries `probeInterval` (default 1 s),
`probeTimeout` (default 1 s) and `sampleWindowSize` (default 10). Validation:

| Field | Bounds |
|-------|--------|
| `probeInterval` | 200 ms … 60 s |
| `probeTimeout` | 100 ms … `probeInterval` |
| `sampleWindowSize` | 1 … 300 |

A probe that does not answer inside `probeTimeout` is recorded as a loss.

**Rationale**: the constitution requires an explicit, documented timeout on
every network operation, and the spec's FR-011 requires documented bounds.
Capping the timeout at the interval keeps at most one probe in flight, which
keeps sequence numbering, loss accounting and the "one measurement per probe"
guarantee (FR-019) trivially correct. The 300-sample ceiling on the window caps
retained memory, satisfying SC-006 by construction.

**Note**: `probeTimeout` is an addition to the three fields named in the spec.
It is not scope creep — FR-038 already requires a timeout failure type and the
constitution requires the timeout to exist; making it configurable alongside the
interval is cheaper than hiding it as a constant.

---

## R-009: IPv4, IPv6 and NAT64

**Decision**: v1 probes over **IPv4**. A custom target's optional IPv6 address is
accepted, carried and exposed, but not probed. TCP and UDP probes resolve their
destination through `getaddrinfo` on the address literal rather than building a
`sockaddr_in` by hand.

**Rationale**: the `getaddrinfo` detail is what keeps this correct on
IPv6-only networks. On a NAT64/DNS64 network, Darwin's `getaddrinfo` synthesises
a routable IPv6 address from an IPv4 literal, so TCP and UDP probes keep working
where a hand-built `sockaddr_in` would fail outright — and App Store review
tests exactly that network. ICMP has no such synthesis: it would need a separate
ICMPv6 implementation with a different checksum computation.

**Consequence, documented rather than hidden**: on an IPv6-only network, TCP and
UDP monitoring works and ICMP monitoring returns
`UnsupportedCapabilityFailure` at start. That is the constitution's required
behaviour — a typed failure, never a silent substitution.

**Follow-up**: ICMPv6 support is a candidate for a later iteration. It is
recorded here rather than as a `ponytail:` comment because there is no code to
attach a comment to yet; the task list should carry it as an explicit
out-of-scope note.

---

## R-010: Address fallback within a target

**Decision**: a session starts on the target's primary IPv4 address. After
`consecutiveFailuresBeforeFallback` (fixed at 3) consecutive failed probes, and
only if the target exposes a secondary address, the prober switches to the
secondary and emits a `targetAddressChanged` event. It does not switch back
automatically for the life of the session.

**Rationale**: FR-004 gives every preset two addresses, and FR-005 lets a custom
target define one, so a fallback rule has to exist; three consecutive failures is
long enough not to fire on a single dropped packet and short enough to matter
within one default window. Not switching back avoids flapping between two
addresses on a marginal link, which would corrupt the latency aggregates the
session reports.

---

## R-011: Bounded stop time *(deferred from the spec)*

**Decision**: **500 ms.** On `stopSession`, or on the native stream handler's
`onCancel`, the controller cancels the scheduled probe, closes any in-flight
socket immediately, and stops emitting. The Dart side completes all three
streams.

**Rationale**: the socket close is synchronous and the scheduler is a single
repeating timer on a serial queue, so the real bound is dominated by the channel
round-trip; 500 ms is a comfortable ceiling that still leaves four times the
margin against the 2 s the spec's SC-005 allows.

**Listener accounting**: the auto-stop fires only on a **1 → 0** transition in
subscriber count. A session that has never been subscribed to keeps running,
which is what the spec's "no listeners" edge case requires. The three public
streams are views over one internal broadcast source, so the count is the sum
across all three and FR-036 holds — subscribing to any combination changes no
emitted value and starts no second session.

---

## R-012: Event throttling

**Decision**: two classes of event.

- **Edge-triggered, always emitted**: `monitoringStarted`, `monitoringStopped`,
  `healthChanged`, `connectivityLost`, `connectivityRestored`,
  `interfaceChanged`, `ipAddressChanged`, `targetAddressChanged`. These describe
  a transition, so they cannot repeat without something having actually changed.
- **Level-triggered, throttled**: `packetLossDetected`, `highJitterDetected`,
  `latencySpikeDetected`. A 30-second per-kind cooldown applies.

**Rationale**: FR-033 requires that a persistent condition not flood the stream,
but a blanket cooldown would swallow the state transitions a host needs to render
a correct timeline. Splitting by trigger type satisfies the requirement without
losing information — and the spike *count* remains exact in every metrics
emission regardless of how many spike events were suppressed.

---

## R-013: Precision and rounding

**Decision**: latency and jitter are `double` milliseconds rounded to one
decimal; packet loss is a `double` percent rounded to one decimal; uptime is a
Dart `Duration` and the host formats it. Values that cannot yet be computed are
`null`, not `0`.

**Rationale**: FR-025 requires documented precision and FR-027 forbids a
misleading zero. Nullable fields make "not yet available" unrepresentable-as-zero
at the type level, which is stronger than a documented sentinel and costs the
caller one `?`. Exposing `Duration` rather than a preformatted
`hours:minutes:seconds` string keeps localisation and formatting where they
belong — in the host's presentation layer, which plugin packages are forbidden to
have.

---

## R-014: Facade shape and the loss of the `const` constructor

**Decision**: `NetworkAnalyzer` becomes a non-`const` class holding an injected
`MonitoringController`. The three streams are instance getters on it.

**Rationale**: the spec puts the streams on the analyzer and enforces one
session at a time, so the analyzer must hold session state — which a `const`
constructor cannot. Constructor injection of the controller is what
`guidelines.md` mandates for testability, and it lets the facade tests run
against a fake with no platform channel at all.

**Impact**: `const NetworkAnalyzer()` stops compiling. Both packages are at
0.1.0 and unreleased, so this is a pre-1.0 adjustment rather than a break of a
published contract; the add-only rule of Principle II governs
`NetworkAnalyzerPlatform`, which is extended add-only here. The example app's
single call site is updated in the same change.

**Alternatives considered**:
- *Static/singleton session state behind a `const` facade*: rejected — global
  mutable state, untestable in parallel, and it makes the single-flight rule a
  process-wide accident rather than an object's invariant.
- *A separate `MonitoringSession` object returned by `start`*: rejected because
  the spec is explicit that starting returns `SessionData`. Worth revisiting if a
  future feature ever needs concurrent sessions, which FR-015 currently forbids.
