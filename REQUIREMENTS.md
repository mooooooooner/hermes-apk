# Hermes 手机客户端（Android）— 需求文档

> 最后更新：2026-10-05

---

## 0. 一句话目标

做一个**原生 Android 客户端**，用 RikkaHub 的 UI 风格，连接自建 VPS 上的 Hermes Agent，
并且解决当前所有通道都解决不了的痛点：**派完任务关掉 app，回来还能拿到完整结果**。

---

## 1. 背景与动机

### 1.1 用户现状
- 用户在腾讯云首尔 VPS 上自建 Hermes Agent（`/usr/local/lib/hermes-agent`，git 安装）
- 日常通过**微信（iLink）**与 Hermes 对话
- 手机端日常使用的 LLM 客户端是 **RikkaHub**（用户明确表示喜欢它的 UI 风格）

### 1.2 现有通道的致命缺陷
| 通道 | 问题 |
|---|---|
| 微信 iLink | **服务端会话窗口约 4 分钟**，超时后 bot 完全发不出消息；不支持消息编辑 |
| Hermes Dashboard | 手机浏览器体验差，是桌面向布局 |
| RikkaHub + API Server | 走标准 OpenAI 同步流，**关掉 app 就断开、拿不到结果** |

### 1.3 为什么必须自己写
Hermes 内置的 **Runs API** 天生支持「异步发起 + 断线重连 + 事后拉取」，
但所有标准 OpenAI 客户端（RikkaHub、Open WebUI、ChatBox…）都只用 `/v1/chat/completions`，
**不会用 Runs API**。所以只有自研客户端才能拿到这个能力。

---

## 2. UI 风格基准：RikkaHub（严格执行）

### 2.1 参考来源
- 仓库：https://github.com/rikkahub/rikkahub
- 语言：**Kotlin**（Jetpack Compose）
- 默认分支：**master**（不是 main）
- 许可证：**AGPL-3.0** 
- 多模块结构：`app` / `ai` / `common` / `material3` / `highlight` / `mediagen` / `search` / `speech` / `web-ui` / `workspace` / `oauth`

### 2.2 许可证红线（重要）
RikkaHub 是 **AGPL-3.0**：
- ✅ 可以**拉源码阅读**、学习布局与设计语言
- ✅ 可以自己**重新实现**相似风格
- ✅**可以直接复制粘贴它的代码文件**，本项目同意以 AGPL-3.0 开源，且绝大部分情况下为自用
- 建议做法：参考**视觉规范**（配色、圆角、间距、层级、动效节奏），并复用部分代码

### 2.3 具体要参考什么
- 会话列表页的卡片密度与信息层级
- 聊天页的气泡样式、Markdown 渲染、代码块高亮、复制/重发交互
- 底部输入框的设计（附件按钮、发送按钮、语音入口）
- 抽屉/侧边栏导航结构
- 设置页的分组方式
- 深色 / 浅色主题的配色体系
- 动效：页面转场、消息进入、按钮反馈

---

## 3. 后端：Hermes API Server

### 3.1 接入方式
Hermes 提供 OpenAI 兼容的 HTTP API：

| 项目 | 值 |
|---|---|
| 监听 | `127.0.0.1:8642`（仅本机） |
| 公网暴露 | Cloudflare 隧道（systemd 服务 `hermes-api-tunnel.service`） |
| 认证 | `Authorization: Bearer <API_SERVER_KEY>` |
| 配置项 | `API_SERVER_ENABLED=true` / `API_SERVER_KEY`（在 `~/.hermes/.env`） |

> ⚠️ 当前是 **Cloudflare quick tunnel**，URL 每次进程重启都会变。
> **正式开发前应先换成命名隧道（固定域名）**，方法见 §6.3。

### 3.2 关键端点

**标准（同步）**
```
GET  /health
GET  /v1/models                      → [{id: "hermes-agent", ...}]
GET  /v1/capabilities                → 探测服务端支持哪些能力
POST /v1/chat/completions            → OpenAI 标准，支持 stream:true (SSE)
POST /v1/responses                   → OpenAI Responses API 格式
```

