package com.koaladevelopments.network_analyzer_android.monitoring

import com.koaladevelopments.network_analyzer_android.FlutterError
import com.koaladevelopments.network_analyzer_android.InterfaceTypeMessage
import com.koaladevelopments.network_analyzer_android.KindMessage
import com.koaladevelopments.network_analyzer_android.MonitorConfigMessage
import com.koaladevelopments.network_analyzer_android.MonitorSignalMessage
import com.koaladevelopments.network_analyzer_android.NetworkStateMessage
import com.koaladevelopments.network_analyzer_android.OutcomeMessage
import com.koaladevelopments.network_analyzer_android.ProbeSampleMessage
import com.koaladevelopments.network_analyzer_android.ProtocolMessage
import com.koaladevelopments.network_analyzer_android.monitoring.probe.ProbeResult
import com.koaladevelopments.network_analyzer_android.monitoring.probe.Prober
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

private class FakeInspector(var facts: NetworkFacts) : NetworkInspector {
    var reads = 0
    override fun read(): NetworkFacts {
        reads++
        return facts
    }
}

private class FakeProber(private val results: MutableList<ProbeResult>) : Prober {
    var closed = false
    val probed = mutableListOf<Triple<String, Int, Int>>()

    override fun probe(address: String, port: Int, timeoutMillis: Int): ProbeResult {
        probed += Triple(address, port, timeoutMillis)
        return if (results.isEmpty()) ProbeResult.timeout() else results.removeAt(0)
    }

    override fun close() {
        closed = true
    }
}

internal class MonitorSessionControllerTest {
    private val executor = Executors.newSingleThreadScheduledExecutor()
    private var now = 0L

    private val wifi = NetworkFacts(
        interfaceType = InterfaceTypeMessage.WIFI,
        deviceIpAddress = "192.168.1.42",
        gatewayAddress = "192.168.1.1",
    )

    @AfterTest
    fun tearDown() {
        executor.shutdownNow()
    }

    private fun controllerFor(
        inspector: NetworkInspector,
        prober: Prober,
    ): MonitorSessionController = MonitorSessionController(
        inspector = inspector,
        proberFactory = { prober },
        executor = executor,
        monotonicNanos = { now },
        wallClockMillis = { 1_787_654_321_000L },
    )

    private fun internetConfig(
        fallback: String? = null,
        protocol: ProtocolMessage = ProtocolMessage.TCP,
    ) = MonitorConfigMessage(
        probeProtocol = protocol,
        kind = KindMessage.INTERNET,
        targetIPv4 = "8.8.8.8",
        fallbackIPv4 = fallback,
        targetName = "Google Public DNS",
        port = 53,
        probeIntervalMillis = 200,
        probeTimeoutMillis = 200,
    )

    private fun gatewayConfig(
        protocol: ProtocolMessage = ProtocolMessage.TCP,
    ) = MonitorConfigMessage(
        probeProtocol = protocol,
        kind = KindMessage.GATEWAY,
        targetIPv4 = null,
        fallbackIPv4 = null,
        targetName = null,
        port = 80,
        probeIntervalMillis = 200,
        probeTimeoutMillis = 200,
    )

    @Test
    fun startSession_reportsTheFactsAboutTheNewSession() {
        val controller = controllerFor(FakeInspector(wifi), FakeProber(mutableListOf()))

        val session = controller.startSession(internetConfig())

        assertEquals(InterfaceTypeMessage.WIFI, session.interfaceType)
        assertEquals("192.168.1.42", session.deviceIpAddress)
        assertEquals("8.8.8.8", session.targetAddress)
        assertEquals("Google Public DNS", session.targetName)
        assertEquals(1_787_654_321_000L, session.startedAtUtcMillis)
        controller.stopSession()
    }

    @Test
    fun startSession_isRejectedWhileASessionIsRunning() {
        val controller = controllerFor(FakeInspector(wifi), FakeProber(mutableListOf()))
        val first = controller.startSession(internetConfig())

        val error = assertFailsWith<FlutterError> {
            controller.startSession(internetConfig())
        }

        assertEquals(MonitorErrors.SESSION_ALREADY_RUNNING, error.code)
        // The running session is untouched by the rejected request.
        assertEquals(first.targetAddress, controller.currentSession()?.targetAddress)
        controller.stopSession()
    }

    @Test
    fun startSession_discoversTheGatewayWhenNoAddressIsSupplied() {
        val controller = controllerFor(FakeInspector(wifi), FakeProber(mutableListOf()))

        val session = controller.startSession(gatewayConfig())

        assertEquals("192.168.1.1", session.targetAddress)
        assertEquals("Gateway", session.targetName)
        controller.stopSession()
    }

    @Test
    fun startSession_failsWhenNoDefaultRouteExists() {
        val inspector = FakeInspector(wifi.copy(gatewayAddress = null))
        val controller = controllerFor(inspector, FakeProber(mutableListOf()))

        val error = assertFailsWith<FlutterError> {
            controller.startSession(gatewayConfig())
        }

        assertEquals(MonitorErrors.GATEWAY_DISCOVERY_FAILED, error.code)
        assertNull(controller.currentSession())
    }

    @Test
    fun startSession_rejectsUdpForAGatewayMonitor() {
        val controller = controllerFor(FakeInspector(wifi), FakeProber(mutableListOf()))

        val error = assertFailsWith<FlutterError> {
            controller.startSession(gatewayConfig(ProtocolMessage.UDP))
        }

        assertEquals(MonitorErrors.INVALID_CONFIGURATION, error.code)
    }

