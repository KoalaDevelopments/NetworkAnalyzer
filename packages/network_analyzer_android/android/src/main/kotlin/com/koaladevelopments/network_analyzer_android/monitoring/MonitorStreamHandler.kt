package com.koaladevelopments.network_analyzer_android.monitoring

import android.os.Handler
import android.os.Looper
import com.koaladevelopments.network_analyzer_android.MonitorSignalMessage
import com.koaladevelopments.network_analyzer_android.PigeonEventSink
import com.koaladevelopments.network_analyzer_android.StreamMonitorSignalsStreamHandler

/**
 * Bridges the session controller to the pigeon event channel.
 *
 * Signals are produced on the controller's serial executor and marshalled
 * onto the main looper, which is where the Flutter engine requires them.
 *
 * Cancelling the last subscription stops probing: a session nobody is
 * listening to has no reason to keep using the radio.
 */
class MonitorStreamHandler(
    private val controller: MonitorSessionController,
    private val mainHandler: Handler = Handler(Looper.getMainLooper()),
) : StreamMonitorSignalsStreamHandler() {
    override fun onListen(
        p0: Any?,
        sink: PigeonEventSink<MonitorSignalMessage>,
    ) {
        controller.attachSink { signal -> mainHandler.post { sink.success(signal) } }
    }

    override fun onCancel(p0: Any?) {
        controller.attachSink { }
        controller.stopSession()
    }
}
