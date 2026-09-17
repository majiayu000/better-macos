# 三个月自我复盘：Felix（2026-04 ~ 2026-07）

（合并自三份分析：系统化机会 / 深度缺口 / 画像与成长。重复内容已去重，冲突处的裁决在文中标注。）

## 一、你这三个月在做什么

先拆一个容易自欺的前提：session 量和你的注意力是两回事。全部 session 中约 70-90% 是机器自动触发的——Looper x-reply 两天近 700 次、runner 农场单日最高 373 个 session。按算力口径，内容运营自动化约占 45%、研究 runner 农场约 30%、个人工具流水线约 15%、AtlasCloud 工作仅约 10%。但按你本人的注意力（手打消息密度和纠偏深度）估算：个人工具开发约 35-40%，工作约 25-30%，一次即止的新想法立项约 20%，剩下 10-15% 花在对自动化系统的催问上（"今天发了几个reply？""提交了吗"）。

直白地说：你注意力的最大头投在"给自己造工具的工具"上，而这些工具服务的对象主要是你自己的其他工具，自指循环占比过高。三个月里有 60+ 个话题一次即止（Obsidian 插件立项 3 次全停在 spec），启动成本被 AI 压到零之后，放弃成本也是零，于是什么都启动、什么都不结束。同时要承认强项：你的多 agent 编排纪律（只读 lane、文件所有权、file:line 证据）是个人用户里的顶尖水平，threads+specrail 流水线在 15+ 个仓库验证过；工作侧的 VSR/Topaz 逆向和计费排障是有闭环的实活。问题不是能力，是结构。

## 二、重复劳动 → 系统化清单

一个总体判断先行：你的系统化能力本身很强，缺口集中在两类——(a) 已有 skill 的"最后一公里"（默认参数、定时触发、失败回退），(b) 所有自动化都缺"自我汇报"层，产出量、健康度、完成度从不主动上报，全靠你连环追问。第二类值得优先投资，它一次性消灭的是横跨所有项目的同一种劳动。

**优先级 P0（完全没有系统化，风险最大）**

1. **自动化产出健康度监控**。证据：looper 状态追问"04-07/04-08 至少 7 个 session 原样重复"；theme runner 目录持续 0 文件仍空转轮询；remem flush 烧光 Claude 额度、DeepSearch 被扣 100 刀，全部事后才发现。做法：统一采集各 runner 的「今日产出数、失败数、空转轮次、成本」，异常主动推送。这把"扣 100 刀"类事故从事后排查变成分钟级告警。
2. **git 状态自动汇报**。「提交了吗」「push了吗」几乎是每个编码 session 的固定结尾。一个 Stop hook 输出「未提交 N / 未 push N / PR 状态」，改动成本最小、见效最快。
3. **客户反馈 → issue 队列转换器**。mutil-om 6 月中下旬每隔一两天一批 5-10 条客户 comment，靠人肉截图追问「还有多少这样的？？？」核对。做成 feedback-to-issues：反馈原文 → 结构化条目 → 批量开 issue → 逐条完成度对照表。

**优先级 P1（已有 skill 但差最后一公里）**

4. **多仓库巡检定时化**。「你帮我看下这个库还有什么issue和pr」在 remem 一个库连续逐字重复 3+ 次，6 天 8 仓库各跑一轮。threads/specrail 已覆盖单仓库单轮，缺的是定时舰队巡检 + 统一 triage 报告，人只做批准。估算每天省 30-60 分钟。
5. **prod-judge 默认多窗口**。「你看看7天14天的 别只看7天的啊」从 4 月末重复到 7 月。改 skill 默认输出 7d/14d/4w + 环比，一次修改永久消除。
6. **VSR 接入子流程 checklist**。wan-2.7、kling-std、kling-pro、vidu_q3 逐模型重复，且出过"720p-SR route priority 被 catch-all 压过"的生产事故。给 aiproxy-workflow-deploy 补 vsr-attach 子流程，把 route priority、失败不扣钱、model_history NULL 写成强制验证步骤。
7. **system-doctor 病因库 + 定时哨兵**。Mac 资源排查每周 1-2 次，根因高度集中在你自己的工具链（vibeguard hook 吃 120% CPU 至少 2 次、post-edit-guard 卡死 3.5 小时、Codex zombie）。加"已知惯犯优先检查"清单，并给 vibeguard hook 加超时自杀——根治而非监控。
8. **skill 执行校验 hook**。「所以你倒是用这个skill啊！」式纠偏贯穿三个月、每周数次。检测用户消息中的 skill 点名，会话结束前核对调用记录，未命中强制报告原因。
9. **repo-brief skill**。「看下这个库这是啥」是主导开场模式（最后一批记录 10 个 session 中 4-5 个）。固定输出定位/活跃度/与已有工具重叠——最后一项能防止你再干"design 目录重新立项一个和 loom 高度重叠的 skill 管理工具"这种事。

**裁决一处冲突**：材料一建议把 multi-post 挂进 Looper 定时、扩大内容流水线；材料三建议关停内容运营自动化。裁决：**先复盘再建设**。x-reply 跑了三个月数千次，可见反馈只有质量抱怨，涨粉目标 4 月后再无量化复盘——在拿出一份 ROI 数据之前，不再给内容线投任何建设时间，multi-post 定时化暂缓。这是"自动化沉没成本"：因为流水线建好了所以继续跑，而不是因为它有效。

## 三、深度缺口：值得深入 vs 应该放弃

你的"浅"是结构问题：调研外包给 runner 农场（生产无限、消费为零），实现外包给 threads 流水线（能跑但不长本事），于是所有领域停在"报告层"或"能用层"。只保留以下几条深入线：

**1. 推理系统与服务化性能（唯一值得投学习时间的）**。现状：04-15 贴研究清单纯咨询、karpathy autoresearch 无后续；而工作中你天天在"果"上打转——wan-2.6 延迟长尾、超分超时靠"把时长上限削到 45s"绕过。掌握 serving 内部机制（vLLM/SGLang 源码、continuous batching、KV cache、diffusion 推理加速）是从"模型运维"到"平台性能负责人"的分界线，且你已有 Topaz 逆向 + 九模型 benchmark 这条做深了的线。8-12 周，每周 4-6 小时。

**2. Eval 工程化，一条线做穿**。两天 220 个 eval 研究 session，但"reply 太像 AI"从 4 月复发到 7 月至少 4 次。停止开任何 eval 研究 runner，只做 x-reply 一条闭环：50 条人工标注黄金集 → grader 与人工判断一致率校准（所有报告里缺的正是这步）→ 周度看板，然后整套搬到 aiproxy prompt enhancement A/B。6-8 周。

