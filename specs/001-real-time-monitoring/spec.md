# Feature Specification: Real-time Monitoring

**Feature Branch**: `001-real-time-monitoring`

**Created**: 2026-08-24

**Status**: Draft

**Input**: User description: "Feature \"Real-time monitoring\". This feature needs to be capable of monitoring a connection in realtime and detect the type connection (Wi-Fi, mobile data, etc.) and IP address of the current network. [...] Ask me if any of the instructions are unclear"

## Overview

Real-time monitoring lets a host application observe the quality of a device's
network connection continuously, from the moment monitoring starts until it is
stopped. The host chooses **what** to monitor — the public internet through a
chosen host, or the local gateway discovered automatically — and **how** to
probe it. In return it receives a live description of the session, a continuous
flow of quality measurements, and a continuous flow of notable events.

This is the first of the four capabilities named in the constitution and
establishes the contract patterns the remaining three will follow.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Monitor internet quality with a known host (Priority: P1)

An application developer wants to show their users whether the internet
connection is healthy right now. They describe an internet monitor with a
preset public host and a probe protocol, start monitoring, and listen to a
continuous flow of quality measurements — latency, packet loss, jitter, spike
count, an overall health verdict, and running aggregates for the session.

**Why this priority**: This is the core value of the feature and the minimum
viable slice. Everything else in this spec enriches or varies this flow.

**Independent Test**: Configure an internet monitor against a preset host,
start it, and confirm that measurements arrive continuously, that each carries
the session description, and that stopping monitoring ends the flow.

**Acceptance Scenarios**:

1. **Given** a device with a working connection and an internet monitor
   configured with a preset host, **When** the host application starts
   monitoring, **Then** it receives a session description identifying the
   network interface type, the device's network IP address, the probe
   protocol, the monitor kind, the target that was reached, and the start
   instant.
2. **Given** monitoring is running, **When** the host application listens to
   the measurements flow, **Then** measurements arrive once per configured
   probe interval — one second unless the host chose otherwise — each carrying
   the session description plus
   current latency, packet loss, jitter, spike count, health verdict, elapsed
   uptime, and average, lowest and highest latency for the session.
3. **Given** monitoring is running, **When** the host application stops
   monitoring, **Then** the flows complete, no further measurements or events
   are produced, and all underlying probing ceases within a documented bounded
   time.
4. **Given** no monitoring session is running, **When** the host application
   requests the current session description, **Then** it is told plainly that
   there is no active session rather than receiving fabricated data.
5. **Given** a monitor configured without any tuning values, **When**
   monitoring starts, **Then** the documented default probe interval, sample
   window and health thresholds apply, and the developer supplies none of them.
6. **Given** a monitor configured with a custom probe interval, sample window
   or health thresholds, **When** monitoring starts, **Then** those values
   govern emission cadence, the rolling window and the health verdict, and any
   value left unset falls back to its default.

---

### User Story 2 - React to notable connection events (Priority: P2)

The developer wants to record and react to discrete moments — monitoring
started, packet loss detected, jitter climbed, a latency spike occurred, the
health verdict changed, the network interface switched from Wi-Fi to mobile
data. They listen to a separate flow of events, each timestamped in UTC with a
human-readable message, so they can render a log, raise a notification, or
persist a trail.

**Why this priority**: Independently valuable and independently testable, but
useless without a running session, so it ranks below P1.

**Independent Test**: Start a session under fixture conditions that trigger
each event type and confirm exactly the expected events are emitted, each
carrying the session description, a UTC timestamp and a message.

**Acceptance Scenarios**:

1. **Given** the host application listens to the events flow, **When**
   monitoring starts, **Then** a "monitoring started" event is emitted first.
2. **Given** monitoring is running, **When** probes are lost, jitter exceeds
   its threshold, or a latency spike occurs, **Then** a corresponding event is
   emitted carrying the session description, a UTC timestamp and a message
   describing what happened and the value that triggered it.
3. **Given** an event was emitted, **When** the host application reads its
   timestamp, **Then** the timestamp is in UTC so the host can convert it to
   the viewer's local time.
