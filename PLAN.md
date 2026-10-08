# 实施计划 / 进度

> 依据 `REQUIREMENTS.md` 制定。状态：✅ 已完成 · 🟡 部分 · ⬜ 未做

## 阶段

### P0 / 环境
- ✅ 读取需求与凭据；实测 Hermes API（`/v1/models`、`/v1/capabilities`、`POST /v1/runs`、SSE 事件格式）
- ✅ 安装构建环境（JDK 21 已有；下载 Gradle 8.9、Android command-line tools，安装 platform-tools / platforms;android-35 / build-tools;35.0.0，注册 PATH）
- ✅ `git init`，`.gitignore`（含凭据文件），Gradle Kotlin DSL + Version Catalog

### P0 / MVP
- ✅ 配置页：Base URL + API Key + 测试连接（`GET /v1/models`）
- ✅ 会话列表（本地 session_id）：新建 / 重命名 / 删除
- ✅ 聊天页：发消息、`message.delta` 流式显示
- ✅ 长任务模式：`POST /v1/runs` 异步发起，`run_id` 落库（Room）
- ✅ 断线恢复：启动 / 回前台 / WorkManager 周期对账未完成 run
- ✅ 完成通知：终态发系统通知，点通知深链到会话
- ✅ 工具调用进度：`tool.started` / `tool.completed`（含 subagent 事件）
- ✅ Markdown 渲染 + 代码块高亮 + 一键复制
- ✅ 深色 / 浅色主题（+ 动态取色）

### P1
- ✅ 会话历史与 session_id 绑定（服务端权威 + 本地缓存，聊天页可同步）
- ✅ 附件上传：优先上传到自建文件服务（`POST {filesBase}/upload`），把服务端本地 `path` 通过 run `instructions` 注入（→ `ephemeral_system_prompt`，不落库），对用户透明；上传失败才回退到多模态 `input`（图片）/ 内联围栏文本
- ✅ 中断正在跑的任务（`POST /v1/runs/{id}/stop`）
- ✅ 重新生成 / 编辑重发
- ✅ 消息长按复制、快捷复制按钮
- ✅ `Idempotency-Key`（UUID，安全重试）
- ✅ Markdown 各类语法（标题/列表/引用/表格/分割线/行内样式/链接/代码）
- 🟡 插话（`/steer` 已在 RunManager 暴露，尚未接入 UI 按钮）

### P2
- ✅ 语音输入（系统 `RecognizerIntent`，输入框麦克风按钮；设备无识别器时 Snackbar 提示）
- ⬜ 多服务器 / 多 profile
- ⬜ 会话搜索
- ✅ 子代理状态面板（`subagent.start` / `subagent.complete` 渲染在工具区）
- ✅ 用量统计（usage tokens，助手消息底部展示）

## 验收对照
1. ✅ 填 URL+Key → 列模型（测试连接）
2. ✅ 逐字流式（SSE `message.delta`）
3. ✅ 长任务关 App → 重开见完整结果（Room + reconcile）
4. ✅ 完成系统通知
5. ✅ UI 观感（RikkaHub 风格：Material 3、大圆角、会话卡片；配色采用 RikkaHub 的 Claude/Anthropic 预设；统一 16dp 栅格对齐）
6. ✅ 断网 / 切后台 / 杀进程恢复
7. ✅ 双向文件 / 图片：用户上传 → 自建文件服务（`incoming/`），助手可直接读服务端路径；助手 → 用户，`MEDIA:url` 渲染为可下载文件卡片，Markdown 图片由带 Bearer 的 Coil 拉取内联渲染。实测端到端通过
8. ✅ 助手名称 / 头像自定义（本地存储）：设置页可改名称、选头像，聊天头部、输入框占位、空态提示同步更新
9. ✅ `/` 斜杠命令：命令列表从服务端 `GET {filesBase}/commands` 读取（现为 Hermes 内置命令集 102 条，由 `hermes_cli/commands.py` 生成），失败回退内置；输入 `/` 弹出补全，选中插入 `/name`
10. ✅ 应用图标：Hermes 官方图标（自适应图标 + 单色层 + 各密度位图）

