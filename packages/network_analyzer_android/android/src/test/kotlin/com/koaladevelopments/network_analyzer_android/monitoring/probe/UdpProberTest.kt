package com.koaladevelopments.network_analyzer_android.monitoring.probe

import kotlin.test.Test
import kotlin.test.assertEquals

internal class UdpProberTest {
    @Test
    fun dnsRootQuery_isAWellFormedStandardQuery() {
        val query = UdpProber.dnsRootQuery()

        assertEquals(17, query.size)
        assertEquals(0x01, query[2].toInt()) // recursion desired
        assertEquals(0x01, query[5].toInt()) // exactly one question
        assertEquals(0x00, query[12].toInt()) // root name
        assertEquals(0x02, query[14].toInt()) // type NS
        assertEquals(0x01, query[16].toInt()) // class IN
    }
}