4. **Given** monitoring is running, **When** the health verdict changes from
   one level to another, **Then** an event records the transition, including
   the previous and new verdict.

---

### User Story 3 - Monitor the local gateway without knowing its address (Priority: P2)

The developer wants to distinguish "the internet is down" from "the local
network is down". They describe a gateway monitor with only a probe protocol;
the plugin discovers the current network's gateway address itself and probes
it.

**Why this priority**: Equal footing with events for diagnostic value, and
independently testable, but the internet path is the more common need.

**Independent Test**: Start a gateway monitor with no address supplied and
confirm the resolved gateway address appears in the session description and
that measurements flow against it.

**Acceptance Scenarios**:

1. **Given** a device attached to a network, **When** the host application
   starts a gateway monitor without supplying any address, **Then** the
   session description reports the automatically discovered gateway address as
   the target reached.
2. **Given** the gateway address cannot be discovered, **When** the host
   application starts a gateway monitor, **Then** starting fails with a typed
   error explaining that discovery failed, and no session, measurements or
   events are produced.
3. **Given** a gateway monitor is being configured, **When** an unsupported
   probe protocol is supplied, **Then** configuration is rejected before any
   probing begins.

---

### User Story 4 - Choose or define the target host (Priority: P3)

The developer wants convenience for common cases and freedom for uncommon ones.
They pick a bundled preset — Google, Cloudflare, or OpenDNS, each with a primary
and a secondary address — or they define their own target with a name, a
required IPv4 address, and an optional IPv6 address, for example their own
corporate endpoint.

**Why this priority**: Enriches P1 rather than enabling it; P1 is satisfiable
with presets alone.

**Independent Test**: Start sessions against each preset and against a custom
target, and confirm the session description names the target actually used.

**Acceptance Scenarios**:

1. **Given** the bundled presets, **When** the host application selects one,
   **Then** it obtains a display name and both of that provider's addresses
   without hard-coding any address itself.
2. **Given** a custom target with a name and an IPv4 address, **When**
   monitoring starts, **Then** probing targets that address and the session
   description names it.
3. **Given** a custom target definition with a malformed or missing IPv4
   address, **When** it is constructed, **Then** it is rejected with a clear
   explanation before any monitoring can be started with it.
4. **Given** a target exposes a secondary or IPv6 address, **When** the primary
   address is unreachable, **Then** the documented fallback behaviour applies
   and the session description reports which address was actually reached.

---

### User Story 5 - Consume measurements and events as one flow (Priority: P3)

The developer building a single timeline view does not want to merge two flows
by hand. They subscribe to one combined flow that carries both measurements and
events in the order they occurred, each item clearly identifiable as one or the
other.

**Why this priority**: Pure convenience over P1 and P2; nothing is impossible
without it.

**Independent Test**: Subscribe only to the combined flow and confirm it
carries every item the two individual flows carry, in emission order, each
distinguishable by kind.

**Acceptance Scenarios**:

1. **Given** monitoring is running, **When** the host application listens only
   to the combined flow, **Then** it receives every measurement and every event
   in the order they were produced.
2. **Given** the combined flow delivers an item, **When** the host application
   inspects it, **Then** it can determine without ambiguity whether the item is
   a measurement or an event, and read the corresponding data.

---

### User Story 6 - Survive network changes mid-session (Priority: P3)

The device moves from Wi-Fi to mobile data, or the IP address is reassigned.
The developer expects the session to keep reporting truthfully rather than
silently reporting stale facts.

**Why this priority**: Correctness safeguard around P1, exercised less often
than the main flow but essential to trustworthiness.

**Independent Test**: Simulate an interface change and an address change during
a session and confirm the reported facts update and the corresponding events
are emitted.

**Acceptance Scenarios**:

1. **Given** a session started on Wi-Fi, **When** the device switches to mobile
   data, **Then** subsequent session descriptions report the new interface type
   and address, and an event records the change.
2. **Given** connectivity is lost entirely, **When** probes cannot be sent,
   **Then** the health verdict becomes the "unknown" level, an event records
   the loss, and the session remains alive so it can report recovery.
