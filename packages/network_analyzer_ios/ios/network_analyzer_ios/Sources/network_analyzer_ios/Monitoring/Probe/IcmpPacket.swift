import Foundation

/// Builds and reads ICMP echo messages.
///
/// Kept separate from the prober so the packet format and its checksum can be
/// unit-tested without opening a socket.
///
/// Darwin does not fill the checksum for ICMP datagram sockets, so it is
/// computed here — unlike some platforms where the kernel does it.
enum IcmpPacket {
  /// Bytes in an ICMP echo header.
  static let headerBytes = 8

  private static let typeEchoRequest: UInt8 = 8
  private static let typeEchoReply: UInt8 = 0

  /// Builds an echo request carrying `sequence` and `payloadBytes` of filler.
  static func echoRequest(sequence: Int, payloadBytes: Int = 32) -> [UInt8] {
    var packet = [UInt8](repeating: 0, count: headerBytes + payloadBytes)
    packet[0] = typeEchoRequest
    packet[1] = 0  // code
    packet[2] = 0  // checksum, filled in below
    packet[3] = 0
    packet[4] = 0  // identifier, rewritten by the kernel
    packet[5] = 0
    packet[6] = UInt8((sequence >> 8) & 0xFF)
    packet[7] = UInt8(sequence & 0xFF)
    for index in 0..<payloadBytes {
      packet[headerBytes + index] = UInt8(index & 0xFF)
    }

    let sum = checksum(packet)
    packet[2] = UInt8((sum >> 8) & 0xFF)
    packet[3] = UInt8(sum & 0xFF)
    return packet
  }

  /// Whether `packet` is an echo reply for `sequence`.
  static func isEchoReply(_ packet: [UInt8], length: Int, sequence: Int) -> Bool {
    guard length >= headerBytes, packet[0] == typeEchoReply else {
      return false
    }
    let replySequence = (Int(packet[6]) << 8) | Int(packet[7])
    return replySequence == (sequence & 0xFFFF)
  }

  /// Returns the ICMP portion of a received datagram.
  ///
  /// Darwin's unprivileged ICMP sockets deliver the **full IPv4 header**
  /// ahead of the ICMP message — unlike Linux, which strips it. Reading the
  /// bytes as ICMP without stripping makes every genuine echo reply look
  /// malformed, which reads back as 100% packet loss. Apple's own SimplePing
  /// strips the header the same way.
  ///
  /// Defensive rather than assumed: the header is only removed when the
  /// first byte carries an IPv4 version nibble, so an already-stripped
  /// message (echo reply type 0) passes through untouched.
  static func stripIPv4Header(_ packet: [UInt8], length: Int) -> (
    payload: [UInt8], length: Int
  ) {
    let minimumIPv4Header = 20
    guard length >= minimumIPv4Header, packet[0] >> 4 == 4 else {
      return (packet, length)
    }
    let headerLength = Int(packet[0] & 0x0F) * 4
    guard headerLength >= minimumIPv4Header, length > headerLength else {
      return (packet, length)
    }
    return (Array(packet[headerLength..<length]), length - headerLength)
  }

  /// The internet checksum (RFC 1071) over `data`.
  static func checksum(_ data: [UInt8]) -> Int {
    var sum = 0
    var index = 0
    while index + 1 < data.count {
      sum += (Int(data[index]) << 8) | Int(data[index + 1])
      index += 2
    }
    if index < data.count {
      sum += Int(data[index]) << 8
    }
    while (sum >> 16) != 0 {
      sum = (sum & 0xFFFF) + (sum >> 16)
    }
    return (~sum) & 0xFFFF
  }
}