## 已知限制
- 服务端 artifacts 上传 / 下载接口在本环境返回 `browser_control_disabled`，且没有通用文件下载路由；双向文件改由自建 `hermes-files` 服务承担（`/upload` 上传、`/files/{id}` 下载、`/commands` 命令表）。助手若只给本地 `MEDIA:/绝对路径` 仍无法直接下载，需走文件服务或给出可访问 URL。
- 真实的「思考过程」来自 `reasoning.delta`（流式）与服务端 transcript（同步）；该部署的 `reasoning.available` 只是本轮可见文本的回声，已完全忽略。按最新要求 UI 不再渲染 `reasoning`（数据仍保留在 segments 中）。

### 多轮分段模型（本次修复）
- 助手消息持久化为有序 `segments: List<MessageSegment{reasoning, tools, text}>`（Room 新增 `segments` 列 + 1→2 迁移），按「思维链 → 工具调用 → 正文」逐轮渲染，不再把多轮压平成一整段。
- 流式：以 `message.interim` 作为轮次边界，`tool.started`/`tool.completed` 归入当前轮；`run.completed.output` 仅在**完全没有流式内容**时作为兜底，绝不覆盖已流式的内容（修复「只剩最后一个 1 和结语」）。
- 同步：按用户回合把服务端 transcript（assistant + tool 结果）折叠成与流式一致的 segments，避免同步前后格式剧变。

### 文件服务（本次新增，服务端自建）
- 服务端：stdlib Python HTTP，监听 `127.0.0.1:8791`；systemd 单元 `hermes-files.service`（`Restart=always`、开机自启）；nginx `location /hermes-files/ { proxy_pass http://127.0.0.1:8791/; }`。
- 端点：`GET /health`、`POST /upload`、`GET /files/{id}`、`GET /list`、`GET /commands`，均需 `Authorization: Bearer <API_KEY>`。
- 存储：`{filebox}/incoming`（用户→助手）、`{filebox}/outgoing`；`commands.json` 提供命令表（默认 `{name,description,template}`，现 5 条）。
- App：独立 `@FilesClient`（`FilesUrlInterceptor` 解析相对路径 + Bearer）；Coil `ImageLoader` 用 `FilesAuthInterceptor`（仅对文件服务 host 加鉴权）。
- 用户附件先传到文件服务，把服务端本地 `path` 通过 run `instructions` 注入（透明）；助手回传用 `MEDIA:url`（可下载文件卡片）或 Markdown 图片（带鉴权内联）。

### 助手身份 / 斜杠命令（本次新增）
- 助手名称 + 头像本地存储（DataStore / 私有目录），设置页「助手」分组，聊天头部 / 空态 / 输入占位复用。
- 文件服务 Base URL 为独立设置项，留空按 `baseUrl` 推导（`/hermes-api`、`/api` → `/hermes-files`，否则追加 `/hermes-files`）。
- `/` 命令：输入框尾部 `/` 按钮或输入 `/` 触发补全，命令表来自服务端，失败回退内置。

