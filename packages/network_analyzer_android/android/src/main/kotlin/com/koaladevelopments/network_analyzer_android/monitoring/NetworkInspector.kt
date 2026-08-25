package com.koaladevelopments.network_analyzer_android.monitoring

import android.Manifest
import android.content.Context
import android.net.ConnectivityManager
import android.net.LinkProperties
import android.net.NetworkCapabilities
import android.telephony.TelephonyManager
import androidx.annotation.RequiresPermission
import com.koaladevelopments.network_analyzer_android.InterfaceTypeMessage
import java.net.Inet4Address

/** What the device's current network looks like. */
data class NetworkFacts(
    val interfaceType: InterfaceTypeMessage,
    val deviceIpAddress: String,
    val gatewayAddress: String?,
)

/**
 * Reads the current network's type, address and default gateway.
 *
 * An interface so the session controller can be unit-tested against fixed
 * facts without an Android framework.
 */
interface NetworkInspector {
    /** The device's current network situation. */
    fun read(): NetworkFacts
}

/**
 * Reads network facts from [ConnectivityManager].
 *
 * Cellular generation is best effort. From API 30 it requires
 * `READ_PHONE_STATE`, a dangerous runtime permission this plugin
 * deliberately does not declare — forcing it onto every host application to
 * refine a label would violate least privilege. Without it the connection is
 * honestly reported as [InterfaceTypeMessage.CELLULAR].
 */
class AndroidNetworkInspector(
    private val context: Context,
) : NetworkInspector {
    @RequiresPermission(anyOf = [Manifest.permission.READ_BASIC_PHONE_STATE, Manifest.permission.READ_PHONE_STATE])
    override fun read(): NetworkFacts {
        val manager = context.getSystemService(ConnectivityManager::class.java)
            ?: return NetworkFacts(InterfaceTypeMessage.UNKNOWN, "", null)
        val network = manager.activeNetwork
            ?: return NetworkFacts(InterfaceTypeMessage.NONE, "", null)
        val capabilities = manager.getNetworkCapabilities(network)
        val link = manager.getLinkProperties(network)
        return NetworkFacts(
            interfaceType = interfaceType(capabilities),
            deviceIpAddress = deviceAddress(link),
            gatewayAddress = defaultGateway(link),
        )
    }

    @RequiresPermission(anyOf = [Manifest.permission.READ_BASIC_PHONE_STATE, Manifest.permission.READ_PHONE_STATE])
    private fun interfaceType(
        capabilities: NetworkCapabilities?,
    ): InterfaceTypeMessage = when {
        capabilities == null -> InterfaceTypeMessage.UNKNOWN
        capabilities.hasTransport(NetworkCapabilities.TRANSPORT_VPN) ->
            InterfaceTypeMessage.VPN
        capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) ->
            InterfaceTypeMessage.ETHERNET
        capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ->
            InterfaceTypeMessage.WIFI
        capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) ->
            cellularGeneration()
        else -> InterfaceTypeMessage.OTHER
    }

    @RequiresPermission(anyOf = [Manifest.permission.READ_BASIC_PHONE_STATE, Manifest.permission.READ_PHONE_STATE])
    private fun cellularGeneration(): InterfaceTypeMessage {
        val telephony = context.getSystemService(TelephonyManager::class.java)
            ?: return InterfaceTypeMessage.CELLULAR
        // Without READ_PHONE_STATE this throws; degrading is the honest
        // answer, and never a guess at the generation.
        val networkType = try {
            telephony.dataNetworkType
        } catch (_: SecurityException) {
            return InterfaceTypeMessage.CELLULAR
        }
        return when (networkType) {
            TelephonyManager.NETWORK_TYPE_NR -> InterfaceTypeMessage.CELLULAR5G
            TelephonyManager.NETWORK_TYPE_LTE,
            TelephonyManager.NETWORK_TYPE_IWLAN,
            -> InterfaceTypeMessage.CELLULAR4G
            TelephonyManager.NETWORK_TYPE_UMTS,
            TelephonyManager.NETWORK_TYPE_HSDPA,
            TelephonyManager.NETWORK_TYPE_HSUPA,
            TelephonyManager.NETWORK_TYPE_HSPA,
            TelephonyManager.NETWORK_TYPE_HSPAP,
            TelephonyManager.NETWORK_TYPE_TD_SCDMA,
            -> InterfaceTypeMessage.CELLULAR3G
            TelephonyManager.NETWORK_TYPE_GPRS,
            TelephonyManager.NETWORK_TYPE_EDGE,
            TelephonyManager.NETWORK_TYPE_GSM,
            -> InterfaceTypeMessage.CELLULAR2G
            else -> InterfaceTypeMessage.CELLULAR
        }
    }

    private fun deviceAddress(link: LinkProperties?): String =
        link?.linkAddresses
            ?.firstOrNull { it.address is Inet4Address }
            ?.address
            ?.hostAddress
            ?: ""

    private fun defaultGateway(link: LinkProperties?): String? =
        link?.routes
            ?.firstOrNull { it.isDefaultRoute && it.gateway is Inet4Address }
            ?.gateway
            ?.hostAddress
}
