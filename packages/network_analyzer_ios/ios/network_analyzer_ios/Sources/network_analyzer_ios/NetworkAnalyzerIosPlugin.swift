import Flutter

/// iOS entry point of the network_analyzer plugin.
///
/// Exposes the pigeon-generated `MonitoringHostApi` over the engine's binary
/// messenger, plus the monitoring signal event channel. The wire layer lives
/// in Monitoring.g.swift, generated from pigeons/ — never hand-write channel
/// code (constitution, Principle II).
public class NetworkAnalyzerIosPlugin: NSObject, FlutterPlugin, MonitoringHostApi {
  private var controller: MonitorSessionController?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = NetworkAnalyzerIosPlugin()

    let sessionController = MonitorSessionController(
      inspector: DarwinNetworkInspector(),
      proberFactory: NetworkAnalyzerIosPlugin.proberFor)
    instance.controller = sessionController
    MonitoringHostApiSetup.setUp(
      binaryMessenger: registrar.messenger(), api: instance)
    StreamMonitorSignalsStreamHandler.register(
      with: registrar.messenger(),
      streamHandler: MonitorStreamHandler(controller: sessionController))
  }

  func startSession(config: MonitorConfigMessage) throws -> SessionDataMessage {
    guard let controller = controller else {
      throw PigeonError(
        code: "NOT_ATTACHED",
        message: "The plugin is not attached to a Flutter engine.",
        details: nil)
    }
    return try controller.startSession(config)
  }

  func stopSession() throws {
    controller?.stopSession()
  }

  func currentSession() throws -> SessionDataMessage? {
    return controller?.currentSession()
  }

  private static func proberFor(_ protocolMessage: ProtocolMessage) -> Prober {
    switch protocolMessage {
    case .tcp:
      return TcpProber()
    case .udp:
      return UdpProber()
    case .icmp:
      return IcmpProber()
    }
  }
}