**3. 计费对账机制**。三个月至少 5 次独立计费事故（720p-sr 价差、空返回被扣费、model_history NULL……），每次单点排障。写一个每日对账 job：model_billing × model_history × provider 回执三方比对，把 5 次事故各变成一条永久 invariant。4-6 周，做完收手。这是最显性的工作亮点。

**4. 止血型三项**：runner 消化端（见第四部分裁决）；前端 DevTools 最低限度取证能力（mutil-om"改过很多次都没生效"式 5 轮循环压到 1-2 轮，UI bug 一律先取证再改，2-3 周刻意练习）；secrets 收口（记录明确写"会直接在消息里贴 API key"——你自己维护 SEC-02 却对自己不执行，1-2 周迁 1Password CLI）。

**应该放弃的**（证据均为立项后零消化或零实现）：内容营销 runner 矩阵、电商选品 runner 集群、Obsidian 插件（三次立项已证明意愿不足）、抖音、rui/rnk 对标 WarpUI 的野心、VPS 测评站、一次性爬虫、GPT-5.5 反代等新代理方案（cliproxy-newapi-stack 冻结为存量维护）、Codex Computer Use 逆向重做、沉浸式翻译复刻、be 仓库 4 个 PRD 里的 3 个、零散上游 PR（要做就选 vLLM 类与推理主线相关的，按季度认领 1 个）、数字人（跟工作节奏即可）。

## 四、提升路径：未来 6-12 个月的押注

**押注一：AtlasCloud 工作线的"模型生产运维 + eval + 计费"体系（第一优先）**。这是唯一有真实付费用户、真实生产数据、真实反馈闭环的场景，你在这条线上的交互质量也明显最高。把 prod-judge、model-onboarding、VSR checklist、计费对账、prompt enhancement eval 从"个人 skill 集合"升级成团队可用的体系——这是职业价值最确定的路径，也是唯一能把 4 月 eval 研究农场的沉没成本变现的地方。推理系统的学习（深度缺口 #1）挂在这条线下，作为其纵深。

**押注二：threads + specrail 收敛成一个 agent 交付流水线产品**。这是你唯一有真实差异化积累的东西——三个月 15+ 仓库验证过的完整流程，而它现在散落在 4-5 个仓库当自用脚本。6-30 你让 AI 生成的 4 个产品想法本质全是这条线的变体，你潜意识知道答案。硬条件：先杀掉其余约 10 个个人库的维护循环，否则它就是第 16 个并行仓库。

**押注三（反向）：关停研究 runner 农场、降级内容运营**。裁决材料一"做消化管道"与材料三"直接关停"的分歧：**先砍再管**——先把与押注一/二无关的 runner 全部归档（并行上限 5 个，你曾同时开 21 个），对存量再加三个机制：产出健康度指标（theme runner 那种空转第 2 轮就该被叫停）、报告 7 天无人读自动停、每周固定 30 分钟人工消化（top 3 报告每份必须转成 issue/决策或删除）。不要再用"再开一个 meta runner"代替消化——autoresearch-meta-strategy 本身又是一个 runner，这个讽刺该到此为止。x-reply 降到每天一次人工批处理，四周后看 ROI 数据决定去留。省下的不是算力，是你最稀缺的碎片化注意力。

一句话：你的编排成熟度是 90 分，"选一件事做完并让别人用起来"的纪律是 40 分。未来一年的杠杆不在任何新工具，在砍掉 80% 的并行线。

## 五、本周就能开始的 3 个行动

1. **周一花 2 小时做 runner 大清洗**：列出全部在跑的 runner 和 Looper 任务，与押注一/二无关的直接归档，设并行上限 5 个；顺手把 x-reply 降为每天一次人工批处理。这是零开发成本、当天回收注意力的动作。
2. **写 git 状态 Stop hook + 产出健康度日报（合计半天）**：会话结束自动报「未提交/未 push/PR 状态」，每天早上推一条各流水线「产出数/失败数/成本」摘要。消灭「提交了吗」和「今天发了几个」两类你最高频的手工轮询。
3. **启动计费对账 job 第一版**：先只做 model_billing × model_history 两方比对 + 一条 NULL 检查，接上告警。这周能跑通最小版本，它同时是押注一的第一块砖和下次生产事故的提前量。

---

# 附录 A：系统化机会（完整材料）

# 视角一：可系统化的重复劳动分析

分析基础：37 份 agent 结构化发现（2026-04 ~ 2026-07 约 3 个月聊天记录）。以下按价值排序，每项标注证据、现有 skill 覆盖状态、建议形式与预期节省。

---

## Top 10 值得系统化的重复劳动

### 1. 多仓库 issue/PR 巡检闭环 → 定时舰队巡检系统（最高价值）

- **模式**：「你看下这个库 有什么 issue 和 pr → review → 一个个修复 → 测试 → merge → 开 followup」，同一句式对 remem、loom、litellm-rs、vibeguard、caff、rnk、page-lingo、spellbook、keepline、stash 等 15+ 个仓库轮询。
- **频率证据**：几乎每天多次，贯穿 4-7 月。「你帮我看下这个库 还有什么issue 和pr呢？」在 remem 一个库就"连续出现 3+ 次几乎逐字重复"；6 月记录显示"6 天内至少 8 个仓库各跑一轮"；配套追问「提交了吗」「merge 了吗」「没有额外的 comment 吗？」几乎每个 session 结尾都有。
- **覆盖状态**：**已有 skill 但没覆盖到**。threads / specrail / implx 已覆盖"单仓库单轮处理"，但**触发仍是人肉逐库手打**，且状态追问全靠人。
- **建议形式**：定时任务（cron/Looper）+ repo-fleet 巡检 skill：每天扫描 majiayu000 全部活跃仓库的 open issue/PR/新 comment/CI 状态，生成一份统一 triage 报告，标注"可直接 threads 处理 / 需要人决策"，人只做批准。
- **预期节省**：每天 5-10 个手打巡检 session、几十条「提交了吗」式轮询，估算每天 30-60 分钟，且消除仓库被遗忘的风险。

### 2. 自动化流水线的产出健康度监控（最大风险缺口）