3. **Given** connectivity returns, **When** probes succeed again, **Then** an
   event records the recovery and measurements resume.

---

### Edge Cases

- **Starting twice**: a second start request while a session is running is
  rejected with a typed error; the running session is unaffected.
- **Stopping when idle**: stopping with no session running is a harmless no-op
  and never an error the host must guard against.
- **No listeners**: a session with no subscribers still runs, but when the last
  subscriber cancels, all probing ceases within a documented bounded time.
- **Late subscriber**: a subscriber attaching after start receives measurements
  from that point forward, and can read the session description separately to
  learn what it missed.
- **Airplane mode at start**: starting with no connectivity produces the
  documented outcome — either a typed start failure or a live session whose
  health is "unknown" — never a fabricated healthy session.
- **Probe protocol unsupported on the platform**: raw-socket probing that a
  platform forbids yields a typed "unsupported" error at configuration or start
  time, never a silently substituted protocol.
- **Permission denied**: a missing or denied OS permission yields a typed
  permission error with remediation guidance and no session.
- **Every probe failing**: sustained total loss reports 100% packet loss and
  the most severe health level rather than stalling or emitting nothing.
- **Insufficient samples**: before enough samples exist to compute jitter,
  packet loss or averages, the health verdict is "unknown" and derived values
  are reported as not-yet-available rather than as zero.
- **First measurement**: with a single sample, average, lowest and highest
  latency all equal that sample and jitter is not-yet-available.
- **Clock changes**: the device clock changing during a session does not
  distort latency, jitter, uptime or spike detection.
- **Extreme tuning values**: a probe interval below the documented minimum, a
  sample window smaller than one sample, or a critical threshold below its
  unstable threshold is rejected at construction, before any session exists.
- **Very long probe interval**: a large interval produces correspondingly
  infrequent measurements without stalling the flows or delaying an explicit
  stop beyond its bounded time.
- **Window not yet full**: while fewer samples than the window size exist,
  packet loss and jitter are computed over what is available, or reported as
  not-yet-available, per the documented rule — never padded with assumed
  successes.
- **Long sessions**: a session running for days keeps reporting correct
  aggregates and uptime without unbounded memory growth.
- **Target address change**: a custom target whose primary address becomes
  unreachable follows the documented fallback and records the switch as an
  event.
- **Host app backgrounded**: the documented behaviour when the OS suspends the
  application is stated, and on resume the session either continues correctly
  or reports that it was interrupted.

## Requirements *(mandatory)*

### Functional Requirements

#### Configuring a monitor

- **FR-001**: The system MUST let the host application describe what to monitor
  as one of exactly two monitor kinds: an **internet monitor** or a **gateway
  monitor**.
- **FR-002**: An internet monitor MUST be configurable with a probe protocol
  from {TCP, UDP, ICMP} and a target host.
- **FR-003**: A gateway monitor MUST be configurable with a probe protocol from
  {TCP, ICMP} and MUST NOT accept a target host; UDP MUST be rejected.
- **FR-004**: The system MUST provide bundled target presets — Google
  (8.8.8.8, 8.8.4.4), Cloudflare (1.1.1.1, 1.0.0.1) and OpenDNS
  (208.67.222.222, 208.67.220.220) — each exposing a display name and both
  addresses.
- **FR-005**: The system MUST let the host application define a custom target
  with a host name and a required IPv4 address, and an optional IPv6 address.
- **FR-006**: The system MUST reject invalid monitor configurations — malformed
  addresses, missing required fields, protocol/kind mismatches — at
  construction or at start, before any probing occurs.
- **FR-007**: A gateway monitor MUST determine its target automatically by
  discovering the current network's gateway address, and MUST NOT require the
  host application to supply or discover it.
- **FR-008**: Monitor configurations MUST be immutable once constructed;
  changing what is monitored requires stopping and starting a new session.
- **FR-009**: The system MUST let the host application configure the probe
  interval and the rolling sample-window size used for packet loss and jitter,
  and MUST supply documented defaults — a 1 second probe interval and a
  10 sample window — so that neither has to be supplied for a monitor to start.
