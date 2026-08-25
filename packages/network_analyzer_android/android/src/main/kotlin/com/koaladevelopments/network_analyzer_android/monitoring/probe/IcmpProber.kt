package com.koaladevelopments.network_analyzer_android.monitoring.probe

import android.system.ErrnoException
import android.system.Os
import android.system.OsConstants
import android.system.StructTimeval
import java.io.FileDescriptor
import java.net.InetAddress
import java.net.InetSocketAddress

/**
 * Sends an ICMP echo request and times the echo reply.
 *
 * Uses an unprivileged ICMP *datagram* socket, which Android has permitted
 * since Lollipop, reached through [Os] — the platform's own BSD socket
 * surface. That avoids an NDK component, avoids shelling out to `ping`, and
 * avoids `InetAddress.isReachable`, which silently falls back to TCP and so
 * could not honestly report which protocol produced a measurement.
 *
 * IPv4 only in this version: an ICMPv6 echo needs a different checksum
 * computation over a pseudo-header. A caller on an IPv6-only network is told
 * so with an unsupported-capability failure rather than quietly switched to
 * another protocol.
 */
// ponytail: IPv4 only. ICMPv6 needs IPPROTO_ICMPV6 and a checksum over an
// IPv6 pseudo-header; add it here and drop the IPv6-only guard in
// MonitorSessionController if ICMP on IPv6-only networks becomes a
// requirement.
class IcmpProber(
    private val clock: () -> Long = System::nanoTime,
) : Prober {
    private var sequence = 0

    override fun probe(
        address: String,
        port: Int,
        timeoutMillis: Int,
    ): ProbeResult {
        var descriptor: FileDescriptor? = null
        return try {
            descriptor = Os.socket(
                OsConstants.AF_INET,
                OsConstants.SOCK_DGRAM,
                OsConstants.IPPROTO_ICMP,
            )
            Os.setsockoptTimeval(
                descriptor,
                OsConstants.SOL_SOCKET,
                OsConstants.SO_RCVTIMEO,
                StructTimeval.fromMillis(timeoutMillis.toLong()),
            )

            val current = sequence++
            val request = IcmpPacket.echoRequest(current)
            val destination = InetAddress.getByName(address)
            val startedAt = clock()
            Os.sendto(
                descriptor,
                request,
                0,
                request.size,
                0,
                destination,
                0,
            )

            val reply = ByteArray(REPLY_BUFFER_BYTES)
            val received = Os.recvfrom(
                descriptor,
                reply,
                0,
                reply.size,
                0,
                InetSocketAddress(0),
            )
            if (IcmpPacket.isEchoReply(reply, received, current)) {
                ProbeResult.success((clock() - startedAt) / 1_000)
            } else {
                ProbeResult.error()
            }
        } catch (error: ErrnoException) {
            when (error.errno) {
                // Android exposes only EAGAIN; EWOULDBLOCK is the same
                // errno value and is not declared in OsConstants.
                OsConstants.EAGAIN, OsConstants.ETIMEDOUT ->
                    ProbeResult.timeout()
                OsConstants.EHOSTUNREACH, OsConstants.ENETUNREACH ->
                    ProbeResult.unreachable()
                else -> ProbeResult.error()
            }
        } catch (error: java.io.IOException) {
            ProbeResult.error()
        } finally {
            descriptor?.let { runCatching { Os.close(it) } }
        }
    }

    private companion object {
        const val REPLY_BUFFER_BYTES = 128
    }
}