- **模式**：反复人肉追问自动化系统是否活着、产出为什么少：「今天发了几个reply？」「怎么只有这么点啊」「为啥失败20个」「现在启动了吗」；且多次发现流水线空转无告警——"theme runner 记录 theme_map/、signals/ 目录持续为 0 个文件，ranker 空转轮询"、"2026-04-23 当天没有 reply"要三路子 agent 排查、runner "任务 10 分钟就早退"。
- **频率证据**：looper 状态追问"04-07/04-08 至少 7 个 session 原样重复"，之后每个月都在重复；额外还有 remem flush bug 烧光 Claude 额度、DeepSearch 被扣 100 刀这类"事后才发现"的事故。
- **覆盖状态**：**完全没有系统化**。有 looper-eval、x-post-eval 等质量 eval skill，但没有任何"产出量/心跳/成本"维度的 watchdog。
- **建议形式**：独立监控工具 + 每日推送：对 Looper、auto-run-agent、各 runner 统一采集「今日产出数、失败数、空转轮次、token/额度消耗」，异常（产出为 0、失败率>阈值、成本突增）主动推送，而不是等你问。
- **预期节省**：每天 3-5 次状态轮询 session；更重要的是把"额度瞬间烧空""扣 100 刀""流水线空转两天"这类事故从事后排查变成分钟级告警。

### 3. scout 素材 → X post + 配图的批量内容流水线补完

- **模式**：对每条资讯固定发两条模板消息：「给我用中文做一个 X post：…」+「给我用中文做一个图片：…」，以及后期的「URL：https://… 给我用中文使用imagegen的skill做一个图片」。
- **频率证据**：5 月上旬"5 天内约 70-80 次，几乎逐条素材成对出现"；imagegen 单条模板"两天内 40+ 次""本月内 40+ 个 session"；6 月仍在持续。另有"同一张 social card 连发 4+ 个 prompt 变体"的重试循环。
- **覆盖状态**：**已有 skill 但没覆盖到**。multi-post 明确就是干这个的（"从 scout 报告批量生成 X post + 配图"），但记录显示大量单条手发仍在发生——说明 multi-post 要么覆盖率不足（失败回退到手发），要么没接上定时触发。
- **建议形式**：把 multi-post 挂进 Looper 定时任务：scout 报告落盘 → 自动批量生成 post+图 → 进 review 队列；同时把反复重试炼出的配图 prompt 模板（1600×900 深蓝底、思源黑体、HARD CONSTRAINT 禁 SVG 回退）固化进 skill 的模板库，杜绝逐条微调。
- **预期节省**：每月 100+ 条手发模板消息，估算每月 8-10 小时。

### 4. 「看下这个库这是啥」仓库速览 → repo-brief skill

- **模式**：每接触一个仓库/工具/网站，第一句都是「看下这个库 这是啥啊」「你看下这个库是干嘛的呢」「你看下 https://www.magicpath.ai/ 这个是干嘛的呢？」。
- **频率证据**：4 月中"几乎每接触一个仓库都出现，本批至少 5 个仓库开场如此"；5 月"5 天内 10+ 次"；最后一批记录"10 个 session 中约 4-5 个属于此类，几乎是主导模式"。
- **覆盖状态**：**完全没有系统化**。每次都是自由发挥式回答，深度和格式不稳定。
- **建议形式**：轻量 skill（repo-brief）：固定输出「一句话定位 / 核心模块 / 最近 30 天活跃度 / open issue·PR 摘要 / 与你已有工具的重叠（对照 loom/remem/spellbook 清单）」。最后一项尤其重要——他曾在 design 目录重新立项"skill 管理工具"，功能与已有 loom 高度重叠。
- **预期节省**：每次省 2-3 轮追问；防重复造轮子的价值大于时间节省。

### 5. aiproxy 模型上线 + VSR 接入子流程

- **模式**：每上一个视频模型走同一套：对标厂商（wavespeed/fal）设计与定价 → 改 schema/路由 → dev 部署测试 → 实测生成 → 写 Lark 文档；VSR 接入更是逐模型重复（wan-2.7、kling-std、kling-pro、vidu_q3…）：「第一个加一个vsr 你帮我分析一下 如何设计」「走vsr的都需要标记清楚 参考 wan2.7的vsr 的schema」。
- **频率证据**："每上一个模型重复一次，本批至少 2-3 个模型"（5 月），6 月又给"排行榜高用量模型加 VSR 选项"批量重复，"针对 wan-2.7、kling-std、kling-pro 等多个模型反复做同类接入"。
- **覆盖状态**：**已有 skill 但没覆盖到**。aiproxy-workflow-deploy、model-onboarding 覆盖了 workflow 上线主流程（6 月已见「按 onboarding skill 给 vidu_q3 接 VSR」），但 **VSR/超分挂载**这个高频子流程没有独立的 checklist：显式 1080p/2k enum、TOOLS tag、计费路径验证、route priority 防 catch-all 压过（曾出过生产事故"720p-SR route priority 被 catch-all 路由压过"）。
- **建议形式**：给 aiproxy-workflow-deploy 增补 `vsr-attach` 子流程文档/skill，把踩过的坑（route priority、超分失败不扣钱、model_history NULL）写成强制验证步骤。
- **预期节省**：每个模型上线省 1-2 轮返工和一次潜在生产事故排查（此前 InfiniteTalk、720p-SR 均出过事故）。

### 6. prodjudge 分析的默认多窗口对比

- **模式**：用 prod-judge 查 DMS 使用率/报错后，总要手动追加：「你看看 7天 14天的 别只看7天的啊」「能不能出一个 4周的数量和比例的数值呢」。
- **频率证据**：4 月末至 7 月每次模型运营分析都出现，6-05 一天内"同一分析反复多轮"。
- **覆盖状态**：**已有 skill 但没覆盖到**——prod-judge 存在，但默认输出不含 7/14/28 天对比和比例列。
- **建议形式**：直接改 prod-judge skill：默认输出 7d/14d/4w 三窗口 + 环比 + 绝对量/比例双列。一次 skill 修改，永久消除追问。
- **预期节省**：每次分析省 2-3 轮往返，每月约 10+ 轮。

### 7. Mac 资源异常排查 → 已知病因库 + 定时哨兵

- **模式**：「你看下这台电脑 是什么在占用 cpu和内存呢 现在风扇一直在转」。且根因高度集中于**自己的工具链**：vibeguard 孤儿 hook 吃 120% CPU（至少 2 次）、post-edit-guard.sh 卡死 3.5 小时、remem core 59%/923MB、Codex zombie 进程、watcher 进程树。
- **频率证据**：4-7 月每批记录都有，估算每周 1-2 次，累计 15+ 个 session。
- **覆盖状态**：**已有 skill 但没覆盖到**。system-doctor、disk-cleaner 存在，但都是被动触发，且没有沉淀"本机惯犯清单"。
- **建议形式**：① 给 system-doctor 加"已知病因优先检查"列表（vibeguard hook、remem flush、Codex zombie、mihomo、Gatekeeper 扫描）；② launchd 定时哨兵：CPU/内存超阈值自动跑诊断并通知，附一键 kill；③ 对 vibeguard hook 本身加进程超时自杀（根治而非监控）。
- **预期节省**：每周 1-2 次排查 session（每次 10-20 分钟）+ 消除"风扇转了半天才发现 hook 卡死 3.5 小时"的隐性算力浪费。

