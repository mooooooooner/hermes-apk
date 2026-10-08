package com.hermes.client

import javax.inject.Inject
import javax.inject.Singleton

/**
 * Process-level foreground state, fed from activity started/stopped callbacks by [HermesApp].
 * Used to decide whether a run-completion notification is useful at all.
 */
@Singleton
class AppVisibility @Inject constructor() {
    @Volatile
    var isForeground: Boolean = false
        private set

    private var startedActivities = 0

    fun onActivityStarted() {
        startedActivities += 1
        if (startedActivities == 1) isForeground = true
    }

    fun onActivityStopped() {
        startedActivities = (startedActivities - 1).coerceAtLeast(0)
        if (startedActivities == 0) isForeground = false
    }
}

/**
 * The chat session currently on screen. RunManager suppresses the system notification when the
 * user is already watching the session that finished — the live UI shows the outcome.
 */
@Singleton
class ChatVisibility @Inject constructor() {
    @Volatile
    var foregroundSessionId: String? = null
}