**Runs API（★ 本项目核心）**
```
POST /v1/runs                        → 发起异步任务，立刻返回 {run_id, status:"started"}
GET  /v1/runs/{run_id}               → 轮询状态（无需保持连接！）
GET  /v1/runs/{run_id}/events        → SSE 事件流，可 attach/detach
```

`POST /v1/runs` 请求体：
```json
{
  "input": "用户的消息文本",
  "session_id": "my-session-id",        // 可选，用于会话关联
  "instructions": "...",                // 可选，系统指令
  "conversation_history": [...]         // 可选
}
```
- 支持 `Idempotency-Key` 请求头（1–255 可见 ASCII），安全重试；重复会返回原 `run_id`
- 若 `session_id` 指向已存在的 Hermes 会话且未提供 history，会自动载入该会话的 transcript

`GET /v1/runs/{run_id}` 返回：
```json
{
  "object": "hermes.run",
  "run_id": "run_abc123",
  "status": "completed",              // started | running | completed | failed | cancelled | interrupted
  "session_id": "my-session-id",
  "model": "hermes-agent",
  "output": "Done.",
  "usage": {"input_tokens": 50, "output_tokens": 200, "total_tokens": 250,
            "cache_read_tokens": 40, "cache_write_tokens": 0},
  "runtime": {"provider": "...", "model": "...", "route_source": "global"}
}
```
> 终态会短暂保留（completed / failed / cancelled / interrupted），便于轮询和 UI 对账。

**SSE 事件类型**（`GET /v1/runs/{id}/events`）
```
message.delta        → 逐 token 文本增量
message.interim      → 中途助手消息（文本 + already_streamed 标志）
tool.started         → {tool, preview(参数)}
tool.completed       → {tool, duration, error, preview(结果，截断 500 字符)}
subagent.start       → 后台子代理启动
subagent.complete    → 后台子代理完成
run.completed        → 最终答案（★ 唯一携带完整 final answer 的事件）
run.interrupted      → 网关关闭导致中断
: keepalive          → 每 10 秒无事件时发送的注释行（客户端需忽略以 ':' 开头的行）
```

**会话历史**
```
GET  /api/sessions/{session_id}/messages   → 拉取完整历史（断线恢复用）
POST /api/sessions/{session_id}/chat
POST /api/sessions/{session_id}/chat/stream
```

### 3.3 断线恢复的正确姿势（本项目核心逻辑）
1. `POST /v1/runs` 发起任务 → 立刻拿到 `run_id`
2. **立刻把 `run_id` 持久化到本地数据库**（Room）
3. 连 `GET /v1/runs/{id}/events` 收流式进度（可选）
4. 用户关掉 app → 连接断开 → **任务在服务端继续跑**
5. 用户重新打开 app → 遍历本地未完成 run → `GET /v1/runs/{id}` 轮询状态
6. 若已是终态 → 取 `output` 展示；若仍 running → 重新连 events 流
7. 兜底：`GET /api/sessions/{id}/messages` 拉服务端权威历史

### 3.4 SSE 注意事项
- 服务端每 10 秒发 `: keepalive` 注释行，**不要因为空闲超时断开连接**
- 标准 SSE 客户端会忽略注释行；自写解析器必须跳过以 `:` 开头的行
- `tool_progress_events` 默认开启；若客户端解析不了命名事件，可关：
  `gateway.platforms.api_server.tool_progress_events: false`

---

## 4. 功能需求清单

### P0 — 必须有（MVP）
- [ ] 配置页：填写 Base URL + API Key，可测试连接（`GET /v1/models`）
- [ ] 会话列表（本地维护 session_id），新建 / 重命名 / 删除
- [ ] 聊天页：发消息、**流式显示**回复（`message.delta`）
- [ ] **长任务模式**：`POST /v1/runs` 异步发起，`run_id` 落库
- [ ] **断线恢复**：重开 app 自动对账未完成 run
- [ ] **完成通知**：任务终态时发 Android 通知（点通知直接跳到该会话）
- [ ] 工具调用进度展示（`tool.started` / `tool.completed`）
- [ ] Markdown 渲染 + 代码块语法高亮 + 一键复制
- [ ] 深色 / 浅色主题