### 8. 客户反馈 / 会议纪要 → issue 队列转换器

- **模式**：把客户英文反馈原文（「Page 18 – Submarket Snapshot High…values should be dynamically pulled」）、会议转录本（CRE Studio Sync）、同事飞书对话（Ted Ming、Eva Ma）整段粘贴进对话，让 AI 逐条消化成改动。
- **频率证据**：mutil-om 项目"6 月中下旬每隔一两天一批"，每批 5-10 条；aiproxy 侧"多条消息直接粘贴同事的飞书对话作为任务输入"。
- **覆盖状态**：**完全没有系统化**。每次都是临场逐条处理，条目遗漏靠人肉截图追问（「还有多少这样的？？？」）。
- **建议形式**：feedback-to-issues skill：输入反馈原文/转录本 → 自动解析成结构化条目（页码、严重度、验收标准）→ 批量开 issue → 接 threads/specrail 执行 → 输出逐条完成度对照表。
- **预期节省**：每批反馈省 30-60 分钟的逐条转述和"哪些做了哪些没做"的核对；漏项率下降。

### 9. 「AI 没用指定 skill / 越权动手」纠偏 → 执行验证 hook

- **模式**：反复发现 AI 没走指定 skill 或擅自实现，靠吼纠正：「所以你倒是用这个skill啊！」「你有没有用dotey的skill啊？」「我没让你做东西 我是让你走一个plan 和spec！！」「谁让你用xhscli啊 改skill 用computeruse！！！」「你在干嘛 我是让你用这个系统来生成 你怎么自己写了？？？」。
- **频率证据**："贯穿全月，高频"（4 月），5、6 月持续出现，估算每周数次。
- **覆盖状态**：**部分基建存在但没串起来**。skill-usage-stats 能统计使用，vibeguard 有 hook 体系，但没有"指令中点名了 skill → 校验本轮是否真的调用了该 skill"的闭环。
- **建议形式**：PostToolUse/Stop hook：检测用户消息中的 skill 点名（正则匹配「用 X 的 skill」「使用 X」），会话结束前核对 skill 调用记录，未命中则在停止前强制提示 agent 补用或明确报告为什么没用。
- **预期节省**：每周数次返工 + 情绪成本；这是他抱怨最频繁的失败模式之一。

### 10. runner 研究产出的消化层（digest + 去重 + 落地转化）

- **模式**：auto-run-agent 批量产出数百份研究报告，但"本人几乎没有出现在对话中做追问、修正或验收，产出是否被真正阅读不可见"；他自己也建了 autoresearch-meta-strategy runner，"承认目标是从大量 runner 中总结方法论，而不是继续盲目加 runner"。
- **频率证据**：4 月中下旬单日最高 373 个 runner session、50+ 个主题；多个方向（Obsidian 插件、media factory、remem 研究）只跑一天调研就无下文。
- **覆盖状态**：**意识到了但没做成**。remem-memory-quality-runner、research-to-prd-pipeline 都是针对这个问题开的 runner，但仍停在研究层。
- **建议形式**：不要再开新 runner，做一个消化管道：每天把所有 runner 新增 reports 压缩成一页 digest（结论 + 与已有结论的重复度 + 建议动作：转 PRD / 归档 / 停 runner），推送给你只做三选一决策；连续 N 天被标"归档"的 runner 自动停。
- **预期节省**：直接节省的是算力和 token（数百个低消化 session），更关键是把"研究工厂"从堆积模式变成收敛模式。

---

## 补充两项（价值稍低但改动成本极小）

### 11. git 状态自动汇报（消灭「提交了吗」）
「提交了吗」「push了吗」「开pr了吗」几乎是每个编码 session 的固定结尾（6 月记录"几乎每个实现类 session 末尾都出现"）。**完全没有系统化**。做一个 Stop hook：会话结束时自动输出「未提交文件 N / 未 push commit N / open PR 状态」，一行解决。

### 12. 周报/日报覆盖率校验
weekly/日报 skill 已存在，但曾出现「怎么没有om-gen-web的改动和deepsearch的改动呢？这个目录下的都需要啊」式漏报。**已有 skill 但没覆盖到**：给 weekly skill 加一步自检——对时间窗内所有有 commit 的仓库做清单比对，报告"已覆盖/未覆盖"仓库列表。

---

## 汇总：覆盖状态一览

| 类别 | 条目 |
|---|---|
| **完全没有系统化**（优先做） | #2 产出健康度监控、#4 repo-brief、#8 反馈→issue 转换、#11 git 状态汇报 |
| **已有 skill 但没覆盖到**（改造现有） | #1 仓库巡检（threads 有、定时+批量没有）、#3 内容流水线（multi-post 有、覆盖率/定时没有）、#5 VSR 子流程（onboarding 有、VSR checklist 没有）、#6 prodjudge 多窗口、#7 system-doctor 病因库、#9 skill 执行校验、#12 周报覆盖率 |
| **已系统化的正面样板**（可复制方法） | clash-doctor/clash-routes（代理排查已收口）、threads/specrail（单仓库流程已收口）、pod skill（排障流程即时固化的好习惯） |

一个总体观察：你的系统化能力本身很强（3 个月里把大量流程做成了 skill），真正的缺口集中在**两类**——(a) 已有 skill 的"最后一公里"：默认参数、定时触发、失败回退，导致仍需人肉轮询和追问；(b) 所有自动化都缺"自我汇报"层：产出量、健康度、完成度从不主动上报，全靠你连环追问（「怎么样了呢」「提交了吗」「发了几条」）。第二类是最值得投资的方向——它一次性消灭的是横跨所有项目的同一种劳动。

---

# 附录 B：深度缺口（完整材料）

# 视角二：不够深入的领域 —— 深挖 vs 放弃

**说明**：以下"现状证据"均引自 37 份 digest 的原文（事实）；"收益判断"和"路径"属于推断与建议，置信度已标注。判断基准：与 AtlasCloud 工作（aiproxy 网关、模型上线运维、OM 产品）和已验证的个人主线（agent 工具链、X 内容运营）的距离。

---

## 一、值得深入的领域（6 项，按优先级排序）

