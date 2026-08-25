package com.koaladevelopments.network_analyzer_android.monitoring

/**
 * The error codes the native side raises across the channel.
 *
 * The Dart platform implementation maps each to a typed `Failure`, so no
 * `PlatformException` ever reaches a host application (constitution,
 * Principle III). Kept in one place because both platforms must agree.
 */
object MonitorErrors {
    const val PERMISSION_DENIED = "PERMISSION_DENIED"
    const val UNSUPPORTED_CAPABILITY = "UNSUPPORTED_CAPABILITY"
    const val GATEWAY_DISCOVERY_FAILED = "GATEWAY_DISCOVERY_FAILED"
    const val INVALID_CONFIGURATION = "INVALID_CONFIGURATION"
    const val TARGET_UNREACHABLE = "TARGET_UNREACHABLE"
    const val SESSION_ALREADY_RUNNING = "SESSION_ALREADY_RUNNING"
}
