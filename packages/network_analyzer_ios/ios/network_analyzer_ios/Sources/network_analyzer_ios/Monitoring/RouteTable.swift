import Foundation

/// Reads the BSD routing table to find the default gateway.
///
/// iOS exposes no public API for the default gateway. The route table itself
/// is readable through `sysctl(CTL_NET, PF_ROUTE, …, NET_RT_DUMP, …)`, which
/// is a public BSD interface and passes App Store review — `CTL_NET`,
/// `PF_ROUTE` and `NET_RT_DUMP` all live in `<sys/socket.h>` and
/// `<sys/sysctl.h>`, both of which the iOS SDK ships.
///
/// What the iOS SDK does **not** ship is `<net/route.h>`, so `rt_msghdr`,
/// `RTF_*` and `RTA_*` cannot be imported — by Swift or by C. The few
/// constants and offsets that header would have provided are therefore
/// declared here, read straight out of the returned bytes rather than through
/// a hand-mirrored struct that Swift gives no layout guarantee for.
///
/// Because that layout is asserted rather than imported, every read is
/// validated: anything that does not look like the message it should be makes
/// the parse give up and return `nil`, which surfaces as a typed
/// `GatewayDiscoveryFailure`. A wrong gateway would be far worse than no
/// gateway.
enum RouteTable {
  // MARK: - Constants from <net/route.h>

  /// The route is usable.
  private static let rtfUp: Int32 = 0x1

  /// The route's destination is reached through a gateway.
  private static let rtfGateway: Int32 = 0x2

  /// The message carries a destination address.
  private static let rtaDst: Int32 = 0x1

  /// The message carries a gateway address.
  private static let rtaGateway: Int32 = 0x2

  // MARK: - Layout of `struct rt_msghdr`

  /// `sizeof(struct rt_msghdr)` on Darwin, where the address block begins.
  ///
  /// Every field is 32 bits or narrower, so the size is the same on 32- and
  /// 64-bit: 36 bytes of header fields followed by a 56-byte `rt_metrics`.
  /// Validated at parse time rather than trusted.
  private static let headerBytes = 92

  private static let offsetMessageLength = 0  // u_short
  private static let offsetFlags = 8  // int32
  private static let offsetAddresses = 12  // int32

  /// The size of a `sockaddr_in`, which is what an IPv4 route entry carries.
  private static let sockaddrInBytes = MemoryLayout<sockaddr_in>.size

  // MARK: - Public surface

  /// The IPv4 address of the current default gateway, if there is one.
  static func defaultGateway() -> String? {
    guard let buffer = dump() else {
      return nil
    }
    return parseDefaultGateway(buffer)
  }

  /// The raw `NET_RT_DUMP` payload for the IPv4 routing table.
  static func dump() -> [UInt8]? {
    var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, AF_INET, NET_RT_DUMP, 0]
    var length = 0
    guard sysctl(&mib, u_int(mib.count), nil, &length, nil, 0) == 0,
      length > 0
    else {
      return nil
    }
    var buffer = [UInt8](repeating: 0, count: length)
    let status = buffer.withUnsafeMutableBytes { raw -> Int32 in
      sysctl(&mib, u_int(mib.count), raw.baseAddress, &length, nil, 0)
    }
    guard status == 0 else {
      return nil
    }
    return Array(buffer.prefix(length))
  }

  /// Extracts the first up, gateway-bearing default route from `buffer`.
  ///
  /// A default route is the one whose destination is `0.0.0.0`, which is what
  /// distinguishes it from every other entry in the table.
  static func parseDefaultGateway(_ buffer: [UInt8]) -> String? {
    var offset = 0

    while offset + headerBytes <= buffer.count {
      guard
        let messageLength = readUInt16(buffer, at: offset + offsetMessageLength)
      else {
        return nil
      }
      let length = Int(messageLength)
      // A message shorter than its own header, or running past the buffer,
      // means the layout assumption no longer holds. Stop rather than guess.
      guard length >= headerBytes, offset + length <= buffer.count else {
        return nil
      }

      let flags = readInt32(buffer, at: offset + offsetFlags) ?? 0
      let addresses = readInt32(buffer, at: offset + offsetAddresses) ?? 0
      let isUsable = (flags & rtfUp) != 0 && (flags & rtfGateway) != 0
      let hasBothAddresses =
        (addresses & rtaDst) != 0 && (addresses & rtaGateway) != 0

      if isUsable, hasBothAddresses {
        var cursor = offset + headerBytes
        let limit = offset + length
        if let destination = readAddress(buffer, at: &cursor, limit: limit),
          let gateway = readAddress(buffer, at: &cursor, limit: limit),
          destination == "0.0.0.0"
        {
          return gateway
        }
      }
      offset += length
    }
    return nil
  }

  // MARK: - Byte reading

  private static func readUInt16(_ buffer: [UInt8], at offset: Int) -> UInt16? {
    guard offset >= 0, offset + 2 <= buffer.count else {
      return nil
    }
    return buffer.withUnsafeBytes { raw in
      raw.loadUnaligned(fromByteOffset: offset, as: UInt16.self)
    }
  }

  private static func readInt32(_ buffer: [UInt8], at offset: Int) -> Int32? {
    guard offset >= 0, offset + 4 <= buffer.count else {
      return nil
    }
    return buffer.withUnsafeBytes { raw in
      raw.loadUnaligned(fromByteOffset: offset, as: Int32.self)
    }
  }

  /// Reads one socket address at `cursor`, advancing it past the entry.
  ///
  /// A zero-length entry is how the kernel writes the wildcard destination of
  /// a default route, so it reads as `0.0.0.0` rather than as a parse error.
  /// Entries are padded to a 4-byte boundary, matching the `ROUNDUP` macro
  /// the routing socket documents.
  private static func readAddress(
    _ buffer: [UInt8], at cursor: inout Int, limit: Int
  ) -> String? {
    guard cursor >= 0, cursor + 2 <= limit else {
      return nil
    }
    let length = Int(buffer[cursor])
    let family = buffer[cursor + 1]
    let advance = length == 0 ? 4 : roundUp(length)
    defer { cursor += advance }

    if length == 0 {
      return "0.0.0.0"
    }
    guard family == UInt8(AF_INET),
      length >= sockaddrInBytes,
      cursor + length <= limit
    else {
      return nil
    }

    let address: sockaddr_in = buffer.withUnsafeBytes { raw in
      raw.loadUnaligned(fromByteOffset: cursor, as: sockaddr_in.self)
    }
    var source = address.sin_addr
    var text = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
    guard inet_ntop(AF_INET, &source, &text, socklen_t(text.count)) != nil else {
      return nil
    }
    return String(cString: text)
  }

  /// Rounds a socket address length up to the table's 4-byte alignment.
  private static func roundUp(_ length: Int) -> Int {
    let alignment = MemoryLayout<UInt32>.size
    return (length + alignment - 1) & ~(alignment - 1)
  }
}