### 1. LLM/视频模型推理系统与服务化性能 ⭐ 最高优先级

**现状深度：只有"贴清单咨询"和"被动排障"两种浅层形态。**
- 04-15 贴入一份"动态批处理、KV Cache 分层存储"研究方向清单，只问"哪些是我能做的、需要什么硬件、做17要准备什么"，**纯咨询式对话，没有任何动手实现的 session**（digest 原话）。
- karpathy autoresearch：问"这是啥能不能用"、建了 rea 目录，"之后本批记录内无任何后续迭代"。
- LongCat-Video-Avatar 测试："问了脚本为什么慢、蒸馏为什么差就没有后续"。
- 对照组：工作中你天天在推理性能的"果"上打转——wan-2.6-spicy 延迟长尾 p50/p95/p99 分析、"52s 30fps 视频超分超时，按冷启动余量把时长上限削到 45s"、atlas_video 429 告警、VSR 使用率下滑排查。**全部是事后排障，没有一次进入"因"的层面**（事实 + 推断，置信度高）。

**深入后的收益**：AtlasCloud 的核心就是模型上线和网关。你现在的角色是"接模型、配 schema、查 DMS 定价"，推理层是黑盒；掌握 serving 内部机制后，超时/长尾/冷启动这类问题你能给出优化方案而不是削参数绕过，这是从"模型运维"到"平台性能负责人"的分界线。而且你已有独家素材：Topaz 模型逆向 + ONNX/TensorRT/OpenVINO 九模型 benchmark 是本 3 个月里少数做深了的技术线，差的只是往前一步。

**深入路径**：
- 学：vLLM 或 SGLang 源码走读（continuous batching、PagedAttention/KV cache 管理、prefill/decode 分离）；TensorRT-LLM 部署一遍；视频模型侧补 diffusion 推理加速（step distillation、TeaCache 类缓存）——这直接对应你问过的"蒸馏为什么差"。
- 做：两个都用现成素材。(a) 把已 detached 的 Topaz/VSR 模型包成一个有 p50/p95/p99 SLO、有冷启动指标的内部推理服务，接入 atlas_video；(b) 针对 wan 系列延迟长尾写一份根因 RFC（排队/冷启动/上游 provider 分解），在组内 review。
- 周期：8–12 周，每周 4–6 小时。这是唯一建议投"学习型"时间的领域。

### 2. Eval 工程化：从 200 个研究 runner 到一条真正闭环

**现状深度：研究量巨大、落地为零，这是最典型的"广而不深"。**
- 04-22~23 两天约 220 个 session 专门研究 agent eval（goal-taxonomy、trajectory-quality、production-scorecard…），但 harness-eval-fixture-builder 等 runner "prompt 自身声明'默认只产出 reports/backlog，不直接修改代码'——刻意停在设计层"。
- 症状端反复发作：04-29 "reply 质量差、同作者去重只在文档不在代码"；05-14 "今天 reply 质量好差"；06-30 还在问 "这个looper的xreply的skill 现在有问题就是回复太像ai了 怎么办呢"。**两个月里同一质量问题至少 4 次原样复发**（事实）。
- 工作侧同样卡住：prompt enhancement A/B 评测做了多轮只读调研（TIP-I2V/VidProM/VBench、15 个测试 case），digest 记录"未见实现或落地"。

**深入后的收益**：你所有的慢性痛点（reply 像 AI、runner 空转、skill 输出不满意、"为啥失败20个"）共享同一个根因——只有生成端没有校准过的评估端。这也是工作上 prompt enhancement 上线的硬需求。把一条线做穿，方法论可以直接复制到 aiproxy。

**深入路径**：
- 停止再开任何 eval 研究 runner（你已经有几百页报告了）。
- 做：只选 x-reply 一条线，做完整闭环：50 条人工标注黄金集 → deterministic gate + model grader → **grader 与你人工判断的一致率校准**（这一步是所有报告里缺的）→ 周度指标看板。跑满 4 周，看"像 AI"投诉是否消失。
- 迁移：把同一套（黄金集 + grader 校准 + 门禁）搬到 aiproxy prompt enhancement A/B，变成工作产出。
- 学的部分很少：Promptfoo/Langfuse 二选一实操即可，重点是校准纪律不是工具。
- 周期：6–8 周。

### 3. 计费/计量正确性（billing invariants）

**现状深度：至少 5 次独立生产计费事故，每次都是单点排障，从未系统化。**
- "seedance-2.0 720p-sr 显示价格与实际扣费不一致"（05-18）；
- "客户调用 wan-2.6-spicy 返回空但被扣费"的 DMS 排查（06-08）；
- "生产 billing 数据不一致排查（model_billing 有记录 model_history 没有）"（05 上旬）；
- "model_history.result.outputs 为 NULL 的生产事故"（06-10~12）；
- 个人侧也中招："DeepSearch 被扣 100 刀的 Google API 计费"、remem bug "瞬间耗尽 Claude Code 额度"。

**深入后的收益**：计费正确性是 AI 云平台的生命线；同类事故反复出现说明缺的不是修 bug 而是对账机制。做出"每日自动对账 + invariant 回归"是非常显性的工作亮点，且你已经有 prod-judge/DMS 全套工具链（推断，置信度高）。

**深入路径**：
- 学：metering 系统的三个核心概念——写入幂等、双录对账（usage 事件 vs billing 记录 vs provider 侧账单）、失败退款语义（你自己设计过"超分失败不扣钱"，说明已有直觉）。看一篇 Stripe/Orb 的 metering 架构文章级别即可，不需要长期学习。
- 做：给 aiproxy 写一个每日对账 job：`model_billing` × `model_history` × provider 回执三方比对，把上面 5 次事故各变成一条永久 invariant 检查，接告警。
- 周期：4–6 周，做完即收手。

### 4. 自动化产出的"消化端"与健康度监控（元问题）

**现状深度：生产端无限扩张，消费端为零。**
- 04-16 单日约 274 个 runner session、04-17~18 两天约 730 条同模板消息，digest 判断："批量生成研究报告但可能没人读"、"30+ 个研究主题…本人几乎没有出现在对话中做追问、修正或验收"。
- 最实锤的空转证据：theme runner "theme_map/、source_registry/、signals/ 目录持续为 0 个文件，ranker 处于空转轮询状态——流水线开起来了但上游没有真实产出"。
- 你自己也意识到了：建了 autoresearch-meta-strategy runner，其目标写明"从大量 runner 中总结方法论，而不是继续盲目加 runner"——但这又是一个 runner（事实，颇具讽刺性）。

