package com.hermes.client

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import androidx.lifecycle.lifecycleScope
import com.hermes.client.data.repository.RunManager
import com.hermes.client.ui.HermesRoot
import dagger.hilt.android.AndroidEntryPoint
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@AndroidEntryPoint
class MainActivity : ComponentActivity() {

    @Inject lateinit var runManager: RunManager

    private val pendingSessionId = MutableStateFlow<String?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        installSplashScreen()
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        handleIntent(intent)

        // Anything the server finished while we were gone is reconciled on entry.
        lifecycleScope.launch { runManager.reconcileAll() }

        setContent {
            HermesRoot(
                pendingSessionId = pendingSessionId,
                onSessionConsumed = { pendingSessionId.value = null },
            )
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        lifecycleScope.launch { runManager.reconcileAll() }
    }

    private fun handleIntent(intent: Intent?) {
        val sessionId = intent?.getStringExtra(EXTRA_SESSION_ID)
        if (!sessionId.isNullOrBlank()) {
            pendingSessionId.value = sessionId
        }
    }

    companion object {
        const val EXTRA_SESSION_ID = "extra_session_id"
    }
}
