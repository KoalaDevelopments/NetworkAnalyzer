package com.koaladevelopments.network_analyzer_android.monitoring.probe

import java.net.ConnectException
import java.net.InetSocketAddress
import java.net.NoRouteToHostException
import java.net.Socket
import java.net.SocketTimeoutException

/**
 * Times a TCP connection handshake to the target.
 *
 * The most portable probe: it needs no special socket permission and works
 * wherever outbound connections are allowed.
 *
 * A **refused** connection counts as a success, not a failure: the RST that
 * refuses it round-tripped from the target, which proves reachability and
 * carries a real timing. This matters most for gateway monitoring — many
 * routers listen on no TCP port at all, and answering "100% loss" about a
 * router that is demonstrably replying would be a false measurement.
 */
class TcpProber(
    private val socketFactory: () -> Socket = { Socket() },
    private val clock: () -> Long = System::nanoTime,
) : Prober {
    override fun probe(
        address: String,
        port: Int,
        timeoutMillis: Int,
    ): ProbeResult {
        val socket = socketFactory()
        val startedAt = clock()
        return try {
            socket.connect(InetSocketAddress(address, port), timeoutMillis)
            ProbeResult.success((clock() - startedAt) / 1_000)
        } catch (error: SocketTimeoutException) {
            ProbeResult.timeout()
        } catch (error: NoRouteToHostException) {
            ProbeResult.unreachable()
        } catch (error: ConnectException) {
            if (error.message?.contains("refused", ignoreCase = true) == true) {
                // The RST is a reply; time it like one.
                ProbeResult.success((clock() - startedAt) / 1_000)
            } else {
                ProbeResult.unreachable()
            }
        } catch (error: java.io.IOException) {
            ProbeResult.error()
        } finally {
            runCatching { socket.close() }
        }
    }
}
