import XCTest

@testable import network_analyzer_ios

final class IcmpPacketTests: XCTestCase {
  func testEchoRequestStartsWithAnEchoHeader() {
    let packet = IcmpPacket.echoRequest(sequence: 7, payloadBytes: 4)

    XCTAssertEqual(packet.count, IcmpPacket.headerBytes + 4)
    XCTAssertEqual(packet[0], 8)  // type: echo request
    XCTAssertEqual(packet[1], 0)  // code
    XCTAssertEqual(packet[7], 7)  // sequence, low byte
  }

  func testEchoRequestCarriesAChecksumThatValidates() {
    let packet = IcmpPacket.echoRequest(sequence: 1, payloadBytes: 8)

    // A packet with a correct checksum sums to zero when re-checked.
    XCTAssertEqual(IcmpPacket.checksum(packet), 0)
  }

  func testChecksumMatchesRfc1071ForAKnownVector() {
    let data: [UInt8] = [0x00, 0x01, 0xF2, 0x03, 0xF4, 0xF5]

    XCTAssertEqual(IcmpPacket.checksum(data), 0x1905)
  }

  func testIsEchoReplyAcceptsAReplyForTheSameSequence() {
    var reply = [UInt8](repeating: 0, count: IcmpPacket.headerBytes)
    reply[0] = 0  // type: echo reply
    reply[7] = 9

    XCTAssertTrue(
      IcmpPacket.isEchoReply(reply, length: reply.count, sequence: 9))
  }

  func testIsEchoReplyRejectsAnotherSequence() {
    var reply = [UInt8](repeating: 0, count: IcmpPacket.headerBytes)
    reply[0] = 0
    reply[7] = 9

    XCTAssertFalse(
      IcmpPacket.isEchoReply(reply, length: reply.count, sequence: 10))
  }

  func testIsEchoReplyRejectsANonReplyType() {
    var reply = [UInt8](repeating: 0, count: IcmpPacket.headerBytes)
    reply[0] = 3  // destination unreachable
    reply[7] = 9

    XCTAssertFalse(
      IcmpPacket.isEchoReply(reply, length: reply.count, sequence: 9))
  }

  func testIsEchoReplyRejectsATruncatedPacket() {
    let reply = [UInt8](repeating: 0, count: IcmpPacket.headerBytes)

    XCTAssertFalse(IcmpPacket.isEchoReply(reply, length: 4, sequence: 0))
  }
}

final class IcmpStripHeaderTests: XCTestCase {
  /// A reply as Darwin actually delivers it: IPv4 header, then ICMP.
  private func kernelStyleReply(sequence: Int, ihlWords: Int = 5) -> [UInt8] {
    var icmp = [UInt8](repeating: 0, count: IcmpPacket.headerBytes)
    icmp[0] = 0  // echo reply
    icmp[6] = UInt8((sequence >> 8) & 0xFF)
    icmp[7] = UInt8(sequence & 0xFF)
    var ip = [UInt8](repeating: 0, count: ihlWords * 4)
    ip[0] = UInt8(0x40 | ihlWords)  // version 4, header length
    ip[9] = 1  // protocol: ICMP
    return ip + icmp
  }

  func testStripsTheIPv4HeaderDarwinDelivers() {
    let datagram = kernelStyleReply(sequence: 9)

    let (payload, length) = IcmpPacket.stripIPv4Header(
      datagram, length: datagram.count)

    XCTAssertTrue(IcmpPacket.isEchoReply(payload, length: length, sequence: 9))
  }

  func testStripsAHeaderWithOptions() {
    // IHL 6 words = a 24-byte header carrying one option.
    let datagram = kernelStyleReply(sequence: 3, ihlWords: 6)

    let (payload, length) = IcmpPacket.stripIPv4Header(
      datagram, length: datagram.count)

    XCTAssertTrue(IcmpPacket.isEchoReply(payload, length: length, sequence: 3))
  }

  func testLeavesAnAlreadyStrippedReplyUntouched() {
    var reply = [UInt8](repeating: 0, count: IcmpPacket.headerBytes)
    reply[0] = 0  // echo reply type: no IPv4 version nibble
    reply[7] = 5

    let (payload, length) = IcmpPacket.stripIPv4Header(
      reply, length: reply.count)

    XCTAssertEqual(length, reply.count)
    XCTAssertTrue(IcmpPacket.isEchoReply(payload, length: length, sequence: 5))
  }

  func testLeavesATruncatedDatagramUntouched() {
    let short: [UInt8] = [0x45, 0x00, 0x00]

    let (payload, length) = IcmpPacket.stripIPv4Header(short, length: short.count)

    XCTAssertEqual(length, short.count)
    XCTAssertEqual(payload, short)
  }

  func testWithoutStrippingTheKernelReplyWouldReadAsALoss() {
    // The regression this guards: parsing the raw datagram as ICMP made
    // every real reply look malformed — observed as 100% packet loss on iOS.
    let datagram = kernelStyleReply(sequence: 9)

    XCTAssertFalse(
      IcmpPacket.isEchoReply(datagram, length: datagram.count, sequence: 9))
  }
}

final class UdpProberTests: XCTestCase {
  func testDnsRootQueryIsAWellFormedStandardQuery() {
    let query = UdpProber.dnsRootQuery()

    XCTAssertEqual(query.count, 17)
    XCTAssertEqual(query[2], 0x01)  // recursion desired
    XCTAssertEqual(query[5], 0x01)  // exactly one question
    XCTAssertEqual(query[12], 0x00)  // root name
    XCTAssertEqual(query[14], 0x02)  // type NS
    XCTAssertEqual(query[16], 0x01)  // class IN
  }
}