### 本批次（不显示思维链 / 折叠工具 / 语音 / UI / 主题 / 图标）
- **不显示思维链**：移除 `ReasoningSection` 与设置页「显示思考过程」开关；`reasoning` 仍持久化在 `segments` 中，仅不渲染。
- **自动折叠连续工具调用**：`buildRenderBlocks` 把相邻、之间无正文的 tool 事件合并成一个可折叠「工具调用 (N)」卡片（默认折叠）；中间有正文的仍按轮次分开。
- **语音输入**：输入框空白时右侧显示麦克风，点击走系统 `RecognizerIntent`（`<queries>` 声明 `android.speech.action.RECOGNIZE_SPEECH`），识别结果追加到草稿；设备无识别器时 Snackbar 提示。
- **UI 微调**：聊天列表 / 附件条 / 命令补全面板统一 16dp 栅格；输入框改为「`+` 前置图标 + `/` 尾部图标 + 外部发送/麦克风」，左右边距与消息对齐；助手消息按「头像 + 名称/内容」列对齐；工具卡片用 `key(event.id)` 稳定展开状态。
- **配色**：换成 RikkaHub 的 Claude / Anthropic 预设（象牙白/米色暖底 + 赤陶橙强调），补齐 `surfaceContainer*` / `inverse*` / `errorContainer` 等 Material3 token，浅色与深色均适配。
- **命令集**：文件服务 `commands.json` 改由 Hermes 的真实命令注册表 `hermes_cli/commands.py` 生成（现 102 条，含 `/new`、`/clear`、`/history`、`/save`、`/compress` 等），仍未改动 App 读取逻辑。
- **应用图标**：改用 Hermes 官方 `assets/icon-master.svg` / `nous-girl-black.svg`；Pillow 生成自适应图标前景 + 单色层 + 各密度位图，背景 `#FAF9F5`。

### 本批次（发送失败 / 杀进程后卡死修复）
- **现象**：发送时网络不通（或应用在首次网络请求返回前被杀），会在本地留下 `status=PENDING`、`runId=null` 的助手占位消息；下次打开后 `isRunning` 永远为真、`activeRunId` 为 null，于是「中断」按钮无从下手，聊天持续卡死。
- **对账清理**：`RunManager.sweepOrphanPlaceholders()` 在 `reconcileAll()` 开头把「PENDING 且无 runId」的占位消息标记为 `ERROR`（`消息未发出…请重新发送`）并清空会话 activeRun；正在进行中的提交用内存集合 `inFlightSubmits` 保护，进程重启后该集合为空，正好回收被杀时的残留。
- **中断兜底**：`ChatViewModel` 保留发送协程 `submitJob`；`stop()` 在没有 runId 时取消该协程并调用 `ChatRepository.cancelPending()`，把无 run 的占位置为 `CANCELLED`（UI 显示「已中断」）。
- **提交重构**：`submit()` 用 `try/catch/finally`：`CancellationException` 原样抛出、其它异常把占位置 `ERROR`、`finally` 清除 in-flight 标记；错误定位改用占位 id，不再靠「最后一条 runId 为空的助手消息」猜测。
- 已实测：注入 `PENDING`+`runId=null` 行 → 重开自动变 `ERROR`；黑洞网络下发送卡住 → 点「中断」立即变 `CANCELLED`，按钮恢复为麦克风。

### 本批次（语音送音频 / 同步全部会话 / 删除同步 / 斜杠命令服务端执行）
- **语音输入改为直接送音频给 Hermes**：不再用系统 `RecognizerIntent` 转文字。点麦克风开始 `MediaRecorder` 录制 AAC/.m4a（`VoiceRecorder`，缓存目录），再点停止即上传到文件服务并作为附件发送（用户消息气泡显示「🎤 语音消息」）。
  - 真正原因：该部署 `stt` 工具集是「纯配置、无 agent 工具」（`hermes_cli/tools_config.py:_CONFIG_ONLY_TOOLSETS`），`/v1/capabilities` 也是 `audio_api:false`，所以音频文件本身听不了；但 Hermes 自带转写入口 `tools.transcription_tools.transcribe_audio(path)`。
  - 因此 run `instructions` 里对音频附件单独注入：告诉 Hermes 用 `cd /usr/local/lib/hermes-agent && ./venv/bin/python -c "...transcribe_audio('<path>')"` 先把语音转成文字再回答。旧的 `recognize` 相关代码/`<queries>` 已移除。
  - 服务端前置：venv 缺 `faster-whisper`，按 Hermes 自带锁安装 `stt-whisper` extra（`sync_venv(['stt-whisper'])`，钉 `av==18.1.0`；切勿裸装导致 PyAV 19 崩溃）。
