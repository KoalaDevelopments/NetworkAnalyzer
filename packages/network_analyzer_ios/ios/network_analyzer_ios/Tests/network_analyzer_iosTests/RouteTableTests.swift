import XCTest

@testable import network_analyzer_ios

/// Exercises the route-table parser against hand-built buffers, so gateway
/// extraction is testable without a device or a live network.
///
/// The buffers are assembled from the same layout constants the parser reads,
/// because the iOS SDK ships no `<net/route.h>` to check them against. That
/// makes these tests a check of the parsing logic, not of the kernel's ABI —
/// which is exactly why the parser validates every field it reads and gives up
/// rather than guessing when something does not fit.
final class RouteTableTests: XCTestCase {
  /// `sizeof(struct rt_msghdr)` on Darwin; see `RouteTable`.
  private let headerBytes = 92
  private let rtfUp: Int32 = 0x1
  private let rtfGateway: Int32 = 0x2
  private let rtaDst: Int32 = 0x1
  private let rtaGateway: Int32 = 0x2

  /// Builds one `NET_RT_DUMP` message.
  ///
  /// Passing `nil` for `destination` writes the zero-length wildcard entry the
  /// kernel uses for a default route, which is the awkward case worth covering.
  private func routeMessage(
    destination: String?,
    gateway: String,
    flags: Int32,
    addresses: Int32? = nil
  ) -> [UInt8] {
    let addressSize = MemoryLayout<sockaddr_in>.size
    let destinationSize = destination == nil ? 4 : addressSize
    var message = [UInt8](
      repeating: 0, count: headerBytes + destinationSize + addressSize)

    func write<T>(_ value: T, at offset: Int) {
      withUnsafeBytes(of: value) { raw in
        for (index, byte) in raw.enumerated() {
          message[offset + index] = byte
        }
      }
    }

    write(UInt16(message.count), at: 0)  // rtm_msglen
    message[2] = 5  // rtm_version
    message[3] = 4  // rtm_type (RTM_GET)
    write(flags, at: 8)  // rtm_flags
    write(addresses ?? (rtaDst | rtaGateway), at: 12)  // rtm_addrs

    var offset = headerBytes
    if let destination = destination {
      writeSockaddr(destination, into: &message, at: offset)
      offset += addressSize
    } else {
      // A zero-length entry: sa_len 0, everything else zero.
      offset += 4
    }
    writeSockaddr(gateway, into: &message, at: offset)
    return message
  }

  private func writeSockaddr(
    _ text: String, into message: inout [UInt8], at offset: Int
  ) {
    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    _ = inet_pton(AF_INET, text, &address.sin_addr)
    withUnsafeBytes(of: &address) { raw in
      for (index, byte) in raw.enumerated() {
        message[offset + index] = byte
      }
    }
  }

  func testParsesTheDefaultGateway() {
    let buffer = routeMessage(
      destination: "0.0.0.0", gateway: "192.168.1.1",
      flags: rtfUp | rtfGateway)

    XCTAssertEqual(RouteTable.parseDefaultGateway(buffer), "192.168.1.1")
  }

  func testParsesADefaultRouteWithAZeroLengthDestination() {
    // How the kernel usually writes the wildcard destination.
    let buffer = routeMessage(
      destination: nil, gateway: "10.0.0.1", flags: rtfUp | rtfGateway)

    XCTAssertEqual(RouteTable.parseDefaultGateway(buffer), "10.0.0.1")
  }

  func testIgnoresANonDefaultRoute() {
    let buffer = routeMessage(
      destination: "10.0.0.0", gateway: "10.0.0.1", flags: rtfUp | rtfGateway)

    XCTAssertNil(RouteTable.parseDefaultGateway(buffer))
  }

  func testIgnoresARouteThatIsNotUp() {
    let buffer = routeMessage(
      destination: "0.0.0.0", gateway: "192.168.1.1", flags: rtfGateway)

    XCTAssertNil(RouteTable.parseDefaultGateway(buffer))
  }

  func testIgnoresARouteWithNoGatewayFlag() {
    let buffer = routeMessage(
      destination: "0.0.0.0", gateway: "192.168.1.1", flags: rtfUp)

    XCTAssertNil(RouteTable.parseDefaultGateway(buffer))
  }

  func testIgnoresAMessageMissingAnAddressBit() {
    let buffer = routeMessage(
      destination: "0.0.0.0", gateway: "192.168.1.1",
      flags: rtfUp | rtfGateway, addresses: rtaGateway)

    XCTAssertNil(RouteTable.parseDefaultGateway(buffer))
  }

  func testReturnsNilForAnEmptyTable() {
    XCTAssertNil(RouteTable.parseDefaultGateway([]))
  }

  func testReturnsNilForATruncatedBuffer() {
    // Shorter than a single header: the layout assumption cannot hold.
    let buffer = [UInt8](repeating: 0, count: 40)

    XCTAssertNil(RouteTable.parseDefaultGateway(buffer))
  }

  func testGivesUpOnAMessageShorterThanItsOwnHeader() {
    var buffer = routeMessage(
      destination: "0.0.0.0", gateway: "192.168.1.1",
      flags: rtfUp | rtfGateway)
    // Claim a length no real message could have.
    buffer[0] = 8
    buffer[1] = 0

    XCTAssertNil(RouteTable.parseDefaultGateway(buffer))
  }

  func testFindsTheDefaultRouteAmongOthers() {
    let buffer =
      routeMessage(
        destination: "10.0.0.0", gateway: "10.0.0.1", flags: rtfUp | rtfGateway)
      + routeMessage(
        destination: "0.0.0.0", gateway: "172.16.0.1",
        flags: rtfUp | rtfGateway)

    XCTAssertEqual(RouteTable.parseDefaultGateway(buffer), "172.16.0.1")
  }
}
