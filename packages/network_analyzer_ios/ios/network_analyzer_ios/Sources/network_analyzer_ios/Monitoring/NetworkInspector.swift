import CoreTelephony
import Foundation
import Network

/// What the device's current network looks like.
struct NetworkFacts: Equatable {
  let interfaceType: InterfaceTypeMessage
  let deviceIpAddress: String
  let gatewayAddress: String?
}

/// Reads the current network's type, address and default gateway.
///
/// A protocol so the session controller can be unit-tested against fixed
/// facts without a device.
protocol NetworkInspector {
  func read() -> NetworkFacts
}

/// Reads network facts from the system.
///
/// Unlike Android, iOS resolves the cellular generation without any
/// permission, through `CTTelephonyNetworkInfo`. The default gateway has no
/// public API, so it is read from the BSD route table via `sysctl` — a
/// public interface that passes App Store review.
final class DarwinNetworkInspector: NetworkInspector {
  private let monitor = NWPathMonitor()
  private let telephony = CTTelephonyNetworkInfo()
  private let queue = DispatchQueue(label: "network_analyzer.path_monitor")

  init() {
    monitor.start(queue: queue)
  }

  deinit {
    monitor.cancel()
  }

  func read() -> NetworkFacts {
    let path = monitor.currentPath
    return NetworkFacts(
      interfaceType: interfaceType(for: path),
      deviceIpAddress: DarwinNetworkInspector.deviceAddress() ?? "",
      gatewayAddress: RouteTable.defaultGateway())
  }

  private func interfaceType(for path: NWPath) -> InterfaceTypeMessage {
    guard path.status == .satisfied else {
      return .none
    }
    if path.usesInterfaceType(.wiredEthernet) {
      return .ethernet
    }
    if path.usesInterfaceType(.wifi) {
      return .wifi
    }
    if path.usesInterfaceType(.cellular) {
      return cellularGeneration()
    }
    if path.usesInterfaceType(.other) {
      return .other
    }
    return .unknown
  }

  private func cellularGeneration() -> InterfaceTypeMessage {
    guard
      let technology = telephony.serviceCurrentRadioAccessTechnology?
        .values.first
    else {
      return .cellular
    }
    if #available(iOS 14.1, *) {
      if technology == CTRadioAccessTechnologyNRNSA
        || technology == CTRadioAccessTechnologyNR
      {
        return .cellular5g
      }
    }
    switch technology {
    case CTRadioAccessTechnologyLTE:
      return .cellular4g
    case CTRadioAccessTechnologyWCDMA,
      CTRadioAccessTechnologyHSDPA,
      CTRadioAccessTechnologyHSUPA,
      CTRadioAccessTechnologyCDMAEVDORev0,
      CTRadioAccessTechnologyCDMAEVDORevA,
      CTRadioAccessTechnologyCDMAEVDORevB,
      CTRadioAccessTechnologyeHRPD:
      return .cellular3g
    case CTRadioAccessTechnologyGPRS,
      CTRadioAccessTechnologyEdge,
      CTRadioAccessTechnologyCDMA1x:
      return .cellular2g
    default:
      return .cellular
    }
  }

  /// The device's IPv4 address on the active interface.
  static func deviceAddress() -> String? {
    var addresses: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&addresses) == 0, let first = addresses else {
      return nil
    }
    defer { freeifaddrs(addresses) }

    var result: String?
    var cursor: UnsafeMutablePointer<ifaddrs>? = first
    while let entry = cursor {
      let flags = Int32(entry.pointee.ifa_flags)
      let family = entry.pointee.ifa_addr?.pointee.sa_family
      let isUp = (flags & IFF_UP) == IFF_UP
      let isLoopback = (flags & IFF_LOOPBACK) == IFF_LOOPBACK
      if isUp, !isLoopback, family == UInt8(AF_INET) {
        let name = String(cString: entry.pointee.ifa_name)
        if name.hasPrefix("en") || name.hasPrefix("pdp_ip") {
          var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
          if getnameinfo(
            entry.pointee.ifa_addr,
            socklen_t(entry.pointee.ifa_addr.pointee.sa_len),
            &buffer, socklen_t(buffer.count), nil, 0, NI_NUMERICHOST) == 0
          {
            result = String(cString: buffer)
            if name.hasPrefix("en") {
              break
            }
          }
        }
      }
      cursor = entry.pointee.ifa_next
    }
    return result
  }
}