- **FR-010**: The system MUST let the host application optionally override the
  thresholds that map measurements to each health verdict, and MUST supply
  documented defaults so that no thresholds have to be supplied for a monitor
  to start. An omitted individual threshold MUST fall back to its default.
- **FR-011**: Probe interval, sample-window size and any supplied thresholds
  MUST be validated against documented bounds at construction, and out-of-range
  or nonsensical values (non-positive interval, window smaller than one sample,
  a critical threshold below its unstable threshold) MUST be rejected before
  any monitoring can be started with them.

#### Starting and stopping

- **FR-012**: The system MUST expose a start operation that takes exactly one
  monitor configuration and returns either a session description or a typed
  failure — it MUST NOT surface raw platform exceptions.
- **FR-013**: A returned session description MUST report: the network
  interface type, the probe protocol in use, the device's current network IP
  address, the start instant, the target actually reached, and the monitor
  kind.
- **FR-014**: The network interface type MUST distinguish at minimum Ethernet,
  Wi-Fi, and mobile data by generation where the platform exposes it (5G, 4G,
  3G, 2G), plus explicit values for other, none, and unknown.
- **FR-015**: The system MUST allow at most one monitoring session at a time,
  of exactly one monitor kind; a start request while a session is running MUST
  be rejected with a typed failure and MUST NOT disturb the running session.
  Running an internet monitor and a gateway monitor concurrently is out of
  scope; switching between them requires stopping and starting.
- **FR-016**: The system MUST expose a stop operation that ends the session,
  completes all flows, and halts all underlying probing within a documented
  bounded time. Stopping when idle MUST be a safe no-op.
- **FR-017**: The system MUST expose the current session description on demand
  while a session is running, and MUST report the absence of a session
  explicitly when none is running.
- **FR-018**: When the last subscriber to the flows cancels, all underlying
  probing MUST stop within the same documented bounded time as an explicit
  stop.

#### Measurements

- **FR-019**: The system MUST expose a continuous flow of measurements,
  emitting one measurement per completed probe for as long as the session runs,
  so that emission cadence equals the configured probe interval.
- **FR-020**: Packet loss and jitter MUST be computed over a rolling window of
  the most recent samples, sized by the configured sample-window size, so that
  both values recover once conditions improve. Average, lowest and highest
  latency, spike count and uptime MUST be cumulative for the whole session.
- **FR-021**: Each measurement MUST carry the session description together
  with: current latency in milliseconds, packet loss as a percentage, jitter in
  milliseconds, spike count, health verdict, elapsed uptime, and average,
  lowest and highest latency for the session.
- **FR-022**: The health verdict MUST be one of exactly four levels — stable,
  unstable, critical, unknown — with published definitions: **stable** =
  measurements steady and within expected ranges; **unstable** = occasional
  spikes or variation that may degrade performance; **critical** = very high
  latency or packet loss, or frequent drops, with severe impact; **unknown** =
  insufficient data or the target is unreachable.
- **FR-023**: The thresholds that map measurements to each health verdict MUST
  be applied deterministically: the same sample sequence and the same
  thresholds always yield the same verdict.
- **FR-024**: Uptime MUST report elapsed session duration in hours, minutes and
  seconds, measured so that device clock changes cannot distort it.
- **FR-025**: Latency MUST be reported in milliseconds, packet loss as a
  percentage, and jitter in milliseconds, each with documented precision and
  rounding rules.
- **FR-026**: A "spike" MUST have a single published definition, and the spike
  count MUST be the number of spikes observed since the session started.
- **FR-027**: Before enough samples exist to compute a derived value, that
  value MUST be reported as not-yet-available rather than as a misleading zero.
- **FR-028**: Measurement values MUST derive only from probes actually
  performed; the system MUST NOT interpolate, estimate or fabricate any
  reported value.

#### Events

- **FR-029**: The system MUST expose a continuous flow of events, separate from
  the measurements flow.
- **FR-030**: Each event MUST carry the session description, a UTC timestamp,
  a machine-readable event kind, and a human-readable message.
- **FR-031**: The system MUST emit events at minimum for: monitoring started,
  monitoring stopped, packet loss detected, high jitter detected, latency spike
  detected, health verdict changed, connectivity lost, connectivity restored,
  network interface changed, and IP address changed.
