package com.koaladevelopments.network_analyzer_android.monitoring.probe

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

internal class IcmpPacketTest {
    @Test
    fun echoRequest_startsWithAnEchoHeader() {
        val packet = IcmpPacket.echoRequest(sequence = 7, payloadBytes = 4)

        assertEquals(IcmpPacket.HEADER_BYTES + 4, packet.size)
        assertEquals(8, packet[0].toInt()) // type: echo request
        assertEquals(0, packet[1].toInt()) // code
        assertEquals(7, packet[7].toInt()) // sequence, low byte
    }

    @Test
    fun echoRequest_carriesAChecksumThatValidates() {
        val packet = IcmpPacket.echoRequest(sequence = 1, payloadBytes = 8)

        // A packet with a correct checksum sums to zero when re-checked.
        assertEquals(0, IcmpPacket.checksum(packet))
    }

    @Test
    fun checksum_matchesRfc1071ForAKnownVector() {
        val data = byteArrayOf(0x00, 0x01, 0xF2.toByte(), 0x03, 0xF4.toByte(), 0xF5.toByte())

        assertEquals(0x1905, IcmpPacket.checksum(data))
    }

    @Test
    fun isEchoReply_acceptsAReplyForTheSameSequence() {
        val reply = ByteArray(IcmpPacket.HEADER_BYTES)
        reply[0] = 0 // type: echo reply
        reply[7] = 9

        assertTrue(IcmpPacket.isEchoReply(reply, reply.size, sequence = 9))
    }

    @Test
    fun isEchoReply_rejectsAnotherSequence() {
        val reply = ByteArray(IcmpPacket.HEADER_BYTES)
        reply[0] = 0
        reply[7] = 9

        assertFalse(IcmpPacket.isEchoReply(reply, reply.size, sequence = 10))
    }

    @Test
    fun isEchoReply_rejectsANonReplyType() {
        val reply = ByteArray(IcmpPacket.HEADER_BYTES)
        reply[0] = 3 // destination unreachable
        reply[7] = 9

        assertFalse(IcmpPacket.isEchoReply(reply, reply.size, sequence = 9))
    }

    @Test
    fun isEchoReply_rejectsATruncatedPacket() {
        val reply = ByteArray(IcmpPacket.HEADER_BYTES)

        assertFalse(IcmpPacket.isEchoReply(reply, length = 4, sequence = 0))
    }
}
