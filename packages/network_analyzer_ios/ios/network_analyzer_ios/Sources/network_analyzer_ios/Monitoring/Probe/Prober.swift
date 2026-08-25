import Foundation

/// The outcome of a single probe.
///
/// `roundTripMicros` is present only when `outcome` is `.success`; a failed
/// probe reports no timing rather than a fabricated one.
struct ProbeResult {
  let outcome: OutcomeMessage
  let roundTripMicros: Int64?

  /// A probe that completed, timed monotonically.
  static func success(_ roundTripMicros: Int64) -> ProbeResult {
    ProbeResult(outcome: .success, roundTripMicros: roundTripMicros)
  }

  /// A probe the target did not answer in time.
  static func timeout() -> ProbeResult {
    ProbeResult(outcome: .timeout, roundTripMicros: nil)
  }

  /// A probe whose target could not be reached at all.
  static func unreachable() -> ProbeResult {
    ProbeResult(outcome: .unreachable, roundTripMicros: nil)
  }

  /// A probe that failed for any other reason.
  static func error() -> ProbeResult {
    ProbeResult(outcome: .error, roundTripMicros: nil)
  }
}

/// Sends one probe and times it.
///
/// Implementations are protocol-specific, take an explicit timeout, and time
/// with `CLOCK_MONOTONIC_RAW` so a device clock change cannot distort a
/// measurement.
protocol Prober {
  func probe(address: String, port: Int, timeoutMillis: Int) -> ProbeResult
  func close()
}

extension Prober {
  func close() {}
}

/// A monotonic timestamp in nanoseconds.
///
/// `Date` is deliberately unused: it follows the wall clock, which the user
/// or the network can move mid-session.
func monotonicNanos() -> Int64 {
  var time = timespec()
  clock_gettime(CLOCK_MONOTONIC_RAW, &time)
  return Int64(time.tv_sec) * 1_000_000_000 + Int64(time.tv_nsec)
}

/// Resolves `address` for `port`, honouring NAT64 synthesis.
///
/// `getaddrinfo` is used rather than a hand-built `sockaddr_in` because on an
/// IPv6-only network it synthesises a routable IPv6 address from an IPv4
/// literal. Building the address by hand would fail outright there — and that
/// is the network App Store review tests on.
func resolveAddress(_ address: String, port: Int) -> (sockaddr, socklen_t)? {
  var hints = addrinfo()
  hints.ai_family = AF_UNSPEC
  hints.ai_socktype = SOCK_STREAM
  hints.ai_flags = AI_DEFAULT

  var result: UnsafeMutablePointer<addrinfo>?
  let status = getaddrinfo(address, String(port), &hints, &result)
  guard status == 0, let first = result else {
    return nil
  }
  defer { freeaddrinfo(result) }
  guard let resolved = first.pointee.ai_addr?.pointee else {
    return nil
  }
  return (resolved, first.pointee.ai_addrlen)
}
