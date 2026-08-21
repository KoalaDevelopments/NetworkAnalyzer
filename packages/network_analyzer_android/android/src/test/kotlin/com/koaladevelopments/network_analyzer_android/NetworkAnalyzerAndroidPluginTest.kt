package com.koaladevelopments.network_analyzer_android

import kotlin.test.Test
import kotlin.test.assertEquals

/*
 * Unit test of the Kotlin portion of the plugin. Runs on the JVM:
 * `./gradlew testDebugUnitTest` from the example app's android/ directory
 * after the example has been built once.
 */
internal class NetworkAnalyzerAndroidPluginTest {
    @Test
    fun getBridgeInfo_reportsAndroidIdentity() {
        val plugin = NetworkAnalyzerAndroidPlugin()

        val info = plugin.getBridgeInfo()

        assertEquals("android", info.operatingSystem)
        // android.os.Build.VERSION.RELEASE is null on the JVM; the plugin
        // must fall back instead of crashing.
        assertEquals("unknown", info.osVersion)
    }
}
