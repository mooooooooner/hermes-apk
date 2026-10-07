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
- ⬜ 语音输入
- ⬜ 多服务器 / 多 profile
- ⬜ 会话搜索
- ✅ 子代理状态面板（`subagent.start` / `subagent.complete` 渲染在工具区）
- ✅ 用量统计（usage tokens，助手消息底部展示）

## 验收对照
1. ✅ 填 URL+Key → 列模型（测试连接）
2. ✅ 逐字流式（SSE `message.delta`）
3. ✅ 长任务关 App → 重开见完整结果（Room + reconcile）
4. ✅ 完成系统通知
5. 🟡 UI 观感（RikkaHub 风格：Material 3、大圆角、会话卡片、抽屉式信息层级）
6. ✅ 断网 / 切后台 / 杀进程恢复
7. ✅ 双向文件 / 图片：用户上传 → 自建文件服务（`incoming/`），助手可直接读服务端路径；助手 → 用户，`MEDIA:url` 渲染为可下载文件卡片，Markdown 图片由带 Bearer 的 Coil 拉取内联渲染。实测端到端通过
8. ✅ 助手名称 / 头像自定义（本地存储）：设置页可改名称、选头像，聊天头部、输入框占位、空态提示同步更新
9. ✅ `/` 斜杠命令：命令列表从服务端 `GET {filesBase}/commands` 读取，失败回退内置；输入 `/` 弹出补全，选中插入模板

## 已知限制
- 服务端 artifacts 上传 / 下载接口在本环境返回 `browser_control_disabled`，且没有通用文件下载路由；双向文件改由自建 `hermes-files` 服务承担（`/upload` 上传、`/files/{id}` 下载、`/commands` 命令表）。助手若只给本地 `MEDIA:/绝对路径` 仍无法直接下载，需走文件服务或给出可访问 URL。
- 真实的「思考过程」来自 `reasoning.delta`（流式）与服务端 transcript（同步）；该部署的 `reasoning.available` 只是本轮可见文本的回声，已完全忽略，避免与正文重复。

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
