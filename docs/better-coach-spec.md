# Better Coach 连续会话规格

## 1. 目标

在不把 Better 变成通用聊天或 Todo 工具的前提下，补全“完成焦点 → 和 Coach 复盘 → 确认下一步 → 次日继续”的闭环。

用户始终和一个名为 Better Coach 的角色交流。底层使用本机已登录的 Codex CLI。Better 自己保存押注、证据和已确认行动；Codex 线程只用于延续自然语言上下文，不能成为唯一事实来源。

## 2. 用户流程

1. 用户完成当前焦点，填写实际证据、未知问题、现实变化和精力状态。
2. 保存后，Better 保留一条“待复盘证据”，并进入 Better Coach 页面。
3. 用户可直接发送补充信息；第一次发送时，Better 创建专属 Codex 线程并保存线程 ID。
4. 后续消息恢复同一线程，并只补充自上次成功交互后发生的 Better 数据变化。
5. 用户可请求“生成下一步提案”。Codex 返回结构化焦点建议，Better 校验后展示确认卡片。
6. 只有用户确认提案后，Better 才创建唯一焦点。
7. 应用重启后仍可查看本地对话记录并恢复 Codex 线程。
8. 如果线程恢复失败，Better 用当前结构化上下文和本地对话摘要创建新线程，并明确显示已经重建连接。

## 3. 数据所有权

### 3.1 Better 主数据

`BetterData` 继续作为唯一事实来源，新增：

- `coach`：当前 Coach 线程状态和有限本地对话。
- `pendingReviewEvidenceID`：刚完成、尚未交给 Coach 复盘的证据 ID。

新增字段必须兼容旧 JSON。缺失字段按空 Coach 状态解码；当前总数据版本和后续迁移由 [`cycle-review-spec.md`](cycle-review-spec.md) 继续定义，损坏文件不能被覆盖。

### 3.2 Coach 状态

`CoachState` 包含：

- 可选 `threadID`。
- 线程创建和最近使用时间。
- 最近一次成功发送时的上下文指纹。
- 最多 40 条本地可见消息。
- 可选的待确认 `CodexFocusSuggestion`。
- 最近一次线程重建时间，用于 UI 提示。

本地消息只用于恢复界面和构造故障重建摘要；完整 Codex rollout 由 Codex 自己管理。

## 4. Codex 协议

### 4.1 自然语言对话

- 新线程：调用 `codex exec --json`，不使用 `--ephemeral`。
- 从 JSONL `thread.started.thread_id` 读取并保存线程 ID。
- 恢复线程：调用 `codex exec resume <threadID> --json`。
- 两种调用都使用只读沙箱、跳过 Git 仓库检查，并在 Better Application Support 目录运行。
- 从 `item.completed` 中读取最后一条 `agent_message` 作为回复。

### 4.2 上下文包

首次创建或线程重建时发送完整但有限的 `CoachContextPacket`：

- 最多三条活跃押注。
- 最近 14 条证据。
- 当前焦点（若有）。
- 最多 20 条停车场标题。
- 最近 12 条本地对话摘要。
- 最近 8 条周期复盘。

正常恢复时发送 `CoachContextDelta`：最近一次成功交互后新增的证据、当前焦点变化和待复盘证据。不得扫描 GitHub、完整 Codex 聊天档案或其他应用数据。

### 4.3 结构化提案

“生成下一步提案”复用现有 `CodexFocusSuggestion` Schema 和校验规则，但在当前 Coach 线程中请求。若没有线程，先创建线程。提案只保存为待确认状态，不自动写入 `currentFocus`。

### 4.4 失败处理

- 普通执行失败：显示真实错误，不伪造回复。
- 已有线程恢复失败：只自动尝试一次新线程重建。
- 重建失败：返回组合错误，保留原线程 ID 和本地消息，避免丢失诊断线索。
- 进程输出缺少线程 ID、Agent 回复或结构化结果时明确失败。

## 5. 界面

- 侧边栏新增“Better Coach”。
- Coach 页面显示角色说明、线程状态、有限消息历史、输入框和发送按钮。
- 有待复盘证据时，在页面顶部显示本次收尾摘要。
- 无当前焦点且存在活跃押注时，提供“生成下一步提案”。
- 提案卡片支持确认和放弃；确认后跳转“今天”。
- `FinishFocusSheet` 增加“保存并和 Coach 复盘”，保存成功后导航到 Coach。
- “今天”无焦点时显示“继续和 Better Coach 聊”的入口。

## 6. 文件范围

- `Sources/Models.swift`：Coach 数据模型和 v1 → v2 兼容解码。
- `Sources/AppStore.swift`：消息、线程、待复盘和提案的原子持久化接口。
- `Sources/CodexCoachService.swift`：Codex JSONL 会话协议、上下文包和恢复重建。
- `Sources/CodexCoachView.swift`：从单一卡片扩展为 Coach 页面，同时保留现有滚动规划卡片。
- `Sources/TodayView.swift`、`Sources/DashboardView.swift`：收尾与导航接线。
- `Checks/CoreChecks.swift`、`scripts/check-core.sh`：迁移、消息上限、待复盘和上下文检查。
- `docs/product-spec.md`、`README.md`：更新产品边界和使用说明。

## 7. 验收标准

- 现有 v1 `better.json` 能无损读取。
- 完成焦点后产生证据并设置待复盘证据 ID。
- Coach 消息、线程 ID 和提案跨 AppStore 重载保持一致。
- 本地 Coach 消息最多保留 40 条。
- 新 Codex 会话能捕获 `thread_id` 和 Agent 回复。
- 已有线程恢复失败时只重建一次，并发送当前结构化上下文。
- 提案必须通过现有活跃押注、必填字段和时长校验，且用户确认前不创建焦点。
- `./scripts/check-core.sh`、`swift build` 和 App Bundle 构建通过。
