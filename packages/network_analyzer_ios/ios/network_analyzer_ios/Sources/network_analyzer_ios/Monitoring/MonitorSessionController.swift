import Foundation

/// Owns the probe loop and every piece of mutable session state.
///
/// All state is confined to one serial `DispatchQueue`, which is what makes
/// the lifecycle safe without locks. Timing is monotonic throughout; the only
/// wall clock reading is the session's start instant, which exists to be
/// shown to a person.
///
/// The controller emits raw samples and nothing derived. Packet loss,
/// jitter, spikes and the health verdict are computed once in Dart so the two
/// platforms cannot drift apart.
final class MonitorSessionController {
  private let inspector: NetworkInspector
  private let proberFactory: (ProtocolMessage) -> Prober
  private let queue: DispatchQueue
  private let monotonic: () -> Int64
  private let wallClockMillis: () -> Int64

  private var session: SessionDataMessage?
  private var prober: Prober?
  private var timer: DispatchSourceTimer?
  private var sink: ((MonitorSignalMessage) -> Void)?

  private var sequence = 0
  private var startedAtNanos: Int64 = 0
  private var consecutiveFailures = 0
  private var targetAddress = ""
  private var fallbackAddress: String?
  private var usedFallback = false
  private var port = 0
  private var timeoutMillis = 0
  private var lastFacts: NetworkFacts?

  private static let failuresBeforeFallback = 3
  private static let gatewayTargetName = "Gateway"

  init(
    inspector: NetworkInspector,
    proberFactory: @escaping (ProtocolMessage) -> Prober,
    queue: DispatchQueue = DispatchQueue(label: "network_analyzer.monitoring"),
    monotonic: @escaping () -> Int64 = monotonicNanos,
    wallClockMillis: @escaping () -> Int64 = {
      Int64(Date().timeIntervalSince1970 * 1000)
    }
  ) {
    self.inspector = inspector
    self.proberFactory = proberFactory
    self.queue = queue
    self.monotonic = monotonic
    self.wallClockMillis = wallClockMillis
  }

  /// The running session, or nil when none is running.
  func currentSession() -> SessionDataMessage? {
    session
  }

  /// Routes emitted signals to the event channel sink.
  func attachSink(_ sink: ((MonitorSignalMessage) -> Void)?) {
    self.sink = sink
  }

  /// Starts probing and returns the facts about the new session.
  ///
  /// Throws a `PigeonError` carrying one of the `MonitorErrors` codes when a
  /// session is already running, when the configuration is invalid, or when
  /// a gateway target cannot be discovered. The Dart side turns each into a
  /// typed failure.
  func startSession(_ config: MonitorConfigMessage) throws -> SessionDataMessage {
    if session != nil {
      throw PigeonError(
        code: MonitorErrors.sessionAlreadyRunning,
        message: "A monitoring session is already running.",
        details: nil)
    }
    if config.kind == .gateway, config.probeProtocol == .udp {
      throw PigeonError(
        code: MonitorErrors.invalidConfiguration,
        message: "A gateway monitor accepts only TCP and ICMP.",
        details: nil)
    }

    let facts = inspector.read()
    if config.probeProtocol == .icmp, facts.deviceIpAddress.isEmpty {
      // No IPv4 address means an IPv6-only network. TCP and UDP still work
      // there because getaddrinfo synthesises a NAT64 address from an IPv4
      // literal, but an ICMPv6 echo needs a different checksum over a
      // pseudo-header, which this version does not implement. Say so rather
      // than silently probing with another protocol.
      throw PigeonError(
        code: MonitorErrors.unsupportedCapability,
        message: "ICMP monitoring requires IPv4; this network is IPv6-only.",
        details: nil)
    }
    let resolved = try resolveTarget(config, facts: facts)
    let started = SessionDataMessage(
      interfaceType: facts.interfaceType,
      probeProtocol: config.probeProtocol,
      kind: config.kind,
      deviceIpAddress: facts.deviceIpAddress,
      targetAddress: resolved,
      targetName: config.targetName ?? MonitorSessionController.gatewayTargetName,
      startedAtUtcMillis: wallClockMillis())

    session = started
    lastFacts = facts
    targetAddress = resolved
    fallbackAddress = config.fallbackIPv4
    usedFallback = false
    port = Int(config.port)
    timeoutMillis = Int(config.probeTimeoutMillis)
    sequence = 0
    consecutiveFailures = 0
    startedAtNanos = monotonic()
    prober = proberFactory(config.probeProtocol)

    let source = DispatchSource.makeTimerSource(queue: queue)
    source.schedule(
      deadline: .now(),
      repeating: .milliseconds(Int(config.probeIntervalMillis)))
    source.setEventHandler { [weak self] in self?.probeOnce() }
    timer = source
    source.resume()
    return started
  }

