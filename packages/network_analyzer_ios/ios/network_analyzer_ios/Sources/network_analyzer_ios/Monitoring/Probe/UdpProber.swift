import Foundation

/// Sends a DNS query and times the reply.
///
/// Every bundled preset is a DNS resolver, so a minimal query for the root
/// zone is the cheapest payload that provokes a real answer. A custom target
/// on a non-DNS port will time out, which is the honest result rather than a
/// silent fallback to another protocol.
final class UdpProber: Prober {
  private let clock: () -> Int64

  init(clock: @escaping () -> Int64 = monotonicNanos) {
    self.clock = clock
  }

  /// A standard-query header asking for the root zone's NS record.
  static func dnsRootQuery() -> [UInt8] {
    [
      0x2A, 0x2A,  // transaction id
      0x01, 0x00,  // standard query, recursion desired
      0x00, 0x01,  // one question
      0x00, 0x00,  // no answers
      0x00, 0x00,  // no authority records
      0x00, 0x00,  // no additional records
      0x00,  // root name
      0x00, 0x02,  // type NS
      0x00, 0x01,  // class IN
    ]
  }

  func probe(address: String, port: Int, timeoutMillis: Int) -> ProbeResult {
    guard let resolved = resolveAddress(address, port: port) else {
      return .unreachable()
    }
    var destination = resolved.0
    let length = resolved.1
    let descriptor = socket(Int32(destination.sa_family), SOCK_DGRAM, IPPROTO_UDP)
    guard descriptor >= 0 else {
      return .error()
    }
      defer { _DarwinFoundation3.close(descriptor) }

    var timeout = timeval(
      tv_sec: timeoutMillis / 1000,
      tv_usec: Int32((timeoutMillis % 1000) * 1000))
    setsockopt(
      descriptor, SOL_SOCKET, SO_RCVTIMEO, &timeout,
      socklen_t(MemoryLayout<timeval>.size))

    let query = UdpProber.dnsRootQuery()
    let startedAt = clock()
    let sent = withUnsafePointer(to: &destination) { pointer in
      sendto(descriptor, query, query.count, 0, pointer, length)
    }
    guard sent == query.count else {
      return errno == EHOSTUNREACH || errno == ENETUNREACH
        ? .unreachable() : .error()
    }

    var reply = [UInt8](repeating: 0, count: 512)
    let received = recv(descriptor, &reply, reply.count, 0)
    if received > 0 {
      return .success((clock() - startedAt) / 1_000)
    }
    switch errno {
    case EAGAIN, ETIMEDOUT:
      return .timeout()
    case ECONNREFUSED, EHOSTUNREACH, ENETUNREACH:
      return .unreachable()
    default:
      return .error()
    }
  }
}
