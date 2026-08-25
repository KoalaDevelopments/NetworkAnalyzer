import XCTest

@testable import network_analyzer_ios

private final class FakeInspector: NetworkInspector {
  var facts: NetworkFacts

  init(facts: NetworkFacts) {
    self.facts = facts
  }

  func read() -> NetworkFacts {
    facts
  }
}

private final class FakeProber: Prober {
  private var results: [ProbeResult]
  var closed = false
  var probed: [(String, Int, Int)] = []

  init(results: [ProbeResult] = []) {
    self.results = results
  }

  func probe(address: String, port: Int, timeoutMillis: Int) -> ProbeResult {
    probed.append((address, port, timeoutMillis))
    return results.isEmpty ? .timeout() : results.removeFirst()
  }

  func close() {
    closed = true
  }
}

final class MonitorSessionControllerTests: XCTestCase {
  private var now: Int64 = 0

  private let wifi = NetworkFacts(
    interfaceType: .wifi,
    deviceIpAddress: "192.168.1.42",
    gatewayAddress: "192.168.1.1")

  private func makeController(
    inspector: NetworkInspector,
    prober: Prober
  ) -> MonitorSessionController {
    MonitorSessionController(
      inspector: inspector,
      proberFactory: { _ in prober },
      queue: DispatchQueue(label: "test"),
      monotonic: { self.now },
      wallClockMillis: { 1_787_654_321_000 })
  }

  private func internetConfig(
    fallback: String? = nil,
    probeProtocol: ProtocolMessage = .tcp
  ) -> MonitorConfigMessage {
    MonitorConfigMessage(
      probeProtocol: probeProtocol,
      kind: .internet,
      targetIPv4: "8.8.8.8",
      fallbackIPv4: fallback,
      targetName: "Google Public DNS",
      port: 53,
      probeIntervalMillis: 200,
      probeTimeoutMillis: 200)
  }

  private func gatewayConfig(
    probeProtocol: ProtocolMessage = .tcp
  ) -> MonitorConfigMessage {
    MonitorConfigMessage(
      probeProtocol: probeProtocol,
      kind: .gateway,
      targetIPv4: nil,
      fallbackIPv4: nil,
      targetName: nil,
      port: 80,
      probeIntervalMillis: 200,
      probeTimeoutMillis: 200)
  }

  func testStartSessionReportsTheFactsAboutTheNewSession() throws {
    let controller = makeController(
      inspector: FakeInspector(facts: wifi), prober: FakeProber())

    let session = try controller.startSession(internetConfig())

    XCTAssertEqual(session.interfaceType, .wifi)
    XCTAssertEqual(session.deviceIpAddress, "192.168.1.42")
    XCTAssertEqual(session.targetAddress, "8.8.8.8")
    XCTAssertEqual(session.targetName, "Google Public DNS")
    XCTAssertEqual(session.startedAtUtcMillis, 1_787_654_321_000)
    controller.stopSession()
  }

  func testStartSessionIsRejectedWhileASessionIsRunning() throws {
    let controller = makeController(
      inspector: FakeInspector(facts: wifi), prober: FakeProber())
    let first = try controller.startSession(internetConfig())

    XCTAssertThrowsError(try controller.startSession(internetConfig())) { error in
      XCTAssertEqual(
        (error as? PigeonError)?.code, MonitorErrors.sessionAlreadyRunning)
    }
    // The running session is untouched by the rejected request.
    XCTAssertEqual(controller.currentSession()?.targetAddress, first.targetAddress)
    controller.stopSession()
  }

  func testStartSessionDiscoversTheGatewayWhenNoAddressIsSupplied() throws {
    let controller = makeController(
      inspector: FakeInspector(facts: wifi), prober: FakeProber())

    let session = try controller.startSession(gatewayConfig())

    XCTAssertEqual(session.targetAddress, "192.168.1.1")
    XCTAssertEqual(session.targetName, "Gateway")
    controller.stopSession()
  }

  func testStartSessionFailsWhenNoDefaultRouteExists() {
    let facts = NetworkFacts(
      interfaceType: .wifi, deviceIpAddress: "192.168.1.42", gatewayAddress: nil)
    let controller = makeController(
      inspector: FakeInspector(facts: facts), prober: FakeProber())

    XCTAssertThrowsError(try controller.startSession(gatewayConfig())) { error in
      XCTAssertEqual(
        (error as? PigeonError)?.code, MonitorErrors.gatewayDiscoveryFailed)
    }
    XCTAssertNil(controller.currentSession())
  }

