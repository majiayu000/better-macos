# Better

Better 是一个原生 macOS 决策工具。它不维护无限 Todo，而是强制执行三个边界：最多三条 7/14 天滚动押注、每天一个唯一焦点、每次行动都要提前写下预期证据。

[第一次安排焦点](#第一次安排焦点) · [构建与运行](#运行) · [产品规格](docs/product-spec.md) ·
[核心验证](#验证)

首次从 `Better.app` 启动时，应用会默认注册为 macOS 登录项，让菜单栏入口随登录可用。可以在“提醒与启动”中随时关闭；自动启动不会创建焦点或开始计时。

侧边栏的“图标实验室”可以逐个预览并即时替换内置图标。选择只保存在 `UserDefaults`，下次启动恢复，不会修改押注、焦点或 `better.json`。

## 滚动规划

押注只固定周期结果、证据门槛和最危险假设，不预先写死每天的任务。完成当天焦点后，记录实际证据、阻碍、未知问题与精力状态，再到“我不知道做什么”页面让 Codex 生成下一天建议。

Codex 通过本机已登录的 CLI 运行，使用只读沙箱和 JSON Schema 输出。它不能直接修改 Better；建议必须先在界面中预览并由用户确认。默认检查 `/opt/homebrew/bin/codex`，也可通过 `BETTER_CODEX_PATH` 指定其他路径。

## 第一次安排焦点

下面是一组填写示例，用来区分周期结果、今天的行动和实际证据，不代表项目已经达成这些结果。

| 位置 | 示例 |
|---|---|
| 7 天押注 | 验证两位目标用户是否愿意试用当前原型 |
| 证据门槛 | 两次真实试用反馈，记录具体阻碍与是否愿意继续使用 |
| 最危险假设 | 对方的问题足够强，愿意为试用留出时间 |
| 今天唯一焦点 | 联系一位目标用户，约一次原型试用 |
| 预期证据 | 对方是否答应试用，以及拒绝或接受的具体理由 |
| 实际证据 | 对方未回复；目前还不能判断是否存在需求 |
| 阻碍与未知 | 触达方式可能不对，也可能对方没有时间；不能把猜测当成原因 |

先建押注，再选择今天的唯一焦点并写预期证据。行动结束后，填写真实发生的事。
没有回复、遇到阻碍或否定反馈也可以成为下一步判断的输入；完成任务不自动等于押注成立。

随后可以打开“我不知道做什么”或和 Coach 复盘，比较继续联系、调整触达方式或停放押注。
建议需要你预览确认后才成为下一天焦点。周期结束时，用实际证据决定继续、调整、完成或停放。
具体字段与约束见[产品规格](docs/product-spec.md)，不要预先把 7 天排满任务。

## Better Coach

完成一次焦点后，可以选择“保存并和 Coach 复盘”。Better Coach 会接收本次实际证据、仍未知的问题、现实变化和精力状态，并在 Better 专属的 Codex 线程中继续对话。第二天从侧边栏或“今天”页面打开 Coach，会恢复同一线程。

Better 本地保存最多 40 条可见消息。线程恢复失败时，会使用当前押注、最近 14 条证据和有限对话摘要重新建立连接。线程和回复都不能直接改动 Better；“下一步提案”仍需用户确认后才成为唯一焦点。

## 周期复盘

每条押注到达 7/14 天边界时会显示“开始周期复盘”。复盘会统计当期证据，要求写下结论，并选择继续、调整、完成或停放。继续和调整会从复盘日开启新周期；完成和停放需要先结束对应的当前焦点。

周期复盘也会轮换 Better Coach 线程：旧线程 ID 和交接摘要被归档，有限本地消息继续显示；下一次发送消息时，新线程会收到最近复盘和当前结构化上下文。

## Git 上下文

侧边栏“Git 上下文”可以逐个选择 Better Coach 允许读取的本地仓库。Better 只运行本地只读 Git 命令，保存分支、HEAD、暂存/修改/未跟踪/冲突计数、相对本地 upstream 的 ahead/behind，以及最近 5 条提交。

每次发送 Coach 消息或生成提案前，Better 会刷新所有启用仓库。任何仓库刷新失败都会显示具体错误并取消本次 Agent 调用，不会静默使用旧快照。禁用或移除关注不会修改仓库；Better 不执行 fetch、pull、push，也不会自动扫描其他代码目录。

Git 变化只表示实现活动。clean working tree 或新增提交不代表已经发布、被用户使用或产生业务结果。

## 运行

需要 macOS 14 或更高版本，以及 Swift 6。

```bash
git clone https://github.com/majiayu000/better-macos.git
cd better-macos
./scripts/build-app.sh
open dist/Better.app
```

`swift run Better` 可用于快速界面调试，但裸 SwiftPM 可执行文件没有 macOS Bundle 身份，系统通知只在 `Better.app` 中启用。

数据保存在：

```text
~/Library/Application Support/Better/better.json
```

## 验证

```bash
./scripts/check-core.sh
swift build
```

需要真实验证本机 Codex 连接时，可手动运行 `./scripts/check-codex-planner.sh`。它会消耗一次 Codex 调用，只使用脚本内的隔离样例，不读取或修改 Better 数据。

连续会话可运行 `./scripts/check-codex-coach.sh`。它会消耗两次 Codex 调用，使用隔离样例验证新建线程和按 ID 恢复，不读取或修改 Better 数据。

Tagged GitHub Release zips are Developer ID signed and notarized. Local `./scripts/build-app.sh` output is ad-hoc unless Apple signing env vars are set.

完整产品边界见 [`docs/product-spec.md`](docs/product-spec.md)。
