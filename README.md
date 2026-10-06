# Hermes Android

一个原生 Android 客户端，用来连接自建的 **Hermes Agent**，UI 参考 RikkaHub 的设计语言。
它解决的核心痛点是：

> 派完任务 → 关掉 App → 任务在服务端继续跑 → 回来（或收到通知）就能拿到**完整结果**。

标准 OpenAI 客户端只会用 `/v1/chat/completions`（同步、关应用即断流），本应用改用 Hermes 的
**Runs API**（`POST /v1/runs` 异步发起 + `GET /v1/runs/{id}` 轮询 + `/events` SSE 可断可续），
从而做到真正的“断线可恢复”。

## 核心机制

```
用户发送消息
  └─ 本地先落库用户消息 + 助手占位消息 (Room)
  └─ POST /v1/runs  (Idempotency-Key 防重)  → 立刻拿到 run_id
  └─ run_id 持久化到 Room (runs 表)
  └─ 连接 GET /v1/runs/{id}/events 收流式进度
         message.delta / tool.started / tool.completed / run.completed ...
  └─ 每一批事件写回 Room → UI 实时渲染

用户杀掉进程 / 断网 / 切后台
  └─ 服务端继续执行任务（run 不依赖客户端连接）

重新打开 App
  └─ MainActivity.onCreate / onResume → RunManager.reconcileAll()
  └─ 遍历本地未终态 run → GET /v1/runs/{id}
        · 已终态 → 取 output 落库 + 发通知
        · 仍 running → 重新 attach /events
  └─ WorkManager 周期任务（15 分钟）在后台兜底对账并补发通知
```

- `: keepalive` 注释行由 `okhttp-sse` 自动忽略，不会误判断线。
- 事件里 `event` 字段是事件名（服务端把事件名放在 JSON 内，而不是 SSE 的 `event:` 行）。

## 目录结构

```
app/src/main/java/com/hermes/client/
├─ HermesApp.kt                 # @HiltAndroidApp + WorkManager Configuration.Provider
├─ MainActivity.kt              # 入口；通知深链；前台对账
├─ di/                          # Hilt 模块（网络、数据库、协程作用域）
├─ data/
│  ├─ model/                    # 领域模型 / 枚举
│  ├─ remote/                   # Retrofit API、DTO、动态 URL 拦截器、SSE 客户端
│  ├─ local/                    # Room 实体 / DAO / 数据库 / TypeConverter
│  ├─ prefs/                    # DataStore 设置
│  └─ repository/               # SessionRepository / ChatRepository / RunManager
├─ notifications/               # 完成通知
├─ worker/                      # WorkManager 对账 Worker
└─ ui/
   ├─ theme/                    # Material 3 深/浅色、动态取色
   ├─ markdown/                 # 自研 Markdown 渲染 + 代码高亮
   ├─ sessions/                 # 会话列表
   ├─ chat/                     # 聊天页
   └─ settings/                 # 设置页
```

## 技术栈

| 维度 | 选择 |
|---|---|
| 语言 / UI | Kotlin + Jetpack Compose + Material 3 |
| 架构 | MVVM + Repository（异步任务由 `RunManager` 单例统筹） |
| DI | Hilt |
| 网络 | Retrofit + OkHttp + okhttp-sse |
| 存储 | Room（会话/消息/run）+ DataStore（设置） |
| 后台 | WorkManager（周期对账 + 通知兜底） |
| 图片 | Coil |
| Markdown | 自研解析 + 渲染，代码块内置轻量语法高亮 |

minSdk 26 / targetSdk 35。

## 构建

前置：JDK 17+、Android SDK（platform 35、build-tools 35.0.0）。`local.properties` 指向 SDK：

```properties
sdk.dir=/path/to/Android/Sdk
```

```bash
./gradlew :app:assembleDebug      # 产物 app/build/outputs/apk/debug/app-debug.apk
./gradlew :app:testDebugUnitTest  # 单元测试
```

## 使用

1. 打开 **设置**，填写 Hermes API 的 `Base URL`（可带路径前缀，如 `https://host/hermes-api`）和 `API Key`，点 **测试连接**（打 `GET /v1/models`）。
2. 回到会话列表，点 **新会话** 开始对话。
3. 长任务可以直接发，返回或杀进程都不影响；完成时收到系统通知，点通知直达该会话。
4. 聊天页右上角可 **同步服务端历史**、重命名；长按用户消息可编辑重发 / 重新生成。
5. 发送中的任务可点 **停止** 中断；输入框支持图片 / 文件附件。

## 已实现的接口

| 端点 | 用途 |
|---|---|
| `GET /health`、`GET /v1/models`、`GET /v1/capabilities` | 连接与能力探测 |
| `POST /v1/runs` | 异步发起任务（带 `Idempotency-Key`） |
| `GET /v1/runs/{id}` | 轮询状态（断线恢复核心） |
| `GET /v1/runs/{id}/events` | SSE 事件流 |
| `POST /v1/runs/{id}/stop` / `/steer` | 中断 / 插话 |
| `GET /api/sessions/{id}/messages` | 服务端权威历史兜底 |

## 许可

本项目以 **AGPL-3.0** 开源（UI 设计参考 RikkaHub，后者同样是 AGPL-3.0）。
