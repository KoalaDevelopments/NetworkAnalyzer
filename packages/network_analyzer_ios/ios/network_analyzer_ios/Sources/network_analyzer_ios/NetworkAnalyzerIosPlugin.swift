import Flutter
import UIKit

/// iOS entry point of the network_analyzer plugin.
///
/// Exposes the pigeon-generated `NetworkAnalyzerHostApi` over the engine's
/// binary messenger. The wire layer lives in Messages.g.swift, generated
/// from pigeons/messages.dart — never hand-write channel code
/// (constitution, Principle II).
public class NetworkAnalyzerIosPlugin: NSObject, FlutterPlugin, NetworkAnalyzerHostApi {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = NetworkAnalyzerIosPlugin()
    NetworkAnalyzerHostApiSetup.setUp(
      binaryMessenger: registrar.messenger(), api: instance)
  }

  func getBridgeInfo() throws -> BridgeInfoMessage {
    return BridgeInfoMessage(
      operatingSystem: "ios",
      osVersion: UIDevice.current.systemVersion)
  }
}
