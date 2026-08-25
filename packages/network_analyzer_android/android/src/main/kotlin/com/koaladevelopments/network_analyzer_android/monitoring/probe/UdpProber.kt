package com.koaladevelopments.network_analyzer_android.monitoring.probe

import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.net.PortUnreachableException
import java.net.SocketTimeoutException

/**
 * Sends a DNS query and times the reply.
 *
 * Every bundled preset is a DNS resolver, so a minimal query for the root
 * zone is the cheapest payload that provokes a real answer. A custom target
 * on a non-DNS port will time out, which is the honest result rather than a
 * silent fallback to another protocol.
 */
class UdpProber(
    private val socketFactory: () -> DatagramSocket = { DatagramSocket() },
    private val clock: () -> Long = System::nanoTime,
) : Prober {
    override fun probe(
        address: String,
        port: Int,
        timeoutMillis: Int,
    ): ProbeResult {
        val socket = socketFactory()
        return try {
            socket.soTimeout = timeoutMillis
            val query = dnsRootQuery()
            val destination = InetAddress.getByName(address)
            val startedAt = clock()
            socket.send(DatagramPacket(query, query.size, destination, port))
            val reply = ByteArray(MAX_REPLY_BYTES)
            socket.receive(DatagramPacket(reply, reply.size))
            ProbeResult.success((clock() - startedAt) / 1_000)
        } catch (error: SocketTimeoutException) {
            ProbeResult.timeout()
        } catch (error: PortUnreachableException) {
            ProbeResult.unreachable()
        } catch (error: java.io.IOException) {
            ProbeResult.error()
        } finally {
            runCatching { socket.close() }
        }
    }

    internal companion object {
        private const val MAX_REPLY_BYTES = 512

        /** A standard-query header asking for the root zone's NS record. */
        fun dnsRootQuery(): ByteArray = byteArrayOf(
            0x2A, 0x2A, // transaction id
            0x01, 0x00, // standard query, recursion desired
            0x00, 0x01, // one question
            0x00, 0x00, // no answers
            0x00, 0x00, // no authority records
            0x00, 0x00, // no additional records
            0x00, // root name
            0x00, 0x02, // type NS
            0x00, 0x01, // class IN
        )
    }
}
