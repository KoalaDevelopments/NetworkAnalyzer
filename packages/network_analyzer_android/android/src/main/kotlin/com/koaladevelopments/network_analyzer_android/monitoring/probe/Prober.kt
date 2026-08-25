package com.koaladevelopments.network_analyzer_android.monitoring.probe

import com.koaladevelopments.network_analyzer_android.OutcomeMessage

/**
 * The outcome of a single probe.
 *
 * [roundTripMicros] is present only when [outcome] is
 * [OutcomeMessage.SUCCESS]; a failed probe reports no timing rather than a
 * fabricated one.
 */
data class ProbeResult(
    val outcome: OutcomeMessage,
    val roundTripMicros: Long?,
) {
    companion object {
        /** A probe that completed, timed monotonically. */
        fun success(roundTripMicros: Long) =
            ProbeResult(OutcomeMessage.SUCCESS, roundTripMicros)

        /** A probe the target did not answer in time. */
        fun timeout() = ProbeResult(OutcomeMessage.TIMEOUT, null)

        /** A probe whose target could not be reached at all. */
        fun unreachable() = ProbeResult(OutcomeMessage.UNREACHABLE, null)

        /** A probe that failed for any other reason. */
        fun error() = ProbeResult(OutcomeMessage.ERROR, null)
    }
}

/**
 * Sends one probe and times it.
 *
 * Implementations are protocol-specific, take an explicit timeout, and time
 * with [System.nanoTime] so a device clock change cannot distort a
 * measurement. They are constructed per session and closed when it ends.
 */
interface Prober {
    /** Probes [address] on [port], giving up after [timeoutMillis]. */
    fun probe(address: String, port: Int, timeoutMillis: Int): ProbeResult

    /** Releases any socket held between probes. */
    fun close() {}
}