  /// Stops probing and clears all session state.
  ///
  /// A no-op when nothing is running, so callers never have to guard it. The
  /// timer is cancelled and the socket closed immediately, so probing ceases
  /// well inside the documented 500 ms bound.
  func stopSession() {
    timer?.cancel()
    timer = nil
    prober?.close()
    prober = nil
    session = nil
    lastFacts = nil
  }

  private func resolveTarget(
    _ config: MonitorConfigMessage, facts: NetworkFacts
  ) throws -> String {
    switch config.kind {
    case .internet:
      guard let target = config.targetIPv4 else {
        throw PigeonError(
          code: MonitorErrors.invalidConfiguration,
          message: "An internet monitor requires a target address.",
          details: nil)
      }
      return target
    case .gateway:
      guard let gateway = facts.gatewayAddress else {
        throw PigeonError(
          code: MonitorErrors.gatewayDiscoveryFailed,
          message: "No default route is available on the current network.",
          details: nil)
      }
      return gateway
    }
  }

  func probeOnce() {
    guard let activeProber = prober else {
      return
    }
    let result = activeProber.probe(
      address: targetAddress, port: port, timeoutMillis: timeoutMillis)
    let current = sequence
    sequence += 1
    emit(
      ProbeSampleMessage(
        sequence: Int64(current),
        roundTripMicros: result.roundTripMicros,
        outcome: result.outcome,
        elapsedMicros: (monotonic() - startedAtNanos) / 1_000))
    trackFailures(result.outcome)
    reportNetworkChange()
  }

  private func trackFailures(_ outcome: OutcomeMessage) {
    guard outcome != .success else {
      consecutiveFailures = 0
      return
    }
    consecutiveFailures += 1
    guard !usedFallback, let fallback = fallbackAddress,
      consecutiveFailures >= MonitorSessionController.failuresBeforeFallback
    else {
      return
    }
    // Switch once and never switch back: flapping between two addresses
    // would corrupt the session's latency aggregates.
    usedFallback = true
    targetAddress = fallback
    consecutiveFailures = 0
    session?.targetAddress = fallback
    emit(
      NetworkStateMessage(
        interfaceType: lastFacts?.interfaceType ?? .unknown,
        deviceIpAddress: nil,
        targetAddress: fallback))
  }

  private func reportNetworkChange() {
    let facts = inspector.read()
    if let previous = lastFacts,
      previous.interfaceType == facts.interfaceType,
      previous.deviceIpAddress == facts.deviceIpAddress
    {
      return
    }
    lastFacts = facts
    session?.interfaceType = facts.interfaceType
    session?.deviceIpAddress = facts.deviceIpAddress
    emit(
      NetworkStateMessage(
        interfaceType: facts.interfaceType,
        deviceIpAddress: facts.deviceIpAddress,
        targetAddress: nil))
  }

  private func emit(_ signal: MonitorSignalMessage) {
    guard let sink = sink else {
      return
    }
    DispatchQueue.main.async { sink(signal) }
  }
}