- **FR-032**: Event timestamps MUST be in UTC so the host application can
  convert them to the viewer's local time.
- **FR-033**: Repeated occurrences of the same condition MUST follow documented
  emission rules so that a persistent condition does not flood the flow.

#### Combined flow

- **FR-034**: The system MUST expose a third flow carrying both measurements
  and events in the order they were produced.
- **FR-035**: Each item on the combined flow MUST be unambiguously
  identifiable as either a measurement or an event, with exhaustive handling
  possible by the host application.
- **FR-036**: Subscribing to any combination of the three flows MUST NOT change
  the values any of them emit, and MUST NOT start a second session.

#### Reporting and failure

- **FR-037**: Every fallible operation MUST report success or a typed failure;
  no exception may reach the host application.
- **FR-038**: Failure types MUST at minimum distinguish: permission denied,
  unsupported platform capability, gateway discovery failure, invalid
  configuration, target unreachable, timeout, and a session already running.
- **FR-039**: A platform that cannot honour a requested probe protocol MUST
  report an unsupported-capability failure and MUST NOT silently substitute a
  different protocol.
- **FR-040**: A denied OS permission MUST produce a permission failure carrying
  remediation guidance, and MUST NOT crash the host application.
- **FR-041**: Monitoring MUST NOT collect, store or transmit personally
  identifying information or persistent device identifiers, and MUST NOT
  persist anything durably in this feature.
- **FR-042**: Monitoring MUST NOT block the host application's UI, and its idle
  overhead MUST be documented.

### Key Entities *(include if data involved)*

- **Monitor configuration**: what the host application wants monitored. Exactly
  two variants — internet (probe protocol plus target host) and gateway (probe
  protocol only, target discovered). Immutable; built by the host application.
- **Target host**: where internet probes are sent. Either one of the bundled
  presets (name plus primary and secondary addresses) or a custom definition
  (host name, required IPv4, optional IPv6).
- **Probe protocol**: how probes are sent — TCP, UDP or ICMP. Gateway monitors
  accept only TCP and ICMP.
- **Monitor options**: the tuning attached to a monitor configuration — probe
  interval and rolling sample-window size — both optional, both with documented
  defaults (1 second, 10 samples).
- **Health thresholds**: the optional cutoffs mapping latency, packet loss and
  jitter onto the four health verdicts. Fully defaulted; a host application may
  override all, some, or none.
- **Session description**: the facts about the running session — network
  interface type, probe protocol, device IP address, start instant, target
  reached, monitor kind. Attached to every measurement and every event so each
  item is self-describing.
- **Measurement**: one snapshot of connection quality — session description,
  latency, packet loss, jitter, spike count, health verdict, uptime, and
  average, lowest and highest latency.
- **Health verdict**: stable, unstable, critical, or unknown, as defined in
  FR-022.
- **Event**: one notable moment — session description, UTC timestamp, event
  kind, message.
- **Network interface type**: Ethernet, Wi-Fi, mobile data by generation
  (5G/4G/3G/2G), other, none, unknown.
- **Failure**: a typed, non-throwing description of why an operation did not
  succeed, carrying a short message and optional detail.

### Naming Recommendations *(the description invited suggestions)*

The description left three names open. Recommended, with rationale:

| Concept | Suggested name | Why |
|---------|----------------|-----|
| Measurements flow | `metrics` | The `connection` prefix is redundant — everything in this feature concerns the connection. Short, and reads well at the call site. |
| Measurement bundle | `ConnectionMetrics` | Keeps the qualifier on the type, where it disambiguates, rather than on the flow. |
| Events flow | `events` | "Registered logs" implies persistence, which this feature explicitly does not do. These are live events; the host application decides whether to log them. |
| Event item | `MonitorEvent` | Names what it is, not what the host might do with it. |
| Combined flow | `updates` | Neutral umbrella for "anything new from the session". |
| Combined item | `MonitorUpdate` | A closed set of exactly two variants — a metrics update and an event update — so the host application can handle it exhaustively. |
| Session facts | `SessionData` | As proposed in the description; kept. |
| Tuning | `MonitorOptions` | Groups probe interval and sample window so the monitor configuration keeps two fields, not four. |
| Health cutoffs | `HealthThresholds` | Separate from `MonitorOptions` because it is overridden far less often and has its own defaults. |

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A developer can start monitoring and receive the first
  measurement within 3 seconds of starting, on a working connection.
