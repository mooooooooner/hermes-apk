package com.hermes.client.ui.settings

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.Visibility
import androidx.compose.material.icons.rounded.VisibilityOff
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.hermes.client.BuildConfig
import com.hermes.client.data.prefs.ThemeMode

@Composable
fun SettingsRoute(
    onBack: () -> Unit,
    viewModel: SettingsViewModel = hiltViewModel(),
) {
    val settings by viewModel.settings.collectAsStateWithLifecycle()
    val test by viewModel.test.collectAsStateWithLifecycle()

    SettingsScreen(
        baseUrl = settings.baseUrl,
        apiKey = settings.apiKey,
        themeMode = settings.themeMode,
        dynamicColor = settings.dynamicColor,
        systemInstructions = settings.systemInstructions,
        showReasoning = settings.showReasoning,
        toolProgress = settings.toolProgress,
        test = test,
        onBack = onBack,
        onSaveConnection = viewModel::saveConnection,
        onTestConnection = viewModel::testConnection,
        onSaveInstructions = viewModel::saveSystemInstructions,
        onThemeMode = viewModel::setThemeMode,
        onDynamicColor = viewModel::setDynamicColor,
        onShowReasoning = viewModel::setShowReasoning,
        onToolProgress = viewModel::setToolProgress,
        onClearTest = viewModel::clearTest,
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    baseUrl: String,
    apiKey: String,
    themeMode: ThemeMode,
    dynamicColor: Boolean,
    systemInstructions: String,
    showReasoning: Boolean,
    toolProgress: Boolean,
    test: ConnectionTest,
    onBack: () -> Unit,
    onSaveConnection: (String, String) -> Unit,
    onTestConnection: (String, String) -> Unit,
    onSaveInstructions: (String) -> Unit,
    onThemeMode: (ThemeMode) -> Unit,
    onDynamicColor: (Boolean) -> Unit,
    onShowReasoning: (Boolean) -> Unit,
    onToolProgress: (Boolean) -> Unit,
    onClearTest: () -> Unit,
) {
    var baseUrlField by remember(baseUrl) { mutableStateOf(baseUrl) }
    var apiKeyField by remember(apiKey) { mutableStateOf(apiKey) }
    var instructionsField by remember(systemInstructions) { mutableStateOf(systemInstructions) }
    var keyVisible by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("设置") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Rounded.ArrowBack, contentDescription = "返回")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background,
                ),
            )
        },
        containerColor = MaterialTheme.colorScheme.background,
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            SectionTitle("服务器")
            OutlinedTextField(
                value = baseUrlField,
                onValueChange = { baseUrlField = it },
                modifier = Modifier.fillMaxWidth(),
                label = { Text("Base URL") },
                placeholder = { Text("https://example.com/hermes-api") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(
                    keyboardType = KeyboardType.Uri,
                    imeAction = ImeAction.Next,
                ),
            )
            OutlinedTextField(
                value = apiKeyField,
                onValueChange = { apiKeyField = it },
                modifier = Modifier.fillMaxWidth(),
                label = { Text("API Key") },
                singleLine = true,
                visualTransformation = if (keyVisible) VisualTransformation.None
                else PasswordVisualTransformation(),
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                trailingIcon = {
                    IconButton(onClick = { keyVisible = !keyVisible }) {
                        Icon(
                            if (keyVisible) Icons.Rounded.VisibilityOff else Icons.Rounded.Visibility,
                            contentDescription = null,
                        )
                    }
                },
            )
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Button(
                    onClick = { onSaveConnection(baseUrlField, apiKeyField); onClearTest() },
                ) { Text("保存") }
                Button(
                    onClick = { onTestConnection(baseUrlField, apiKeyField) },
                ) {
                    if (test is ConnectionTest.Loading) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(16.dp),
                            strokeWidth = 2.dp,
                            color = MaterialTheme.colorScheme.onPrimary,
                        )
                        Spacer(Modifier.width(8.dp))
                    }
                    Text("测试连接")
                }
            }
            when (test) {
                is ConnectionTest.Success -> Text(
                    text = "✅ 连接成功，模型：" + test.models.joinToString().ifBlank { "(无)" },
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.primary,
                )
                is ConnectionTest.Failure -> Text(
                    text = "❌ ${test.message}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.error,
                )
                else -> Unit
            }

            Spacer(Modifier.height(6.dp))
            SectionTitle("外观")
            Text(
                text = "主题",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                ThemeMode.entries.forEach { mode ->
                    FilterChip(
                        selected = themeMode == mode,
                        onClick = { onThemeMode(mode) },
                        label = {
                            Text(
                                when (mode) {
                                    ThemeMode.SYSTEM -> "跟随系统"
                                    ThemeMode.LIGHT -> "浅色"
                                    ThemeMode.DARK -> "深色"
                                },
                            )
                        },
                    )
                }
            }
            SettingSwitch(
                title = "动态取色 (Material You)",
                subtitle = "Android 12+ 使用系统壁纸配色",
                checked = dynamicColor,
                onChange = onDynamicColor,
            )

            Spacer(Modifier.height(6.dp))
            SectionTitle("对话")
            SettingSwitch(
                title = "显示思考过程",
                subtitle = "展示服务端返回的 reasoning",
                checked = showReasoning,
                onChange = onShowReasoning,
            )
            SettingSwitch(
                title = "显示工具调用进度",
                subtitle = "展示 tool.started / tool.completed",
                checked = toolProgress,
                onChange = onToolProgress,
            )
            OutlinedTextField(
                value = instructionsField,
                onValueChange = { instructionsField = it },
                modifier = Modifier.fillMaxWidth(),
                label = { Text("系统指令 (instructions)") },
                placeholder = { Text("可选，作为每次任务的系统提示") },
                minLines = 2,
                maxLines = 6,
            )
            Button(
                onClick = { onSaveInstructions(instructionsField) },
                enabled = instructionsField != systemInstructions,
            ) { Text("保存系统指令") }

            Spacer(Modifier.height(6.dp))
            SectionTitle("关于")
            Text(
                text = "Hermes Android v${BuildConfig.VERSION_NAME}",
                style = MaterialTheme.typography.bodyMedium,
            )
            Text(
                text = "使用 Hermes Runs API：异步发起、断线可恢复、完成即通知。",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(24.dp))
        }
    }
}

@Composable
private fun SectionTitle(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.titleMedium,
        color = MaterialTheme.colorScheme.primary,
        modifier = Modifier.padding(top = 8.dp),
    )
}

@Composable
private fun SettingSwitch(
    title: String,
    subtitle: String,
    checked: Boolean,
    onChange: (Boolean) -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(text = title, style = MaterialTheme.typography.bodyLarge)
            Text(
                text = subtitle,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Switch(checked = checked, onCheckedChange = onChange)
    }
}
