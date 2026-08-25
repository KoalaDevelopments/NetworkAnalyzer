package com.koaladevelopments.network_analyzer_android.monitoring.probe

import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Builds and reads ICMP echo messages.
 *
 * Kept separate from the prober so the packet format and its checksum can be
 * unit-tested without opening a socket.
 *
 * On an unprivileged ICMP datagram socket the kernel rewrites the identifier
 * field, so a reply is matched on its sequence number alone.
 */
object IcmpPacket {
    /** Bytes in an ICMP echo header. */
    const val HEADER_BYTES = 8

    private const val TYPE_ECHO_REQUEST = 8
    private const val TYPE_ECHO_REPLY = 0

    /**
     * Builds an echo request carrying [sequence] and [payloadBytes] of
     * filler.
     */
    fun echoRequest(sequence: Int, payloadBytes: Int = 32): ByteArray {
        val buffer = ByteBuffer.allocate(HEADER_BYTES + payloadBytes)
            .order(ByteOrder.BIG_ENDIAN)
        buffer.put(TYPE_ECHO_REQUEST.toByte())
        buffer.put(0) // code
        buffer.putShort(0) // checksum, filled in below
        buffer.putShort(0) // identifier, rewritten by the kernel
        buffer.putShort(sequence.toShort())
        repeat(payloadBytes) { index -> buffer.put((index and 0xFF).toByte()) }

        val packet = buffer.array()
        val sum = checksum(packet)
        packet[2] = (sum shr 8 and 0xFF).toByte()
        packet[3] = (sum and 0xFF).toByte()
        return packet
    }

    /**
     * Whether [packet] is an echo reply for [sequence].
     *
     * [length] is the number of bytes actually received.
     */
    fun isEchoReply(packet: ByteArray, length: Int, sequence: Int): Boolean {
        if (length < HEADER_BYTES) {
            return false
        }
        if (packet[0].toInt() != TYPE_ECHO_REPLY) {
            return false
        }
        val replySequence =
            (packet[6].toInt() and 0xFF shl 8) or (packet[7].toInt() and 0xFF)
        return replySequence == (sequence and 0xFFFF)
    }

    /** The internet checksum (RFC 1071) over [data]. */
    fun checksum(data: ByteArray): Int {
        var sum = 0L
        var index = 0
        while (index + 1 < data.size) {
            val word = (data[index].toInt() and 0xFF shl 8) or
                (data[index + 1].toInt() and 0xFF)
            sum += word.toLong()
            index += 2
        }
        if (index < data.size) {
            sum += (data[index].toInt() and 0xFF shl 8).toLong()
        }
        while (sum shr 16 != 0L) {
            sum = (sum and 0xFFFF) + (sum shr 16)
        }
        return sum.inv().toInt() and 0xFFFF
    }
}