  func testStartSessionRejectsUdpForAGatewayMonitor() {
    let controller = makeController(
      inspector: FakeInspector(facts: wifi), prober: FakeProber())

    XCTAssertThrowsError(
      try controller.startSession(gatewayConfig(probeProtocol: .udp))
    ) { error in
      XCTAssertEqual(
        (error as? PigeonError)?.code, MonitorErrors.invalidConfiguration)
    }
  }

  func testProbeOnceEmitsOneSamplePerProbeIncludingLosses() throws {
    var signals: [MonitorSignalMessage] = []
    let expectation = expectation(description: "two samples")
    expectation.expectedFulfillmentCount = 2
    let controller = makeController(
      inspector: FakeInspector(facts: wifi),
      prober: FakeProber(results: [.success(20_000), .timeout()]))
    controller.attachSink { signal in
      if signal is ProbeSampleMessage {
        signals.append(signal)
        expectation.fulfill()
      }
    }
    _ = try controller.startSession(internetConfig())

    now = 1_000_000_000
    controller.probeOnce()
    now = 2_000_000_000
    controller.probeOnce()
    wait(for: [expectation], timeout: 2)

    let samples = signals.compactMap { $0 as? ProbeSampleMessage }
    XCTAssertEqual(samples.count, 2)
    XCTAssertEqual(samples[0].sequence, 0)
    XCTAssertEqual(samples[0].outcome, .success)
    XCTAssertEqual(samples[0].roundTripMicros, 20_000)
    XCTAssertEqual(samples[1].sequence, 1)
    XCTAssertEqual(samples[1].outcome, .timeout)
    XCTAssertNil(samples[1].roundTripMicros)
    controller.stopSession()
  }

  func testProbeOnceSwitchesToTheFallbackAfterThreeConsecutiveFailures() throws {
    let prober = FakeProber()
    let controller = makeController(
      inspector: FakeInspector(facts: wifi), prober: prober)
    _ = try controller.startSession(internetConfig(fallback: "8.8.4.4"))

    for _ in 0..<3 {
      controller.probeOnce()
    }

    XCTAssertEqual(controller.currentSession()?.targetAddress, "8.8.4.4")
    controller.probeOnce()
    XCTAssertEqual(prober.probed.last?.0, "8.8.4.4")
    controller.stopSession()
  }

  func testStopSessionClearsTheSessionAndClosesTheProber() throws {
    let prober = FakeProber()
    let controller = makeController(
      inspector: FakeInspector(facts: wifi), prober: prober)
    _ = try controller.startSession(internetConfig())
    XCTAssertNotNil(controller.currentSession())

    controller.stopSession()

    XCTAssertNil(controller.currentSession())
    XCTAssertTrue(prober.closed)
  }

  func testStopSessionIsANoOpWhenNothingIsRunning() {
    let controller = makeController(
      inspector: FakeInspector(facts: wifi), prober: FakeProber())

    controller.stopSession()
    controller.stopSession()

    XCTAssertNil(controller.currentSession())
  }

  func testStartSessionRejectsIcmpOnAnIpv6OnlyNetwork() {
    // No IPv4 address is what an IPv6-only network looks like here.
    let facts = NetworkFacts(
      interfaceType: .wifi, deviceIpAddress: "", gatewayAddress: "192.168.1.1")
    let controller = makeController(
      inspector: FakeInspector(facts: facts), prober: FakeProber())

    XCTAssertThrowsError(
      try controller.startSession(internetConfig(probeProtocol: .icmp))
    ) { error in
      XCTAssertEqual(
        (error as? PigeonError)?.code, MonitorErrors.unsupportedCapability)
    }
    XCTAssertNil(controller.currentSession())
  }

  func testStartSessionAllowsTcpOnAnIpv6OnlyNetwork() throws {
    let facts = NetworkFacts(
      interfaceType: .wifi, deviceIpAddress: "", gatewayAddress: "192.168.1.1")
    let controller = makeController(
      inspector: FakeInspector(facts: facts), prober: FakeProber())

    let session = try controller.startSession(internetConfig())

    XCTAssertEqual(session.targetAddress, "8.8.8.8")
    controller.stopSession()
  }
}
