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
import com.koaladevelopments.network_analyzer_android.SessionDataMessage
import com.koaladevelopments.network_analyzer_android.monitoring.probe.Prober
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.ScheduledFuture
import java.util.concurrent.TimeUnit

/**
 * Owns the probe loop and every piece of mutable session state.
 *
 * All state is confined to one serial executor, which is what makes the
 * lifecycle safe without locks. Timing is monotonic throughout; the only
 * wall clock reading is the session's start instant, which exists to be
 * shown to a person.
 *
 * The controller emits raw samples and nothing derived. Packet loss,
 * jitter, spikes and the health verdict are computed once in Dart so the two
 * platforms cannot drift apart.
 */
class MonitorSessionController(
    private val inspector: NetworkInspector,
    private val proberFactory: (ProtocolMessage) -> Prober,
    private val executor: ScheduledExecutorService =
        Executors.newSingleThreadScheduledExecutor(),
    private val monotonicNanos: () -> Long = System::nanoTime,
    private val wallClockMillis: () -> Long = System::currentTimeMillis,
) {
    private var session: SessionDataMessage? = null
    private var prober: Prober? = null
    private var task: ScheduledFuture<*>? = null
    private var sink: ((MonitorSignalMessage) -> Unit)? = null

    private var sequence = 0
    private var startedAtNanos = 0L
    private var consecutiveFailures = 0
    private var targetAddress = ""
    private var fallbackAddress: String? = null
    private var usedFallback = false
    private var port = 0
    private var timeoutMillis = 0
    private var lastFacts: NetworkFacts? = null

    /** The running session, or null when none is running. */
    fun currentSession(): SessionDataMessage? = session

    /** Routes emitted signals to the event channel sink. */
    fun attachSink(sink: (MonitorSignalMessage) -> Unit) {
        this.sink = sink
    }

    /**
     * Starts probing and returns the facts about the new session.
     *
     * Throws a [FlutterError] carrying one of the [MonitorErrors] codes when
     * a session is already running, when the configuration is invalid, or
     * when a gateway target cannot be discovered. The Dart side turns each
     * into a typed failure.
     */
    fun startSession(config: MonitorConfigMessage): SessionDataMessage {
        if (session != null) {
            throw FlutterError(
                MonitorErrors.SESSION_ALREADY_RUNNING,
                "A monitoring session is already running.",
                null,
            )
        }
        if (config.kind == KindMessage.GATEWAY &&
            config.probeProtocol == ProtocolMessage.UDP
        ) {
            throw FlutterError(
                MonitorErrors.INVALID_CONFIGURATION,
                "A gateway monitor accepts only TCP and ICMP.",
                null,
            )
        }

        val facts = inspector.read()
        if (config.probeProtocol == ProtocolMessage.ICMP &&
            facts.deviceIpAddress.isEmpty()
        ) {
            // No IPv4 address means an IPv6-only network. TCP and UDP still
            // work there through NAT64 synthesis, but an ICMPv6 echo needs a
            // different checksum over a pseudo-header, which this version
            // does not implement. Say so rather than silently probing with
            // another protocol.
            throw FlutterError(
                MonitorErrors.UNSUPPORTED_CAPABILITY,
                "ICMP monitoring requires IPv4; this network is IPv6-only.",
                null,
            )
        }
        val resolved = resolveTarget(config, facts)
        val started = SessionDataMessage(
            interfaceType = facts.interfaceType,
            probeProtocol = config.probeProtocol,
            kind = config.kind,
            deviceIpAddress = facts.deviceIpAddress,
            targetAddress = resolved,
            targetName = config.targetName ?: GATEWAY_TARGET_NAME,
            startedAtUtcMillis = wallClockMillis(),
        )

        session = started
        lastFacts = facts
        targetAddress = resolved
        fallbackAddress = config.fallbackIPv4
        usedFallback = false
        port = config.port.toInt()
        timeoutMillis = config.probeTimeoutMillis.toInt()
        sequence = 0
        consecutiveFailures = 0
        startedAtNanos = monotonicNanos()
        prober = proberFactory(config.probeProtocol)

        val interval = config.probeIntervalMillis
        task = executor.scheduleAtFixedRate(
            ::probeOnce,
            0,
            interval,
            TimeUnit.MILLISECONDS,
        )
        return started
    }

    /**
     * Stops probing and clears all session state.
     *
     * A no-op when nothing is running, so callers never have to guard it.
     * The scheduled task is cancelled and the socket closed immediately, so
     * probing ceases well inside the documented 500 ms bound.
     */
    fun stopSession() {
        task?.cancel(true)
        task = null
        prober?.let { runCatching { it.close() } }
        prober = null
        session = null
        lastFacts = null
    }

    /** Releases the executor when the plugin detaches from the engine. */
    fun dispose() {
        stopSession()
        executor.shutdownNow()
    }

    private fun resolveTarget(
        config: MonitorConfigMessage,
        facts: NetworkFacts,
    ): String = when (config.kind) {
        KindMessage.INTERNET -> config.targetIPv4
            ?: throw FlutterError(
                MonitorErrors.INVALID_CONFIGURATION,
                "An internet monitor requires a target address.",
                null,
            )
        KindMessage.GATEWAY -> facts.gatewayAddress
            ?: throw FlutterError(
                MonitorErrors.GATEWAY_DISCOVERY_FAILED,
                "No default route is available on the current network.",
                null,
            )
    }

    internal fun probeOnce() {
        val activeProber = prober ?: return
        val result = activeProber.probe(targetAddress, port, timeoutMillis)
        val current = sequence++
        emit(
            ProbeSampleMessage(
                sequence = current.toLong(),
                roundTripMicros = result.roundTripMicros,
                outcome = result.outcome,
                elapsedMicros = (monotonicNanos() - startedAtNanos) / 1_000,
            ),
        )
        trackFailures(result.outcome)
        reportNetworkChange()
    }

    private fun trackFailures(outcome: OutcomeMessage) {
        if (outcome == OutcomeMessage.SUCCESS) {
            consecutiveFailures = 0
            return
        }
        consecutiveFailures++
        val fallback = fallbackAddress
        if (!usedFallback &&
            fallback != null &&
            consecutiveFailures >= FAILURES_BEFORE_FALLBACK
        ) {
            // Switch once and never switch back: flapping between two
            // addresses would corrupt the session's latency aggregates.
            usedFallback = true
            targetAddress = fallback
            consecutiveFailures = 0
            session = session?.copy(targetAddress = fallback)
            emit(
                NetworkStateMessage(
                    interfaceType = lastFacts?.interfaceType
                        ?: InterfaceTypeMessage.UNKNOWN,
                    deviceIpAddress = null,
                    targetAddress = fallback,
                ),
            )
        }
    }

    private fun reportNetworkChange() {
        val facts = inspector.read()
        val previous = lastFacts
        if (previous != null &&
            previous.interfaceType == facts.interfaceType &&
            previous.deviceIpAddress == facts.deviceIpAddress
        ) {
            return
        }
        lastFacts = facts
        session = session?.copy(
            interfaceType = facts.interfaceType,
            deviceIpAddress = facts.deviceIpAddress,
        )
        emit(
            NetworkStateMessage(
                interfaceType = facts.interfaceType,
                deviceIpAddress = facts.deviceIpAddress,
                targetAddress = null,
            ),
        )
    }

    private fun emit(signal: MonitorSignalMessage) {
        sink?.invoke(signal)
    }

    private companion object {
        const val FAILURES_BEFORE_FALLBACK = 3
        const val GATEWAY_TARGET_NAME = "Gateway"
    }
}