**深入后的收益**：这是你 token、算力和注意力的最大黑洞。修好它等于给其他所有深入项腾出预算。不需要学任何新东西，需要的是一个 kill switch 和一个消费仪式。

**深入路径**（纯工程，2–3 周实现，长期执行）：
- 给 auto-run-agent 加三个机制：① 产出健康度指标（每轮新增文件数、上游数据是否为空——theme runner 那种空转应在第 2 轮被自动叫停）；② 报告"被消费"标记，7 天无人读自动停止 runner；③ 每周固定 30 分钟人工消化：读 top 3 报告，每份必须转成一个 issue/决策或直接删除。
- 硬性预算：并行 runner 上限 5 个（你曾同时开 21 个）。

### 5. 前端布局调试的最低限度亲手能力

**现状深度：同一 UI bug 多轮修不好，靠"贴截图 + 换 prompt 重试"死循环。**
- mutil-om："为什么能拖动刀下边去 我已经改过很多次了 都没生效"（05-28~29 连续 3+ session）；
- stash 拖拽："垃圾桶也没用 移动过去都没有"（单 session 5–6 轮修正）；
- vps-fff：改 UI 多次改坏，"怎么都显示不全了""咋回事啊"；
- loom/remem-web 配色："太丑了""还不够好看"式多轮返工。

**深入后的收益**：每个循环烧 30 分钟到数小时，且发生在**工作项目**（mutil-om 是客户交付物）。你不需要成为前端工程师，只需要能在 DevTools 里 5 分钟定位到"是哪个元素的 overflow/min-height/stacking context 出的问题"，然后把 computed style 证据喂给 AI——5 轮循环会压缩到 1–2 轮（推断，置信度高）。

**深入路径**：
- 学（刻意练习 2–3 周，每次 bug 现场学）：CSS 盒模型 + overflow、flex `min-height:0` 陷阱、position/stacking context、拖拽事件的 hit-testing。
- 做成规则：UI bug 一律先取证再改——自己开 DevTools 或强制 agent 走你已有的 css-debug skill / computeruse 截 computed style，禁止"盲改重试"。
- 这与你的 W-01（先根因后修复）规则完全一致，只是目前它没有覆盖到你的前端交互场景。

### 6. 凭据与安全习惯（一次性工程化，不算"学习"）

**现状深度：随意，且已经付出真实代价。**
- digest 直接记录："会直接在消息里贴 API key、SSH 地址等敏感信息，安全习惯较随意"（04-23~24，另有百炼 API key、支付宝账单解压密码入对话）。
- quotabar "错误刷写 Claude OAuth keychain"、"Claude OAuth 被 quotabar 反复清除"——自己的工具在破坏自己的凭据。
- rekey（密钥管理工具）："审计 + 一次性大修复计划后…未见持续迭代"——正确的方向立了项又烂尾。
- 你运行账号池代理（cli2proxy、"检查 token 是否失效并清理已死账号"）+ 大量无人值守 agent，攻击面持续扩大。

**深入后的收益**：你已有额度被烧光、被扣 100 刀的先例；agent 农场 + 账号池的组合下，一次 key 泄漏是真金白银损失。

**深入路径**（1–2 周收口，不需要持续投入）：所有 secrets 迁入 1Password CLI / env 注入，立规矩"对话里不出现明文 key"；rekey 二选一——两周内收敛成唯一凭据入口，或删掉改用现成方案。你的 VibeGuard SEC-02 规则早就写了，缺的是对自己执行。

---

## 二、浅尝辄止就够了 / 应该果断放弃的清单

| # | 领域 | 证据 | 判断 |
|---|------|------|------|
| 1 | **内容营销 research runner 矩阵**（小红书/YouTube/Reddit/Newsletter 文案、g3 系列 20 个创作方向、AI taste 5 件套、prompt pack 商业化、creator 工具需求、media asset factory） | 数百 session 全模板自动跑，"大量 turn_aborted"、"看不到任何人工对某个主题结果的追问、消化或后续迭代" | **全部停掉**。X 一条线已被验证有持续投入意愿，其余是 token 焚烧炉 |
| 2 | **电商选品/跨境运营 runner 集群**（ecom-niche-scanner、supply-radar 等 150 session） | 04-18 单日铺开后再未出现人工介入 | **放弃**。与工作、与已验证兴趣均无交集 |
| 3 | **Obsidian 插件** | 三轮调研零实现：04-23 demand runner、04-30 "改口去 reddit/X 看需求→要了个设计 spec"、05-01/03 又做 spec | **放弃**（或给最后一次 1 周 timebox 发一个最小插件，做不完即永久关闭。三次调研已证明意愿不足） |
| 4 | **抖音运营** | 你自己的复盘结论："工具不够适用于大众"；选题被你连续否定（"是不是太短了""这不是大家喜欢看的"）后无下文 | **放弃**。留 X 一个主战场 |
| 5 | **rui/rnk 自研 Rust UI 框架对标 WarpUI/Zed** | digest 判断"规模（把自研框架提升到 Warp UI 等级）与投入明显不匹配"，单日爆发式调研 | **放弃对标野心**，rnk 降级为个人玩具，不再开架构 issue |
| 6 | **VPS 测评/监控站 fff + VPS 选购** | "一个 session 内需求反复变化（对外网站→测评→监控系统）"；选购 session"同一句话重复 3 次"后无购买 | **放弃** |
| 7 | **一次性爬虫**（StreetEasy/ZenRows、OpenRouter rankings token 消耗） | 各 1 条消息，"未见落地" | **放弃** |
| 8 | **GPT-5.5 Pro 网页反代 / grok-oauth-proxy / 新代理方案** | grok proxy："算了 你帮我安装试试"改装官方 CLI；GPT-5.5 反代单 session 连问三方案无落地 | **够了**。cliproxy-newapi-stack 已能用，冻结新方案，只做存量维护 |
| 9 | **Codex Computer Use CLI 逆向重做** | 04-29 单日逆向取证（IPC/approval/Skyshot），"没有看到真正开始实现 CLI" | **放弃**。官方迭代速度会淹没自制品 |
| 10 | **沉浸式翻译拓展复刻（chenjinshi）** | 单 session"反编译看源码+基础架构设计"后无实现 | **放弃**。你已有 page-lingo，同类只留一个 |
| 11 | **be 仓库 4 个 agent 产品 PRD**（Control Tower/Agent Patterns/ContextOps/Agent Ledger） | 批量生成 PRD 后只问"哪个更容易火"，Agent Patterns 起头即自我质疑 | **放弃 3 个**。个人 agent 工具已有 keepline/helixflow/stash/loom/remem 五线并行，新立项应冻结（这属于视角一的收敛问题，此处只标记：不深入） |
| 12 | **karpathy autoresearch 及"研究方向清单"式咨询** | "贴一段二手介绍再问能不能用，探索多、深挖少" | **工具放弃**；其中推理系统方向并入上面第 1 项主线 |
| 13 | **零散上游开源贡献**（pandas PR、rust-lang PR、Warp issue） | pandas"仅一个 session"；Warp"把 spec 错放到 PR"、之后只问了句"现在怎么样了呢" | **放弃零散模式**。要么不做，要么选一个与工作相关的上游（如 vLLM/某 provider SDK）按季度认领 1 个 issue，蹭第 1 项的深入红利 |
| 14 | **数字人/百度慧播星 API** | "只有 1 个 session，停留在'能不能测试''为啥只有4秒'" | **跟随工作需要即可**，不主动深入；heygen 平替是正式工作任务，按任务节奏走，不额外投个人时间 |