    @Test
    fun probeOnce_emitsOneSamplePerProbeIncludingLosses() {
        val signals = mutableListOf<MonitorSignalMessage>()
        val prober = FakeProber(
            mutableListOf(ProbeResult.success(20_000), ProbeResult.timeout()),
        )
        val controller = controllerFor(FakeInspector(wifi), prober)
        controller.attachSink { signals += it }
        controller.startSession(internetConfig())

        now = 1_000_000_000L
        controller.probeOnce()
        now = 2_000_000_000L
        controller.probeOnce()

        val samples = signals.filterIsInstance<ProbeSampleMessage>()
        assertEquals(2, samples.size)
        assertEquals(0L, samples[0].sequence)
        assertEquals(OutcomeMessage.SUCCESS, samples[0].outcome)
        assertEquals(20_000L, samples[0].roundTripMicros)
        assertEquals(1L, samples[1].sequence)
        assertEquals(OutcomeMessage.TIMEOUT, samples[1].outcome)
        assertNull(samples[1].roundTripMicros)
        controller.stopSession()
    }

    @Test
    fun probeOnce_switchesToTheFallbackAfterThreeConsecutiveFailures() {
        val signals = mutableListOf<MonitorSignalMessage>()
        val prober = FakeProber(mutableListOf())
        val controller = controllerFor(FakeInspector(wifi), prober)
        controller.attachSink { signals += it }
        controller.startSession(internetConfig(fallback = "8.8.4.4"))

        repeat(3) { controller.probeOnce() }

        assertEquals("8.8.4.4", controller.currentSession()?.targetAddress)
        assertTrue(
            signals.filterIsInstance<NetworkStateMessage>()
                .any { it.targetAddress == "8.8.4.4" },
        )

        // The fourth probe already targets the fallback, and the switch
        // never happens twice.
        controller.probeOnce()
        assertEquals("8.8.4.4", prober.probed.last().first)
        repeat(3) { controller.probeOnce() }
        assertEquals("8.8.4.4", controller.currentSession()?.targetAddress)
        controller.stopSession()
    }

    @Test
    fun probeOnce_reportsAnInterfaceChangeOnce() {
        val signals = mutableListOf<MonitorSignalMessage>()
        val inspector = FakeInspector(wifi)
        val controller = controllerFor(inspector, FakeProber(mutableListOf()))
        controller.attachSink { signals += it }
        controller.startSession(internetConfig())

        controller.probeOnce()
        inspector.facts = wifi.copy(
            interfaceType = InterfaceTypeMessage.CELLULAR4G,
            deviceIpAddress = "10.1.2.3",
        )
        controller.probeOnce()
        controller.probeOnce()

        val changes = signals.filterIsInstance<NetworkStateMessage>()
        assertEquals(1, changes.size)
        assertEquals(InterfaceTypeMessage.CELLULAR4G, changes.single().interfaceType)
        assertEquals("10.1.2.3", controller.currentSession()?.deviceIpAddress)
        controller.stopSession()
    }

    @Test
    fun stopSession_clearsTheSessionAndClosesTheProber() {
        val prober = FakeProber(mutableListOf())
        val controller = controllerFor(FakeInspector(wifi), prober)
        controller.startSession(internetConfig())
        assertNotNull(controller.currentSession())

        controller.stopSession()

        assertNull(controller.currentSession())
        assertTrue(prober.closed)
    }

    @Test
    fun stopSession_isANoOpWhenNothingIsRunning() {
        val controller = controllerFor(FakeInspector(wifi), FakeProber(mutableListOf()))

        controller.stopSession()
        controller.stopSession()

        assertNull(controller.currentSession())
    }

    @Test
    fun stopSession_haltsProbingWellInsideTheDocumentedBound() {
        val prober = FakeProber(mutableListOf())
        val controller = MonitorSessionController(
            inspector = FakeInspector(wifi),
            proberFactory = { prober },
            executor = executor,
            monotonicNanos = { now },
            wallClockMillis = { 0L },
        )
        controller.startSession(internetConfig())
        TimeUnit.MILLISECONDS.sleep(50)

        val startedAt = System.nanoTime()
        controller.stopSession()
        val elapsedMillis = (System.nanoTime() - startedAt) / 1_000_000

        assertTrue(elapsedMillis < 500, "stop took $elapsedMillis ms")
        val probesAtStop = prober.probed.size
        TimeUnit.MILLISECONDS.sleep(300)
        assertEquals(probesAtStop, prober.probed.size)
    }

    @Test
    fun startSession_rejectsIcmpOnAnIpv6OnlyNetwork() {
        // No IPv4 address is what an IPv6-only network looks like here.
        val inspector = FakeInspector(wifi.copy(deviceIpAddress = ""))
        val controller = controllerFor(inspector, FakeProber(mutableListOf()))

        val error = assertFailsWith<FlutterError> {
            controller.startSession(internetConfig(protocol = ProtocolMessage.ICMP))
        }

        assertEquals(MonitorErrors.UNSUPPORTED_CAPABILITY, error.code)
        assertNull(controller.currentSession())
    }

    @Test
    fun startSession_allowsTcpOnAnIpv6OnlyNetwork() {
        val inspector = FakeInspector(wifi.copy(deviceIpAddress = ""))
        val controller = controllerFor(inspector, FakeProber(mutableListOf()))

        val session = controller.startSession(internetConfig())

        assertEquals("8.8.8.8", session.targetAddress)
        controller.stopSession()
    }
}
