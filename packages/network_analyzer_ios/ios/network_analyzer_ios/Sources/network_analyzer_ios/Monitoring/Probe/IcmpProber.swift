import Foundation

// ponytail: IPv4 only. ICMPv6 needs IPPROTO_ICMPV6 and a checksum over an
// IPv6 pseudo-header; add it here and drop the IPv6-only guard in
// MonitorSessionController if ICMP on IPv6-only networks becomes a
// requirement.

/// Sends an ICMP echo request and times the echo reply.
///
/// Uses an unprivileged ICMP *datagram* socket — the approach Apple's own
/// SimplePing sample takes, so it needs no entitlement and passes App Store
/// review.
///
/// Two Darwin realities shape the receive path. Replies arrive with the
/// full IPv4 header still attached, so it is stripped before parsing
/// (`IcmpPacket.stripIPv4Header`). And the socket delivers *every* ICMP
/// message addressed to it, not only our reply, so receiving loops until the
/// matching sequence number arrives or the deadline passes — a stray
/// message must not fail the probe.
final class IcmpProber: Prober {
  private let clock: () -> Int64
  private var sequence = 0

  init(clock: @escaping () -> Int64 = monotonicNanos) {
    self.clock = clock
  }

  func probe(address: String, port: Int, timeoutMillis: Int) -> ProbeResult {
    var destination = sockaddr_in()
    destination.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    destination.sin_family = sa_family_t(AF_INET)
    destination.sin_port = 0
    guard inet_pton(AF_INET, address, &destination.sin_addr) == 1 else {
      return .unreachable()
    }

    let descriptor = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)
    guard descriptor >= 0 else {
      return .error()
    }
    defer { Darwin.close(descriptor) }

    let current = sequence
    sequence += 1
    let request = IcmpPacket.echoRequest(sequence: current)
    let startedAt = clock()
    let sent = withUnsafePointer(to: &destination) { pointer in
      pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { address in
        sendto(
          descriptor, request, request.count, 0, address,
          socklen_t(MemoryLayout<sockaddr_in>.size))
      }
    }
    guard sent == request.count else {
      return errno == EHOSTUNREACH || errno == ENETUNREACH
        ? .unreachable() : .error()
    }

    return awaitReply(
      on: descriptor,
      sequence: current,
      startedAt: startedAt,
      deadline: startedAt + Int64(timeoutMillis) * 1_000_000)
  }

  private func awaitReply(
    on descriptor: Int32, sequence: Int, startedAt: Int64, deadline: Int64
  ) -> ProbeResult {
    var reply = [UInt8](repeating: 0, count: 512)
    while true {
      let remainingNanos = deadline - clock()
      guard remainingNanos > 0 else {
        return .timeout()
      }
      let remainingMillis = Int(remainingNanos / 1_000_000)

      var waiter = pollfd(fd: descriptor, events: Int16(POLLIN), revents: 0)
      let ready = poll(&waiter, 1, Int32(max(remainingMillis, 1)))
      if ready == 0 {
        return .timeout()
      }
      if ready < 0 {
        return .error()
      }

      let received = recv(descriptor, &reply, reply.count, 0)
      guard received > 0 else {
        switch errno {
        case EAGAIN, ETIMEDOUT:
          return .timeout()
        case EHOSTUNREACH, ENETUNREACH:
          return .unreachable()
        default:
          return .error()
        }
      }

      let (payload, length) = IcmpPacket.stripIPv4Header(
        reply, length: received)
      if IcmpPacket.isEchoReply(payload, length: length, sequence: sequence) {
        return .success((clock() - startedAt) / 1_000)
      }
      // Not ours — an unrelated ICMP message. Keep waiting for the reply.
    }
  }
}
