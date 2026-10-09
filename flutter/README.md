# Hermes Client (Flutter)

Hermes Agent 客户端的 Flutter 移植版，与仓库根目录的原生 Android 版（Kotlin + Jetpack Compose）功能对等，目标平台 **Windows + Android**。UI 延续原版的 Material 3 暖色调风格（Claude / RikkaHub 风格）。

## 功能

- **会话与消息**：异步 Runs API（发起 → SSE 流式接收 → 落库渲染），思维链 / 工具调用 / 正文分段展示
- **断线可恢复**：运行状态持久化到本地 SQLite（drift），启动 / 回前台自动 reconcile，Android 端 WorkManager 周期兜底
- **附件双向传输**：图片 / 文件上传（含 base64 内联），语音消息录制；配套文件服务地址自动推导
- **完成通知**：后台任务完成 / 失败时系统通知，点击深链到对应会话（Android 用 flutter_local_notifications，Windows 用 local_notifier）
- **Markdown 渲染**：标题 / 列表 / 引用 / 表格 / 代码高亮 / 图片（带文件服务鉴权头）

## 目录结构

```
lib/
  core/            可见性状态、格式化工具
  data/
    local/         drift 数据库（messages + runs 联表观察）
    prefs/         设置持久化（shared_preferences）
    remote/        dio REST 客户端、动态 URL 拦截器、SSE 流解析
    repository/    ChatRepository / RunManager / HistoryFolder 等业务层
  notifications/   完成通知
  ui/              主题、Markdown 渲染、聊天 / 会话列表 / 设置界面
  worker/          WorkManager 调度（仅 Android，Windows no-op）
  di.dart          手写 DI 容器（init / initForBackground）
```

## 开发

```bash
flutter pub get
dart run build_runner build   # 生成 drift 代码（database.g.dart 已提交，可跳过）
flutter analyze
flutter test
```

## 构建

```bash
flutter build windows   # build\windows\x64\runner\Release\hermes_client.exe
flutter build apk       # build\app\outputs\flutter-apk\app-release.apk
```

Android `applicationId` 为 `com.hermes.client`，minSdk 26。允许明文 http（用户可配置内网服务器地址），见 `android/app/src/main/res/xml/network_security_config.xml`。

## 与原生版的关系

- 协议约定（JSON 形状、SSE 解析、文件服务地址推导规则）与 Kotlin 版完全一致，可直接对接同一服务端
- 单元测试移植自原生版（url_resolver / files_base_url / run_state / markdown / syntax_highlighter / history_folder）
- 许可证：AGPL-3.0（随仓库根目录）