### P1 — 重要
- [ ] 会话历史与 `session_id` 绑定（服务端权威 + 本地缓存）
- [ ] 图片，文件的附件上传（`content` 支持 `image_url`，远程 URL 或 `data:image/...`）
- [ ] 中断或插话正在跑的任务
- [ ] 重新生成 / 编辑重发
- [ ] 消息长按选择复制，以及其他的快捷复制
- [ ] `Idempotency-Key` 防止重复发起
- [ ] md的各类语法支持

### P2 — 锦上添花
- [ ] 语音输入（参 RikkaHub 的 speech 模块思路）
- [ ] 多服务器/多 profile 切换
- [ ] 会话搜索
- [ ] 子代理状态面板（`subagent.start` / `subagent.complete`）
- [ ] 用量统计（`usage` 字段）

---

## 5. 技术选型建议

| 维度 | 建议 | 理由 |
|---|---|---|
| 语言 | **Kotlin** | 与 RikkaHub 一致，参考 UI 时最省力 |
| UI | **Jetpack Compose + Material 3** | 现代 Android 标准，RikkaHub 同款 |
| 架构 | MVVM + Repository（或 MVI） | 主流、易测试 |
| DI | Hilt | 标准 |
| 网络 | Retrofit/OkHttp（普通请求） + **OkHttp SSE / okhttp-sse**（事件流） | SSE 需专门的 EventSource 实现 |
| 本地存储 | **Room**（会话、消息、run 记录） + DataStore（设置） | run_id 必须持久化 |
| 通知 | NotificationCompat + WorkManager（可选，用于轮询兜底） | 后台完成通知 |
| 图片 | Coil | 标准 |
| Markdown | 参考 RikkaHub：自研 `material3` + `highlight` 模块思路，或用 multiplatform-markdown-renderer / compose-richtext | 代码块高亮要有 |
| 最低版本 | minSdk 26 / targetSdk 35 左右 | 兼顾覆盖率与现代化 |

**构建**：Gradle Kotlin DSL（`build.gradle.kts`），建议单模块起步（`app`），
功能稳定后再考虑拆 `core-ui` / `core-network` 等模块。

---

## 6. 环境信息

### 6.1 VPS（Hermes 所在机器）
```
公网 IP   : 43.133.77.30
内网 IP   : 10.8.0.10
hostname  : VM-0-10-debian
OS        : Debian 13, 2 核 / 3.6G 内存 / 59G 磁盘
Docker    : 29.8.1（可用）
工作区     : /home/hermes-workspace（脚本、下载、产物一律放这里）
Hermes    : /usr/local/lib/hermes-agent（git 安装，`hermes` CLI 在 /root/.local/bin/hermes）
```

---

## 7. 验收标准

一个「能被天天用」的 MVP 至少要满足：

1. 手机上填入 VPS 的 API 地址和 key，能连通并列出模型
2. 发一条消息，能**逐字流式**看到回复
3. 发一个**需要 5 分钟以上**的任务，**立刻关掉 app**，
   5 分钟后重新打开 —— **能看到完整结果**（这是本项目存在的全部理由）
4. 任务完成时手机收到**系统通知**
5. UI 观感与 RikkaHub **一致或更好**（由用户主观判定）
6. 断网/切后台/杀进程三种情况下，重新打开都能恢复到正确状态
7. 支持双向发送图片和文件

---

## 8. 参考链接

- RikkaHub 源码：https://github.com/rikkahub/rikkahub
- Hermes Agent 仓库：https://github.com/NousResearch/hermes-agent 
- Hermes 相关文档：https://hermes-agent.nousresearch.com/docs
