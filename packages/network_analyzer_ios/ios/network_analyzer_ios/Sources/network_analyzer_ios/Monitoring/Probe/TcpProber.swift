import Foundation

/// Times a TCP connection handshake to the target.
///
/// The connect is **non-blocking**, completed with `poll` and read back
/// through `SO_ERROR`. That is not a style choice: on Darwin, `SO_SNDTIMEO`
/// does not bound a blocking `connect()`, so a blackholing target would hang
/// the probe queue for the kernel's own timeout — over a minute — during
/// which the session emits nothing at all.
///
/// A **refused** connection counts as a success, not a failure: the RST that
/// refuses it round-tripped from the target, which proves reachability and
/// carries a real timing. This matters most for gateway monitoring — many
/// routers listen on no TCP port at all.
final class TcpProber: Prober {
  private let clock: () -> Int64

  init(clock: @escaping () -> Int64 = monotonicNanos) {
    self.clock = clock
  }

  func probe(address: String, port: Int, timeoutMillis: Int) -> ProbeResult {
    guard let resolved = resolveAddress(address, port: port) else {
      return .unreachable()
    }
    var destination = resolved.0
    let length = resolved.1
    let descriptor = socket(
      Int32(destination.sa_family), SOCK_STREAM, IPPROTO_TCP)
    guard descriptor >= 0 else {
      return .error()
    }
    defer { Darwin.close(descriptor) }

    let flags = fcntl(descriptor, F_GETFL)
    guard flags >= 0, fcntl(descriptor, F_SETFL, flags | O_NONBLOCK) >= 0
    else {
      return .error()
    }

    let startedAt = clock()
    let connected = withUnsafePointer(to: &destination) { pointer in
      connect(descriptor, pointer, length)
    }
    if connected == 0 {
      return .success((clock() - startedAt) / 1_000)
    }
    switch errno {
    case EINPROGRESS:
      break  // the normal non-blocking path; wait below
    case ECONNREFUSED:
      return .success((clock() - startedAt) / 1_000)
    case EHOSTUNREACH, ENETUNREACH:
      return .unreachable()
    default:
      return .error()
    }

    var waiter = pollfd(fd: descriptor, events: Int16(POLLOUT), revents: 0)
    let ready = poll(&waiter, 1, Int32(timeoutMillis))
    if ready == 0 {
      return .timeout()
    }
    if ready < 0 {
      return .error()
    }

    var socketError: Int32 = 0
    var errorSize = socklen_t(MemoryLayout<Int32>.size)
    guard
      getsockopt(descriptor, SOL_SOCKET, SO_ERROR, &socketError, &errorSize)
        == 0
    else {
      return .error()
    }
    let elapsed = (clock() - startedAt) / 1_000
    switch socketError {
    case 0:
      return .success(elapsed)
    case ECONNREFUSED:
      // The RST is a reply; time it like one.
      return .success(elapsed)
    case ETIMEDOUT:
      return .timeout()
    case EHOSTUNREACH, ENETUNREACH:
      return .unreachable()
    default:
      return .error()
    }
  }
}
