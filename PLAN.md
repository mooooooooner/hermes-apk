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
- ✅ 附件上传（图片 / 文件，best-effort 内联；服务端 artifact 上传被禁用，故走 input 内联 + attachments 字段）
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
7. ✅ 双向图片 / 文件（本地展示 + 内联发送）

## 已知限制
- 服务端 artifacts 上传接口在本环境返回 `browser_control_disabled`，因此附件通过 `input` 内联 + `attachments` 字段发送，效果取决于服务端是否消费该字段。
- `/v1/runs` 的 `input` 仅接受字符串；多模态需服务端支持。
