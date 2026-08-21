package com.koaladevelopments.network_analyzer_android

import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * Android entry point of the network_analyzer plugin.
 *
 * Exposes the pigeon-generated [NetworkAnalyzerHostApi] over the engine's
 * binary messenger. The wire layer lives in Messages.g.kt, generated from
 * pigeons/messages.dart — never hand-write channel code (constitution,
 * Principle II).
 */
class NetworkAnalyzerAndroidPlugin :
    FlutterPlugin,
    NetworkAnalyzerHostApi {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        NetworkAnalyzerHostApi.setUp(binding.binaryMessenger, this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        NetworkAnalyzerHostApi.setUp(binding.binaryMessenger, null)
    }

    override fun getBridgeInfo(): BridgeInfoMessage =
        BridgeInfoMessage(
            operatingSystem = "android",
            osVersion = android.os.Build.VERSION.RELEASE ?: "unknown",
        )
}