---

## 三、一句话总结

你的"浅"不是能力问题，是**结构问题**：调研被外包给 runner 农场（生产无限、消费为零），实现被外包给 threads 流水线（能跑但不长本事），于是所有领域都停在"报告层"或"能用层"。建议只保 6 条深入线——其中 **推理系统（#1）是唯一值得投学习时间的**，eval（#2）和 billing（#3）直接兑换工作价值，#4/#5/#6 是止血型基建；其余 14 项果断关停，把每周省下的 runner 预算和 UI 重试时间全部还给前三项。

---

# 附录 C：画像与成长（完整材料）

# 工程师画像与成长路径分析（视角三）

**数据基础**：37 份 agent 摘要，覆盖 2026-04-04 ~ 2026-07-02 约 3 个月的 Claude Code + Codex 全部聊天记录。以下"事实"均可回溯到摘要中的具体证据；跨文件汇总的比例为推断，已标注置信度。

---

## 1. 时间实际花在哪里

先说一个必须拆开的前提：**session 量和本人注意力是两回事**。按摘要统计，全部 session 中约 70-90% 是机器自动触发的（auto-run-agent 研究 runner 单日最高 373 个 session；Looper 的 x-reply/x-reply-review 两天内近 700 次触发）。所以要分两个口径看。

**口径一：机器算力/session 量分布**（事实，直接来自摘要计数）

| 大类 | 占比估算 | 证据 |
|---|---|---|
| 内容运营自动化（Looper x-reply、批量配图、runner 内容线） | ~45% | 5 月起每份文件 x-reply 系列 200-700 次；"URL + imagegen 做图片"模板 40+ 次/批 |
| 自主研究 runner 农场 | ~30% | 4 月中下旬集中爆发：单日 274、373、740 条同模板消息，覆盖 50+ 主题 |
| 个人工具开发（issue/PR 流水线） | ~15% | threads/specrail 驱动的 review-merge 循环，跨 15+ 仓库 |
| 工作（AtlasCloud） | ~10% | 每份文件 aiproxy/mutil-om/VSR/hermes 合计 15-40 个 session |

**口径二：本人注意力分布**（推断，置信度中——依据手打消息的密度和纠偏深度）

- **个人工具开发与维护：约 35-40%**。remem、vibeguard、loom、litellm-rs、ccstats、keepline、helixflow、threads、specrail、rnk、rui、quotabar、caff、page-lingo……手打消息最密集、追问最深的都在这里。
- **工作（AtlasCloud）：约 25-30%**。aiproxy 模型上线/计费排障、mutil-om 客户反馈逐条落地、VSR/Topaz 逆向、hermes/UltraStudio 架构。工作任务的交互质量明显高于个人项目（"工作任务则明显更有纪律和深度"是多个分析 agent 的独立观察）。
- **学习探索/新想法立项：约 20%**。但绝大多数一次即止——37 份摘要累计列出 **60+ 个 shallow engagement**（agent todolist、聊天备份工具、grok-oauth-proxy、Obsidian 插件×3 次、video agent、VPS 站、数字人、Topaz 逆向落地……）。
- **内容运营监督：约 10-15%**。主要是催问和抱怨（"今天发了几个reply？""怎么只有这么点啊""回复太像ai了"）。

**一个直白的结论**：他的注意力最大头投在了"给自己造工具的工具"上，而这些工具服务的主要对象又是他自己的其他工具——4 月 23 日的摘要原话："大量算力花在改进 agent 工具链本身（编排器、harness、eval、memory），呈现明显的'造工具的工具'倾向"。自指循环占比过高。

---

## 2. 强项与明显短板

### 强项（有真实证据支撑）

1. **多 agent 编排能力是个人用户里的顶尖水平**。给子 agent 写的 lane prompt 高度专业：只读约束、文件所有权、severity 分级、file:line 证据、findings-first、事实/推断分离（"You are a read-only reviewer lane... Do not edit files. Return findings first with severity and file:line references"）。这套纪律在 6 月已经固化成 threads + specrail 的完整流水线（issue→spec→worker worktree→并行 review→merge gate，PR 常经二审三审）。
2. **流程沉淀本能强**。排障跑通立刻问"能不能做成 skill"（pod、codexlogguard、clash-doctor、vscode-doctor），并有 spellbook/skill 审计、retrospective、weekly 等元层治理。这是把个人经验资产化的正确动作。
3. **对 AI 幻觉和劣化的嗅觉敏锐**。反复出现的强约束："一定不能用任何mockdata"、"不要hardcode"、"严格区分真实示例和推断，不要编造"、"你这些是基于最新的main做的观测吗？"、"你确定吗？做一个测试"。这在重度委托者中很罕见，也是 vibeguard 项目的真实来源。
4. **工作侧有可交付的深度**。VSR/Topaz 符号级逆向、seedance 计费路径的 DMS 级排查、按客户 comment 逐条修 OM（"Page 14 – Lease Expiration Schedule High"）都是有闭环的实活。

### 明显短板

