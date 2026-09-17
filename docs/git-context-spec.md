# Better Git 上下文规格

## 1. 目标

让 Better Coach 在用户明确选择的本地 Git 仓库中，知道当前实现状态，而不扫描整台电脑、不访问远端、不修改仓库，也不把提交数量误当成用户价值。

Git 上下文用于回答“当前代码实际上走到哪里、是否有未完成改动、最近实现了什么”。押注、真实证据和周期复盘仍然是决策的唯一事实来源。

## 2. 授权边界

- 用户必须通过目录选择器逐个添加仓库。
- Better 不自动发现 `~/Desktop/code`、最近使用仓库或其他 Git 目录。
- 最多关注 8 个仓库，避免上下文无限扩大。
- 所有 Git 命令固定使用参数数组调用 `/usr/bin/git`，不经过 shell。
- 只执行本地只读命令：`rev-parse`、`symbolic-ref`、`status`、`rev-list` 和 `log`。
- 不执行 `fetch`、`pull`、`push`、`checkout`、`reset`、`clean`、`add`、`commit` 或任何 hook。
- ahead/behind 只相对本地保存的 upstream ref，界面和 Prompt 必须说明它可能没有包含远端最新变化。

## 3. 数据模型

`BetterData` 升级到 v4，新增最多 8 条 `GitRepositoryWatch`：

- 仓库 ID、规范化根路径、显示名称、添加时间、是否启用。
- 最近刷新尝试时间。
- 最近一次成功的 `GitRepositorySnapshot`。
- 最近错误；刷新失败时保留旧快照，但不能把旧快照静默交给 Coach。

`GitRepositorySnapshot` 包含：

- 采集时间、规范化仓库根路径。
- 当前分支或 detached HEAD 标识。
- HEAD 完整 SHA。
- 可选 upstream 名称、本地 ahead/behind 数量。
- staged、modified、untracked、conflict 数量。
- 最近 5 条本地提交的 SHA、短 SHA、时间和标题。

旧 v1-v3 JSON 缺少 `gitRepositories` 时解码为空数组，损坏文件继续明确报错且不覆盖。

## 4. 刷新行为

- 打开“Git 上下文”页面时刷新所有启用仓库。
- 用户可以手动刷新单个仓库或全部仓库。
- 每次发送 Coach 消息或生成下一步提案前，必须刷新所有启用仓库。
- 任何启用仓库刷新失败时，本次 Coach 调用不执行，并显示具体仓库和错误。
- 禁用仓库不会刷新，也不会进入 Coach 上下文。
- 删除关注只删除 Better 中的路径和快照，不修改磁盘仓库。

## 5. Git 解析

- `rev-parse --show-toplevel` 验证并规范化仓库根目录。
- `symbolic-ref --quiet --short HEAD` 读取分支；失败时用短 HEAD 标记 detached 状态。
- `status --porcelain=v1 -z --untracked-files=normal` 按 NUL 记录解析路径，支持空格、换行和 rename/copy 的双路径记录。
- 合并冲突状态单独计数，不重复算作 staged/modified。
- 存在 upstream 时用 `rev-list --left-right --count HEAD...@{upstream}` 计算本地 ahead/behind。
- `log -5` 只读取本地最近提交。

## 6. Coach 上下文

完整和增量 Context Packet 都包含所有启用仓库的最新成功快照；调用前的强制刷新保证这些快照来自当前回合。

Prompt 必须明确：

- Git 变化是实现活动或可交付物线索，不等于用户尝试、主动返回、承诺或付费。
- clean working tree 不等于已经发布、部署或被用户使用。
- 本地 upstream ahead/behind 可能因未 fetch 而过期。
- 不基于 commit 数量奖励忙碌，不从分支名或提交标题虚构业务结果。

Git 快照进入上下文指纹，HEAD、工作区计数或刷新时间变化会改变指纹。

## 7. 界面

- 侧边栏新增“Git 上下文”。
- 空状态解释授权边界，并提供“选择本地仓库”。
- 仓库卡片显示路径、分支、短 HEAD、工作区计数、upstream、本地 ahead/behind、最近提交和刷新时间。
- 卡片支持启用/禁用、刷新和移除关注。
- 错误必须在对应卡片和页面级状态中明确显示。
- Coach 页面显示启用 Git 仓库数量和刷新状态。

## 8. 验收标准

- 非 Git 目录无法添加，并显示明确错误。
- 同一路径不能重复添加，第 9 个仓库被拒绝。
- 路径通过参数数组传给 Git，包含空格时仍能工作。
- 临时 Git fixture 可正确读取分支、HEAD、modified、staged、untracked 和最近提交。
- 无 upstream 是合法状态，不显示成错误。
- 刷新失败会持久化错误并阻止 Coach 调用。
- 禁用或移除仓库后不进入 Coach Prompt。
- v1-v3 数据可迁移为 v4。
- 核心检查、Debug/Release 构建和 App Bundle 打包通过。

