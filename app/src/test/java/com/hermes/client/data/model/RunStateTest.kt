package com.hermes.client.data.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class RunStateTest {

    @Test
    fun mapsServerStatuses() {
        assertEquals(RunState.COMPLETED, RunState.from("completed"))
        assertEquals(RunState.RUNNING, RunState.from("running"))
        assertEquals(RunState.STARTED, RunState.from("started"))
        assertEquals(RunState.FAILED, RunState.from("failed"))
        assertEquals(RunState.CANCELLED, RunState.from("canceled"))
        assertEquals(RunState.INTERRUPTED, RunState.from("interrupted"))
        assertEquals(RunState.UNKNOWN, RunState.from("weird"))
    }

    @Test
    fun terminalAndActive() {
        assertTrue(RunState.COMPLETED.isTerminal)
        assertTrue(RunState.FAILED.isTerminal)
        assertFalse(RunState.RUNNING.isTerminal)
        assertTrue(RunState.RUNNING.isActive)
    }
}