1. **自己几乎不读代码、不写代码，验证外包给 AI 审 AI**。多份摘要独立指出"他严重依赖 AI 做验证而非自己读代码"。质量把关方式是连环追问（"提交了吗""你都实现了吗？？"）而非亲自核查。这正是他自己规则集里写的"comprehension debt / 80% problem"——**他知道这个坑，但自己就在坑里**。
2. **对自己产物的记忆已经外化到工具**。6 月摘要："对自己产物记忆模糊、依赖 remem/git/聊天记录回溯"（"我之前做了一个 vsr 的顺序的表格 你看看在哪里"、"我在周三之后都做了什么"）。这是理解权转移给 AI 的直接后果。
3. **产出消化率极低**。4 月的研究农场铺了 50+ 主题、单日 740 条模板消息，但"从这批消息中看不到任何人工对某个主题结果的追问、消化或后续迭代"；theme runner 上游目录持续 0 文件仍空转轮询；自己都发现"为啥失败20个"。**批量生成的研究报告大概率没人读**——他自己也建了 autoresearch-meta-strategy runner 承认"不要继续盲目加 runner"，但行为没变。
4. **自动化基建反噬自己，且不止一次**：remem 疯狂 flush 把 Claude Code 额度瞬间烧空；vibeguard 孤儿 hook 吃满 CPU 3.5 小时、风扇狂转；Codex 日志写爆 SSD；DeepSearch 被 Google API 扣 100 刀。**缺少资源/成本护栏是系统性问题，不是偶发**。
5. **安全习惯粗糙**：摘要明确记录"会直接在消息里贴 API key、SSH 地址等敏感信息"、贴支付宝账单解压密码——与他维护 SEC-01/SEC-02 规则集的身份自相矛盾。
6. **同一 bug 反复修不好**：starship 字体两天两次、mutil-om 白边"我已经改过很多次了 都没生效"、x-reply 质量抱怨从 4 月持续到 7 月（"怎么只有这么点啊"→"回复太像ai了"→"今天的reply质量好差"）。委托式修复对顽固问题的收敛速度很差。

---

## 3. 工作方式的问题（直言）

1. **并行度失控，收尾率惨淡**。两天切换 15+ 仓库是常态；37 份摘要累计 60+ 个一次即止的话题。典型模式是"一句话立项→开 5 个子 agent 调研→出 spec→挂起"：agent todolist、统一 runtime、symphony 网页版、video agent、Obsidian 插件（**至少立项 3 次，5-01、5-19 前后、6 月，每次都停在 spec**）。启动成本被 AI 降到接近零，但**放弃成本也是零，于是什么都启动、什么都不结束**。
2. **用"再开一个 runner/再加一个工具"代替消化**。研究农场的本质是把"我应该读点什么"变成"我让 agent 帮我读了"，然后既没读报告也没做决策。4 月烧掉的数百个 runner session，在 5-7 月的活动里几乎找不到任何被引用的痕迹（推断，置信度中：摘要中未见任何"根据 X runner 报告做了 Y"的记录）。
3. **AI 依赖方式部分不健康**。健康的部分：结构化 lane prompt、多角度对抗评审、强制证据。不健康的部分：(a) review AI 的还是 AI，人只看"merge 了吗"；(b) 遇到偏差靠事后打断怒吼纠偏（"你在干嘛 我有说过让你用atlas的skill吗"、"我是让你做文案啊！！"）而非事前把约束写进 prompt——同类纠偏从 4 月骂到 7 月，说明**没有把纠偏教训回灌到 skill 里形成闭环**（讽刺的是他有 vibeguard:learn 这个 skill）；(c) 同一 prompt 在 runtime 项目重发十余次，时间浪费可观。
4. **内容运营线 ROI 存疑但持续加码**。x-reply 从 4 月跑到 7 月，累计数千次自动执行，占据最大的 session 份额，但全程可见的效果反馈只有抱怨（涨粉目标净增 30/天后再无量化复盘出现在记录中）。**这是典型的"自动化沉没成本"：因为流水线已经建好，所以继续跑，而不是因为它有效**。
5. **个人开源库的 issue/PR 流水线有"自产自销"嫌疑**。"审计→开 issue→做 PR→review→merge"的循环大量消耗在自己给自己的仓库造工作量上；除 claude-skill-registry 有真实社区 PR、jsonrepair-rs/litellm-rs 有零星外部交互外，多数库看不到外部用户证据（推断，置信度中）。

---

## 4. 未来 6-12 个月最值得押注的 2-3 个方向

### 押注一：把 threads + specrail + keepline + remem 收敛成**一个** agent 交付流水线产品（最高优先级）

理由：这是他唯一有真实差异化积累的东西。三个月里他在 15+ 个仓库反复验证了同一套"issue→spec→隔离 worktree→并行只读 review→merge gate"流程，lane prompt 模板、文件所有权纪律、多轮 merge 审查都已经打磨到可复制的程度——**这套东西本身就是产品，而他现在把它当自用脚本散落在 4-5 个仓库里**（threads、specrail、implx、keepline、workflow）。6-30 他自己让 AI 生成的 4 个产品想法里（Orchestration Dashboard、Agent Patterns、ContextOps、Agent Ledger），本质上全是这条线的变体，说明他潜意识也知道答案。条件：**先杀掉其余 10 个个人库的维护循环**，否则又是第 16 个并行仓库。

### 押注二：AtlasCloud 工作线的"模型生产运维/eval 体系"专业深度

理由：这是三个月里唯一有真实付费用户、真实生产数据、真实反馈闭环的场景。prodjudge + DMS 排查、VSR benchmark、model onboarding skill、计费一致性排查已经形成雏形，且他在这条线上的交互质量明显最高（客户 comment 逐条落地、事故复盘、"超分失败不扣钱"的计费设计）。把它从"个人 skill 集合"升级成团队可用的模型上线/eval/观测体系，是职业价值最确定的路径——比任何个人 side project 的期望值都高。他 4 月跑的一大堆 agent-eval 研究 runner（goal-taxonomy、trajectory-quality、production-scorecard）恰好是这个方向的理论储备，**目前是唯一有机会把研究农场沉没成本变现的地方**。

### 押注三（反向押注）：**关停或降级内容运营自动化和研究 runner 农场**

理由：这两块吃掉了 session 量的 70%+ 和相当一部分注意力（催问、修 skill、排查 backlog），但三个月里没有任何可见的量化正反馈——X 增长目标只在 4 月初出现过一次，之后全是质量抱怨；50+ 研究主题零消化。建议：x-reply 降到每天一次人工批处理或直接停掉；runner 农场保留 1-2 个与押注一/二直接相关的（如 harness-eval），其余归档。**省下来的不是算力，是他自己的碎片化注意力**——这是他目前最稀缺的资源。

---

### 一句话总结

他已经是一个非常出色的 agent 编排者，但正在用"编排的广度"逃避"交付的深度"：工具链的成熟度是 90 分，而"选一件事做完并让别人用起来"的纪律大概是 40 分。未来一年的杠杆不在再造任何新工具，而在砍掉 80% 的并行线，把 threads/specrail 这一套变成有外部用户的产品，把工作线的 eval 体系变成团队资产。