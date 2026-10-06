package com.hermes.client.ui

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.core.content.ContextCompat
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.hermes.client.ui.chat.ChatRoute
import com.hermes.client.ui.sessions.SessionListRoute
import com.hermes.client.ui.settings.SettingsRoute
import com.hermes.client.ui.theme.HermesTheme
import kotlinx.coroutines.flow.StateFlow

object Routes {
    const val SESSIONS = "sessions"
    const val SETTINGS = "settings"
    const val CHAT = "chat/{sessionId}"
    fun chat(sessionId: String) = "chat/$sessionId"
}

@Composable
fun HermesRoot(
    pendingSessionId: StateFlow<String?>,
    onSessionConsumed: () -> Unit,
) {
    val mainViewModel: MainViewModel = hiltViewModel()
    val settings by mainViewModel.settings.collectAsStateWithLifecycle()

    HermesTheme(themeMode = settings.themeMode, dynamicColor = settings.dynamicColor) {
        val navController = rememberNavController()
        val deepLink by pendingSessionId.collectAsStateWithLifecycle()

        LaunchedEffect(deepLink) {
            deepLink?.let { sessionId ->
                navController.navigate(Routes.chat(sessionId)) { launchSingleTop = true }
                onSessionConsumed()
            }
        }

        // Ask for notification permission once (Android 13+).
        val permissionLauncher = rememberLauncherForActivityResult(
            ActivityResultContracts.RequestPermission(),
        ) { }
        LaunchedEffect(Unit) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                val context = navController.context
                if (ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) !=
                    PackageManager.PERMISSION_GRANTED
                ) {
                    permissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                }
            }
        }

        NavHost(navController = navController, startDestination = Routes.SESSIONS) {
            composable(Routes.SESSIONS) {
                SessionListRoute(
                    onOpenSession = { navController.navigate(Routes.chat(it)) },
                    onOpenSettings = { navController.navigate(Routes.SETTINGS) },
                )
            }
            composable(Routes.SETTINGS) {
                SettingsRoute(onBack = { navController.popBackStack() })
            }
            composable(
                route = Routes.CHAT,
                arguments = listOf(navArgument("sessionId") { type = NavType.StringType }),
            ) {
                ChatRoute(onBack = { navController.popBackStack() })
            }
        }
    }
}