- **SC-002**: Measurements arrive at the configured probe interval with no gap
  exceeding twice that interval, across a continuous one-hour session on a
  stable connection, at both the default interval and a custom one.
- **SC-003**: 100% of documented failure situations — denied permission,
  unsupported protocol, gateway discovery failure, invalid configuration,
  unreachable target, timeout, session already running — are reported as typed
  failures, and 0% surface as unhandled exceptions.
- **SC-004**: The same recorded sample sequence and the same thresholds
  produce identical latency, packet loss, jitter, spike count and health
  verdict every time they are replayed — verifiable without a live network.
- **SC-005**: Within 2 seconds of stopping a session, or of the last subscriber
  cancelling, no further probing occurs and no further items are emitted.
- **SC-006**: A session running continuously for 24 hours reports correct
  uptime and aggregates with no unbounded growth in memory or in retained
  samples.
- **SC-007**: An interface change (Wi-Fi to mobile data) is reflected in the
  reported session facts and recorded as an event within one measurement
  cadence of the switch.
- **SC-008**: Idle overhead of a running session stays within its documented
  budget and the host application's interface remains responsive throughout,
  on both supported platforms.
- **SC-009**: A developer can start monitoring against a preset target in five
  or fewer statements, without hard-coding any IP address and without supplying
  a probe interval, sample window or any health threshold.
- **SC-010**: Android and iOS produce the same reported values, within the
  documented tolerance, for the same conditions and configuration.

## Assumptions

- **Session facts**: "IP address" in the session description is the device's
  address on the current network; "target reached" is the endpoint probes are
  actually sent to (the resolved gateway address, or the target host address in
  use). These are two distinct fields.
- **Scope boundary**: this feature measures and reports only. Persistence,
  charting, notifications, throughput measurement and the diagnostic tools are
  out of scope; the host application owns all presentation and storage.
- **Single session**: the constitution's single-flight rule applies, so at most
  one monitoring session of one monitor kind exists at a time. Running internet
  and gateway monitors concurrently is explicitly out of scope; a host that
  needs both alternates between them.
- **Tuning is optional**: probe interval, sample window and health thresholds
  are all defaulted. The defaults — 1 second and 10 samples — are the values a
  host gets by supplying nothing, and the concrete threshold numbers are fixed
  during planning and published in the API documentation.
- **Window semantics**: packet loss and jitter reflect only the most recent
  window and therefore recover; averages, extremes, spike count and uptime span
  the whole session and never reset while it runs.
- **No accounts**: the feature is device-local and auth-agnostic, per the
  constitution.
- **Preset addresses**: the three bundled providers' addresses are the
  well-known public ones listed in FR-004 and are treated as stable constants.
- **IPv6**: optional throughout. IPv4 is required for a custom target; IPv6 is
  used only where the platform and the target both support it.
- **Platform capability limits**: where a platform restricts raw-socket
  probing, that limit is surfaced as a typed unsupported-capability failure and
  documented, never emulated with a substituted protocol.
- **Permissions**: the exact OS permissions and entitlements needed to read the
  network interface type, the device address and the gateway address are
  documented per platform, and nothing beyond that set is requested.
- **Timing**: elapsed-time values (latency, jitter, uptime, spike detection)
  come from a monotonic source; only the event timestamp uses wall-clock UTC,
  because it is the value the host application shows to a person.
- **Background behaviour**: the OS may suspend a backgrounded application; the
  resulting behaviour is documented rather than guaranteed to continue.

## Dependencies

- The platform contract package, which must declare every capability above
  before either platform implements it.
- The existing `Result` / `Failure` core, reused unchanged for all fallible
  operations.
- Platform network APIs for interface type, device address, gateway discovery
  and probe transmission on Android and iOS.
