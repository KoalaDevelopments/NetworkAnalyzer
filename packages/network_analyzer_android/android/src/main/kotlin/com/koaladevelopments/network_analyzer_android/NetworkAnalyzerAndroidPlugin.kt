package com.koaladevelopments.network_analyzer_android

import com.koaladevelopments.network_analyzer_android.monitoring.AndroidNetworkInspector
import com.koaladevelopments.network_analyzer_android.monitoring.MonitorSessionController
import com.koaladevelopments.network_analyzer_android.monitoring.MonitorStreamHandler
import com.koaladevelopments.network_analyzer_android.monitoring.probe.IcmpProber
import com.koaladevelopments.network_analyzer_android.monitoring.probe.Prober
import com.koaladevelopments.network_analyzer_android.monitoring.probe.TcpProber
import com.koaladevelopments.network_analyzer_android.monitoring.probe.UdpProber
import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * Android entry point of the network_analyzer plugin.
 *
 * Exposes the pigeon-generated [MonitoringHostApi] over the engine's binary
 * messenger, plus the monitoring signal event channel. The wire layer lives
 * in Monitoring.g.kt, generated from pigeons/ — never hand-write channel
 * code (constitution, Principle II).
 */
class NetworkAnalyzerAndroidPlugin :
    FlutterPlugin,
    MonitoringHostApi {
    private var controller: MonitorSessionController? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val sessionController = MonitorSessionController(
            inspector = AndroidNetworkInspector(binding.applicationContext),
            proberFactory = ::proberFor,
        )
        controller = sessionController
        MonitoringHostApi.setUp(binding.binaryMessenger, this)
        StreamMonitorSignalsStreamHandler.register(
            binding.binaryMessenger,
            MonitorStreamHandler(sessionController),
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        MonitoringHostApi.setUp(binding.binaryMessenger, null)
        controller?.dispose()
        controller = null
    }

    override fun startSession(config: MonitorConfigMessage): SessionDataMessage =
        requireController().startSession(config)

    override fun stopSession() {
        controller?.stopSession()
    }

    override fun currentSession(): SessionDataMessage? =
        controller?.currentSession()

    private fun requireController(): MonitorSessionController =
        controller ?: throw FlutterError(
            "NOT_ATTACHED",
            "The plugin is not attached to a Flutter engine.",
            null,
        )

    private fun proberFor(protocol: ProtocolMessage): Prober = when (protocol) {
        ProtocolMessage.TCP -> TcpProber()
        ProtocolMessage.UDP -> UdpProber()
        ProtocolMessage.ICMP -> IcmpProber()
    }
}
