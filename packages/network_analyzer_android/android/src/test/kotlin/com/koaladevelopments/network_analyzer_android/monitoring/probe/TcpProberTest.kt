package com.koaladevelopments.network_analyzer_android.monitoring.probe

import com.koaladevelopments.network_analyzer_android.OutcomeMessage
import java.io.IOException
import java.net.ConnectException
import java.net.Socket
import java.net.SocketAddress
import java.net.SocketTimeoutException
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

private class FakeSocket(private val onConnect: () -> Unit) : Socket() {
    override fun connect(endpoint: SocketAddress?, timeout: Int) = onConnect()
    override fun close() {}
}

internal class TcpProberTest {
    private var now = 0L
    private val clock: () -> Long = { now }

    @Test
    fun probe_reportsAMonotonicRoundTripOnSuccess() {
        val prober = TcpProber(
            socketFactory = { FakeSocket { now += 20_000_000L } },
            clock = clock,
        )

        val result = prober.probe("8.8.8.8", 53, timeoutMillis = 1_000)

        assertEquals(OutcomeMessage.SUCCESS, result.outcome)
        assertEquals(20_000L, result.roundTripMicros)
    }

    @Test
    fun probe_reportsTimeoutWhenTheTargetDoesNotAnswer() {
        val prober = TcpProber(
            socketFactory = { FakeSocket { throw SocketTimeoutException() } },
            clock = clock,
        )

        val result = prober.probe("8.8.8.8", 53, timeoutMillis = 1_000)

        assertEquals(OutcomeMessage.TIMEOUT, result.outcome)
        assertNull(result.roundTripMicros)
    }

    @Test
    fun probe_countsARefusedConnectionAsAReplyWithTiming() {
        // The RST round-tripped from the target: reachability proven, and
        // the elapsed time to the refusal is a real measurement. Routers
        // that listen on no TCP port at all depend on this.
        val prober = TcpProber(
            socketFactory = {
                FakeSocket {
                    now += 15_000_000L
                    throw ConnectException("Connection refused")
                }
            },
            clock = clock,
        )

        val result = prober.probe("192.168.1.1", 80, timeoutMillis = 1_000)

        assertEquals(OutcomeMessage.SUCCESS, result.outcome)
        assertEquals(15_000L, result.roundTripMicros)
    }

    @Test
    fun probe_reportsUnreachableForANonRefusalConnectException() {
        val prober = TcpProber(
            socketFactory = {
                FakeSocket { throw ConnectException("Network is unreachable") }
            },
            clock = clock,
        )

        val result = prober.probe("8.8.8.8", 53, timeoutMillis = 1_000)

        assertEquals(OutcomeMessage.UNREACHABLE, result.outcome)
        assertNull(result.roundTripMicros)
    }

    @Test
    fun probe_reportsErrorForAnyOtherIoFailure() {
        val prober = TcpProber(
            socketFactory = { FakeSocket { throw IOException("broken") } },
            clock = clock,
        )

        val result = prober.probe("8.8.8.8", 53, timeoutMillis = 1_000)

        assertEquals(OutcomeMessage.ERROR, result.outcome)
    }
}
