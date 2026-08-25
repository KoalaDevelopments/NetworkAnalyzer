import Foundation

/// Bridges the session controller to the pigeon event channel.
///
/// Cancelling the last subscription stops probing: a session nobody is
/// listening to has no reason to keep using the radio.
final class MonitorStreamHandler: StreamMonitorSignalsStreamHandler {
  private let controller: MonitorSessionController

  init(controller: MonitorSessionController) {
    self.controller = controller
    super.init()
  }

  override func onListen(
    withArguments arguments: Any?, sink: PigeonEventSink<MonitorSignalMessage>
  ) {
    controller.attachSink { signal in sink.success(signal) }
  }

  override func onCancel(withArguments arguments: Any?) {
    controller.attachSink(nil)
    controller.stopSession()
  }
}