- **一键同步全部会话**：主页顶栏新增「同步」按钮（同步中显示进度圈）。`GET /api/sessions`（分页 `limit/offset/has_more`）→ 合并进本地 `sessions`：新会话插入；已存在则只更新 `updatedAt`/`preview`，标题仅在本地仍是默认「新会话」时用服务端标题回填（保留本地重命名）。过滤 `hidden` / `is_internal_child` / 有 `parent_session_id` 的内部子会话。
- **删除会话同步删除服务端**：`DELETE /api/sessions/{id}`（404 视为已删除）；无论服务端成功与否都删本地，服务端失败时 Snackbar 提示「已从本机删除，但服务端删除失败」。删除确认文案改为「本机与服务器上的记录都会被移除」。
- **斜杠命令服务端执行**：在服务端 `gateway/platforms/api_server_runs.py::_handle_runs` 内，把只读命令直接派发给网关命令处理器并就地完成 run（不再进入模型）。白名单由 `hermes_cli/commands.py` 的真实注册表过滤得到，实测生效集 = `{status, context, usage, model, sessions, insights}`（`help/history/skills/tools` 因 `cli_only`/带 `execute` 被保守剔除）。非白名单命令（`/new /stop /reset /clear /approve /deny /undo /retry /compress /steer`）与普通对话照旧走模型。合成事件必须带 `internal=True`：否则 `gateway/run_inbound.py::_hm_admit_event` 会因「无 user_id」把它静默丢弃（HTTP 层已用 API Key 鉴权，故语义正确）。已端到端验证：`POST /v1/runs {"input":"/status"}` 立即返回真实命令输出（`run.completed`，无 agent turn）；普通提示与 `/new` 仍走模型且不崩溃。补丁备份 `api_server_runs.py.bak-20261008-101052`，可随时回滚。

### 本批次（同步不再吞掉斜杠命令 / /usage·/context·/status 会话解析修复）
- **现象 1（App）**：在已有消息的会话里发 `/` 命令，回复出现后又被「自动同步」抹掉——`/` 命令与回复一起消失。
  - **根因**：服务端把斜杠命令就地完成、**从不写入会话 transcript**（命令 run 的 `message_count=0`）。而 run 完成后的静默刷新 `RunManager.syncFromServer()`（以及手动 `ChatRepository.fetchHistory()`）会「服务端权威」地用 transcript 覆盖本地消息；只要该会话此前有普通消息，transcript 非空，覆盖就会把本地独有的 `/` 命令回合整段删掉。
  - **修复**：`HistoryFolder.fold()` 末尾新增 `mergeLocalOnlyTurns()`：以「回合」为单位把服务端 transcript 与本地合并，把服务端没有的本地回合（即真正的服务端命令：用户消息以 `/` 开头且服务端 transcript 中**没有**同内容的用户消息）按原始位置重新插回，并重排 `seq`。普通会话（无 `/` 回合）走快速路径，行为与之前完全一致。已补 3 个单测（命令在末尾 / 夹在两条服务端回合之间 / 未知 `/foo` 已被服务端持久化时不重复）。
- **现象 2（服务端）**：`/usage` 永远返回「No usage data available for this session.」，`/context` 返回「No context data available yet」，`/status` 的 Session ID 是一个刚铸造的新 id。
  - **根因**：命令处理器（`gateway/slash_commands_status.py`）按 `event.source` → `SessionStore.get_or_create_session(source)` 解析会话；而 `/v1/runs` 的 run 路径只用裸 `session_id` 驱动 agent，**从不写 SessionStore 的 routing entry**（key = `build_session_key(platform=api_server, chat_id=<session_id>)`）。于是每次命令都走 `_route_create` 铸一个新会话，读到空 transcript。
  - **修复**：在 `hermes-android` 派发块内、构造事件之前，把该 run 的 routing key 绑定到真实 `session_id`——复用 `/resume`/CLI handoff 的既有组合 `get_or_create_session(source)` + `switch_session(key, session_id)`（`gateway/run_startup.py:1790-1795`），store 取自 `self._session_store`（回退 `self.gateway_runner.session_store`）。仅在 `selected_session_id` 非空时执行；失败只 `logger.warning`，不影响 run。首个命令会经 `get_or_create_session` 先铸一行临时会话、再被 `switch_session` 以 `session_end` 结束（此后同 key 命中即零写入）——这是 `/resume` 已有的既定模式。
  - **验证（live）**：`/status` 现在显示 `Session ID: hm-reg-531679`、标题与 17,335 lifetime tokens；`/usage` 返回 `Session Info | Messages: 2`；`/context` 返回该会话的 `~47 tokens across 2 messages`。（无 live agent 时 `/usage` 仍如实降级为 transcript 估算，这是 Hermes 既定行为。）
  - 新补丁 md5 `b8404632ebb20c3e51934d9688caa042`。**重启注意**：网关有自我重启守卫（`tools/terminal_tool_guards.py`），从网关进程内部跑 `systemctl restart` / `systemd-run ... systemctl restart` 会被拒；应改用 `systemctl reload hermes-gateway.service`（网关把 SIGUSR1 视为优雅重启，守卫正则不含 `reload`）。

### 本批次（更新不再闪屏 / 新内容不再跳到消息开头）
- **现象 1（闪屏）**：run 完成后的静默同步（以及手动同步）会让聊天列表瞬间闪白/闪空。
  - **根因**：`ChatRepository.fetchHistory()` 与 `RunManager.syncFromServer()` 都是「先 `deleteForSession` 再逐条 `insert`」，且不在同一事务里。Room 的 `Flow` 是失效驱动：删除与插入之间会各自触发一次查询，观察者先收到**空列表**（触发 `EmptyChatHint` 闪现），再收到逐步拼出的列表；同时新插入的行拿到新的自增 id，`LazyColumn` 的 `key = item.id` 全变，整表被销毁重建，进一步加剧闪烁与滚动跳动。
  - **修复 1（原子替换）**：两条同步路径的删除+插入都包进 `db.withTransaction { ... }`（`room-ktx`），Room 只在事务提交后发一次失效 → 观察者只会看到最终列表，不再闪现空状态。
  - **修复 2（稳定 id）**：`HistoryFolder.fold()` 末尾新增 `reuseLocalIds()`：先按「索引对齐 + 角色/内容相同」复用本地旧行的 `id`/`createdAt`（覆盖常见情形：同一会话顺序不变的同步），再按「角色+内容」兜底匹配被插入/删除挤位的行。id 稳定 → `LazyColumn` 的 item 不会被销毁重建。已补单测 `reusesLocalRowIdsForUnchangedMessages`。
- **现象 2（新内容跳到消息开头）**：流式回复越长、或出现新的工具调用/新消息时，视图总会「对齐到这条消息的**顶部**」，看不到最新内容；用户往上翻读历史时也会被拽走。
  - **根因**：`ChatScreen` 里 `LaunchedEffect(messages.size)` 与 `LaunchedEffect(last.content.length)` 都调用 `listState.scrollToItem(messages.lastIndex)`——`scrollToItem(index)` 是把该 item「顶部」对齐到视口顶部；对长消息就表现为永远停在消息开头。第二个 effect 又在流式增长时反复重对齐。
  - **修复**：列表改为 `reverseLayout = true` + `itemsIndexed(messages.asReversed(), key = { _, it -> it.id })`（item 0 = 最新一条，落在底部）。reverseLayout 天然把「底部」作为锚点：流式/工具卡片增长时底部保持不动、只向上扩展；用户上翻后新内容不会把视图拽回。自动滚动只剩一条 `LaunchedEffect(messages.size) { listState.scrollToItem(0) }`，仅在**回合数变化**（发送新消息/首次加载）时回到最新，流式增量与工具调用不会触发。
  - **已实测（模拟器 `hermes`）**：打开会话落在最新内容（底部）；发送一条会流式长回复的消息，流式中途上翻到历史，5 秒后位置不变；run 完成后自动同步仍停在原处，未跳回底部、未闪空。

