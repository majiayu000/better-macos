import Foundation

final class NoopReminders: ReminderScheduling {
    func scheduleFocusEnd(at date: Date, action: String) async throws {}
    func cancelFocusEnd() {}
    func applyDaily(_ settings: ReminderSettings) async throws {}
}

enum CheckFailure: LocalizedError {
    case failed(String)

    var errorDescription: String? {
        switch self {
        case let .failed(message): message
        }
    }
}

@main
struct CoreChecks {
    @MainActor
    static func main() throws {
        try activeBetLimit()
        try focusPersistenceAndEvidence()
        try requiredFocusFields()
        try decisionRanking()
        try rollingBetMetadata()
        try betEditingPreservesCycle()
        try cycleReviewAndCoachRotation()
        try cycleReviewCloseGuard()
        try codexPlanningContextAndValidation()
        try legacyDataMigration()
        try coachPersistenceAndMessageLimit()
        try coachContextDelta()
        try coachCycleReviewContext()
        try codexEventParsing()
        try gitStatusParser()
        try gitRepositoryInspectionAndPersistence()
        try gitContextPrompt()
        try corruptDataPreservation()
        try appIconCatalogContract()
        print("PASS: 19 Better core checks")
    }

    @MainActor
    private static func activeBetLimit() throws {
        let store = makeStore()
        try store.addBet(title: "一", outcome: "结果一", assumption: "假设一")
        try store.addBet(title: "二", outcome: "结果二", assumption: "假设二")
        try store.addBet(title: "三", outcome: "结果三", assumption: "假设三")

        do {
            try store.addBet(title: "四", outcome: "结果四", assumption: "假设四")
            throw CheckFailure.failed("第四条活跃押注被错误接受")
        } catch BetterStoreError.activeBetLimit {
            try expect(store.activeBets.count == 3, "活跃押注数量不是三条")
        }
    }

    @MainActor
    private static func focusPersistenceAndEvidence() throws {
        let url = temporaryStorage()
        let store = AppStore(storageURL: url, reminders: NoopReminders())
        try store.addBet(title: "验证需求", outcome: "三个人真实尝试", assumption: "问题足够痛")
        guard let betID = store.activeBets.first?.id else {
            throw CheckFailure.failed("押注没有保存")
        }
        try store.createFocus(
            betID: betID,
            action: "约一位目标用户做十分钟访谈",
            expectedEvidence: "一段具体的现有替代方案描述",
            kind: .problem,
            durationMinutes: 25
        )

        let reloaded = AppStore(storageURL: url, reminders: NoopReminders())
        try expect(reloaded.data.currentFocus?.action == "约一位目标用户做十分钟访谈", "焦点没有恢复")
        try reloaded.startFocus(now: Date(timeIntervalSince1970: 1_000))
        try expect(reloaded.data.currentFocus?.endsAt == Date(timeIntervalSince1970: 2_500), "计时结束时间不正确")
        try reloaded.completeFocus(actualEvidence: "对方目前每周手工整理两小时", unresolvedQuestion: "是否愿意试用")
        try expect(reloaded.data.currentFocus == nil, "完成后焦点没有清空")
        try expect(reloaded.data.evidence.count == 1, "完成后没有证据记录")
        try expect(
            reloaded.data.pendingReviewEvidenceID == reloaded.data.evidence.first?.id,
            "完成后没有留下待复盘证据"
        )
    }

    @MainActor
    private static func requiredFocusFields() throws {
        let store = makeStore()
        try store.addBet(title: "验证需求", outcome: "三个人尝试", assumption: "问题存在")
        guard let betID = store.activeBets.first?.id else {
            throw CheckFailure.failed("押注没有保存")
        }

        do {
            try store.createFocus(
                betID: betID,
                action: "",
                expectedEvidence: "有人试用",
                kind: .attempt,
                durationMinutes: 50
            )
            throw CheckFailure.failed("空行动被错误接受")
        } catch BetterStoreError.emptyField("唯一行动") {}

        do {
            try store.createFocus(
                betID: betID,
                action: "发出原型",
                expectedEvidence: "  ",
                kind: .attempt,
                durationMinutes: 50
            )
            throw CheckFailure.failed("空证据被错误接受")
        } catch BetterStoreError.emptyField("预期证据") {}
    }

    private static func decisionRanking() throws {
        let betID = UUID()
        let strong = ActionCandidate(
            betID: betID,
            action: "把原型交给一位用户试用",
            expectedEvidence: "一次真实尝试",
            evidenceKind: .attempt,
            validatesRiskiestAssumption: true,
            evidenceWithin48Hours: true,
            fitsOneFocusBlock: true,
            expandsMaintenanceSurface: false
        )
        let broad = ActionCandidate(
            betID: betID,
            action: "新建一个完整平台",
            expectedEvidence: "写完架构文档",
            evidenceKind: .deliverable,
            validatesRiskiestAssumption: false,
            evidenceWithin48Hours: false,
            fitsOneFocusBlock: false,
            expandsMaintenanceSurface: true
        )
        let ranked = DecisionEngine.rank([broad, strong])
        try expect(ranked.first?.candidate.id == strong.id, "决策排序没有优先真实证据")
        try expect(ranked.first?.score == 14, "强候选分数不正确")
        try expect(ranked.last?.score == -3, "扩张维护面的惩罚不正确")
    }

    @MainActor
    private static func rollingBetMetadata() throws {
        let url = temporaryStorage()
        let store = AppStore(storageURL: url, reminders: NoopReminders())
        try store.addBet(
            title: "验证需求",
            outcome: "七天内三个人尝试",
            assumption: "问题足够痛",
            horizonDays: 7,
            evidenceGoal: "三次真实尝试"
        )
        let reloaded = AppStore(storageURL: url, reminders: NoopReminders())
        try expect(reloaded.activeBets.first?.resolvedHorizonDays == 7, "滚动周期没有保存")
        try expect(reloaded.activeBets.first?.evidenceGoal == "三次真实尝试", "证据门槛没有保存")
    }

    @MainActor
    private static func betEditingPreservesCycle() throws {
        let store = makeStore()
        try store.addBet(
            title: "旧名称",
            outcome: "旧结果",
            assumption: "旧假设",
            horizonDays: 14,
            evidenceGoal: "旧门槛"
        )
        guard let bet = store.activeBets.first else {
            throw CheckFailure.failed("编辑检查缺少押注")
        }
        let originalCycleStart = bet.cycleStartDate
        try store.updateBet(
            bet.id,
            title: "新名称",
            outcome: "新结果",
            assumption: "新假设",
            horizonDays: 7,
            evidenceGoal: "新门槛"
        )
        guard let updated = store.bet(id: bet.id) else {
            throw CheckFailure.failed("编辑后押注丢失")
        }
        try expect(updated.title == "新名称", "押注名称没有更新")
        try expect(updated.resolvedHorizonDays == 7, "押注周期没有更新")
        try expect(updated.evidenceGoal == "新门槛", "押注门槛没有更新")
        try expect(updated.cycleStartDate == originalCycleStart, "编辑押注错误地重置了周期")

        let dueURL = temporaryStorage()
        let dueBet = Bet(
            title: "已到期押注",
            sixWeekOutcome: "到期结果",
            riskiestAssumption: "到期假设",
            createdAt: Calendar.current.date(byAdding: .day, value: -8, to: .now) ?? .now,
            horizonDays: 7,
            evidenceGoal: "到期门槛"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try FileManager.default.createDirectory(
            at: dueURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode(BetterData(bets: [dueBet])).write(to: dueURL)
        let dueStore = AppStore(storageURL: dueURL, reminders: NoopReminders())
        do {
            try dueStore.updateBet(
                dueBet.id,
                title: dueBet.title,
                outcome: dueBet.sixWeekOutcome,
                assumption: dueBet.riskiestAssumption,
                horizonDays: 14,
                evidenceGoal: dueBet.evidenceGoal ?? dueBet.sixWeekOutcome
            )
            throw CheckFailure.failed("已到期押注通过编辑延后了复盘")
        } catch BetterStoreError.reviewRequiredBeforeHorizonChange {}
    }

    @MainActor
    private static func cycleReviewAndCoachRotation() throws {
        let store = makeStore()
        try store.addBet(
            title: "验证需求",
            outcome: "一人完成真实尝试",
            assumption: "触达方式有效",
            horizonDays: 7,
            evidenceGoal: "一次真实尝试"
        )
        guard let betID = store.activeBets.first?.id else {
            throw CheckFailure.failed("周期复盘检查缺少押注")
        }
        try store.createFocus(
            betID: betID,
            action: "完成一次手工演示",
            expectedEvidence: "一次真实操作",
            kind: .attempt,
            durationMinutes: 25
        )
        try store.startFocus()
        try store.completeFocus(
            actualEvidence: "对方完成了操作",
            unresolvedQuestion: "是否会主动返回"
        )
        try store.recordCoachExchange(
            userText: "本周期得到了一次真实尝试",
            assistantText: "先看对方是否会主动返回。",
            threadID: "cycle-thread",
            contextFingerprint: "cycle-fingerprint",
            rebuiltThread: false
        )

        let reviewTime = Date.now.addingTimeInterval(2)
        try store.reviewBet(
            betID,
            conclusion: "真实尝试成立，但返回行为仍未知",
            decision: .continueBet,
            now: reviewTime
        )
        let review = store.data.cycleReviews.first
        try expect(review?.evidenceCount == 1, "周期复盘没有统计当期证据")
        try expect(review?.externalEvidenceCount == 1, "周期复盘没有统计外部证据")
        try expect(review?.strongestEvidenceKind == .attempt, "周期复盘最强证据不正确")
        try expect(store.bet(id: betID)?.cycleStartDate == reviewTime, "继续押注没有开启新周期")
        try expect(store.data.coach.threadID == nil, "周期复盘后 Coach 线程没有轮换")
        try expect(store.data.coach.messages.count == 2, "线程轮换错误地清除了本地消息")
        try expect(
            store.data.coach.archivedThreads?.first?.threadID == "cycle-thread",
            "旧 Coach 线程没有归档"
        )
        try expect(
            store.data.coach.archivedThreads?.first?.handoffSummary.contains("返回行为仍未知") == true,
            "Coach 交接摘要遗漏周期结论"
        )

        let adjustedTime = reviewTime.addingTimeInterval(2)
        try store.reviewBet(
            betID,
            conclusion: "需要缩小到主动返回验证",
            decision: .adjust,
            adjustedOutcome: "一人在七天内主动返回",
            adjustedEvidenceGoal: "一次未催促返回",
            adjustedAssumption: "一次成功体验足以促成返回",
            adjustedHorizonDays: 7,
            now: adjustedTime
        )
        try expect(store.bet(id: betID)?.sixWeekOutcome == "一人在七天内主动返回", "调整复盘没有更新结果")
        try expect(store.bet(id: betID)?.cycleStartDate == adjustedTime, "调整复盘没有重置周期")
    }

    @MainActor
    private static func cycleReviewCloseGuard() throws {
        let store = makeStore()
        try store.addBet(title: "关闭检查", outcome: "完成结果", assumption: "假设")
        guard let betID = store.activeBets.first?.id else {
            throw CheckFailure.failed("关闭检查缺少押注")
        }
        try store.createFocus(
            betID: betID,
            action: "当前行动",
            expectedEvidence: "当前证据",
            kind: .deliverable,
            durationMinutes: 25
        )
        do {
            try store.reviewBet(
                betID,
                conclusion: "希望关闭",
                decision: .complete
            )
            throw CheckFailure.failed("有当前焦点时错误地完成了押注")
        } catch BetterStoreError.cannotCloseFocusedBet {}
        try expect(store.data.cycleReviews.isEmpty, "失败的关闭仍写入了复盘")

        try store.discardUnstartedFocus()
        try store.reviewBet(
            betID,
            conclusion: "证据门槛已经达到",
            decision: .complete
        )
        try expect(store.bet(id: betID)?.status == .completed, "复盘完成没有关闭押注")
        try expect(store.completedBets.first?.id == betID, "完成押注没有进入历史")
    }

    private static func codexPlanningContextAndValidation() throws {
        let bet = Bet(
            title: "验证需求",
            sixWeekOutcome: "十四天内三个人尝试",
            riskiestAssumption: "问题足够痛",
            horizonDays: 14,
            evidenceGoal: "三次真实尝试"
        )
        let evidence = EvidenceRecord(
            betID: bet.id,
            action: "发出原型",
            expectedEvidence: "一人试用",
            actualEvidence: "没有回复",
            unresolvedQuestion: "触达人群是否正确",
            kind: .attempt,
            focusMinutes: 50,
            adaptationNote: "下午精力低，需要缩小范围",
            energyLevel: 2
        )
        var data = BetterData()
        data.bets = [bet]
        data.evidence = [evidence]

        let prompt = try CodexPlanningService.planningPrompt(
            for: data,
            now: Date(timeIntervalSince1970: 2_000)
        )
        try expect(prompt.contains("下午精力低，需要缩小范围"), "规划上下文遗漏现实变化")
        try expect(prompt.contains("三次真实尝试"), "规划上下文遗漏证据门槛")

        let valid = CodexFocusSuggestion(
            betID: bet.id,
            action: "给一位目标用户做五分钟手工演示",
            expectedEvidence: "一次真实操作",
            evidenceKind: .attempt,
            durationMinutes: 25,
            rationale: "缩小范围并改变验证方法"
        )
        try CodexPlanningService.validate(valid, against: data)

        let invalid = CodexFocusSuggestion(
            betID: UUID(),
            action: "新开项目",
            expectedEvidence: "完成文档",
            evidenceKind: .deliverable,
            durationMinutes: 25,
            rationale: "扩大范围"
        )
        do {
            try CodexPlanningService.validate(invalid, against: data)
            throw CheckFailure.failed("未知押注被错误接受")
        } catch CodexPlannerError.invalidSuggestion(_) {}
    }

    @MainActor
    private static func legacyDataMigration() throws {
        let url = temporaryStorage()
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let legacyJSON = """
        {
          "version": 1,
          "bets": [],
          "currentFocus": null,
          "evidence": [],
          "parkedIdeas": [],
          "reminders": {
            "enabled": false,
            "startHour": 9,
            "startMinute": 30,
            "reviewHour": 21,
            "reviewMinute": 30
          }
        }
        """
        try Data(legacyJSON.utf8).write(to: url)

        let store = AppStore(storageURL: url, reminders: NoopReminders())
        try expect(store.errorMessage == nil, "v1 数据无法迁移")
        try expect(store.data.version == BetterData.currentVersion, "迁移后版本不是 v4")
        try expect(store.data.coach == CoachState(), "迁移后 Coach 状态不是空状态")
        try expect(store.data.pendingReviewEvidenceID == nil, "迁移后错误地产生待复盘证据")
        try expect(store.data.cycleReviews.isEmpty, "迁移后错误地产生周期复盘")

        let v2URL = temporaryStorage()
        try FileManager.default.createDirectory(
            at: v2URL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let v2JSON = """
        {
          "version": 2,
          "bets": [],
          "currentFocus": null,
          "evidence": [],
          "parkedIdeas": [],
          "reminders": {
            "enabled": false,
            "startHour": 9,
            "startMinute": 30,
            "reviewHour": 21,
            "reviewMinute": 30
          },
          "coach": {
            "threadID": "legacy-v2-thread",
            "messages": []
          },
          "pendingReviewEvidenceID": null
        }
        """
        try Data(v2JSON.utf8).write(to: v2URL)
        let v2Store = AppStore(storageURL: v2URL, reminders: NoopReminders())
        try expect(v2Store.errorMessage == nil, "v2 数据无法迁移")
        try expect(v2Store.data.coach.threadID == "legacy-v2-thread", "v2 Coach 线程在迁移中丢失")
        try expect(v2Store.data.coach.archivedThreads == nil, "v2 迁移错误地产生线程归档")
        try expect(v2Store.data.cycleReviews.isEmpty, "v2 迁移错误地产生周期复盘")

        let v3URL = temporaryStorage()
        try FileManager.default.createDirectory(
            at: v3URL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let v3JSON = """
        {
          "version": 3,
          "bets": [],
          "currentFocus": null,
          "evidence": [],
          "parkedIdeas": [],
          "reminders": {
            "enabled": false,
            "startHour": 9,
            "startMinute": 30,
            "reviewHour": 21,
            "reviewMinute": 30
          },
          "coach": { "messages": [] },
          "pendingReviewEvidenceID": null,
          "cycleReviews": []
        }
        """
        try Data(v3JSON.utf8).write(to: v3URL)
        let v3Store = AppStore(storageURL: v3URL, reminders: NoopReminders())
        try expect(v3Store.errorMessage == nil, "v3 数据无法迁移")
        try expect(v3Store.data.gitRepositories.isEmpty, "v3 迁移错误地产生 Git 仓库")
    }

    @MainActor
    private static func coachPersistenceAndMessageLimit() throws {
        let url = temporaryStorage()
        let store = AppStore(storageURL: url, reminders: NoopReminders())
        try store.addBet(
            title: "验证需求",
            outcome: "三个人真实尝试",
            assumption: "问题足够痛"
        )
        guard let betID = store.activeBets.first?.id else {
            throw CheckFailure.failed("Coach 检查缺少押注")
        }

        for index in 0..<21 {
            try store.recordCoachExchange(
                userText: "用户消息 \(index)",
                assistantText: "Coach 回复 \(index)",
                threadID: "thread-1",
                contextFingerprint: "fingerprint-\(index)",
                rebuiltThread: index == 0,
                now: Date(timeIntervalSince1970: TimeInterval(index + 1))
            )
        }
        try expect(store.data.coach.messages.count == 40, "Coach 本地消息没有限制为 40 条")
        try expect(store.data.coach.messages.first?.text == "用户消息 1", "Coach 消息裁剪顺序错误")

        let suggestion = CodexFocusSuggestion(
            betID: betID,
            action: "约一位目标用户完成一次手工演示",
            expectedEvidence: "一次真实操作",
            evidenceKind: .attempt,
            durationMinutes: 25,
            rationale: "先验证最危险的假设"
        )
        try store.recordCoachSuggestion(
            suggestion,
            userText: "生成下一步提案",
            assistantText: CodexCoachService.assistantSummary(for: suggestion),
            threadID: "thread-1",
            contextFingerprint: "final-fingerprint",
            rebuiltThread: false
        )

        let reloaded = AppStore(storageURL: url, reminders: NoopReminders())
        try expect(reloaded.data.coach.threadID == "thread-1", "Coach 线程 ID 没有恢复")
        try expect(reloaded.data.coach.pendingSuggestion?.action == suggestion.action, "Coach 提案没有恢复")
        try reloaded.acceptCoachSuggestion()
        try expect(reloaded.data.currentFocus?.action == suggestion.action, "确认提案后没有创建焦点")
        try expect(reloaded.data.coach.pendingSuggestion == nil, "确认后没有清除待定提案")
    }

    private static func coachContextDelta() throws {
        let bet = Bet(
            title: "验证需求",
            sixWeekOutcome: "三个人完成尝试",
            riskiestAssumption: "触达方式有效"
        )
        let oldEvidence = EvidenceRecord(
            betID: bet.id,
            action: "旧行动",
            expectedEvidence: "旧预期",
            actualEvidence: "旧证据不应重复发送",
            unresolvedQuestion: "",
            kind: .attempt,
            recordedAt: Date(timeIntervalSince1970: 100),
            focusMinutes: 25
        )
        let newEvidence = EvidenceRecord(
            betID: bet.id,
            action: "新行动",
            expectedEvidence: "新预期",
            actualEvidence: "最新证据应该进入增量",
            unresolvedQuestion: "下一步触达谁",
            kind: .attempt,
            recordedAt: Date(timeIntervalSince1970: 300),
            focusMinutes: 25
        )
        var data = BetterData(bets: [bet], evidence: [newEvidence, oldEvidence])
        data.coach.lastUsedAt = Date(timeIntervalSince1970: 200)

        let prompt = try CodexCoachService.conversationPrompt(
            for: data,
            message: "我接下来应该考虑什么？",
            fullContext: false,
            now: Date(timeIntervalSince1970: 400)
        )
        try expect(prompt.contains("最新证据应该进入增量"), "Coach 增量遗漏最新证据")
        try expect(!prompt.contains("旧证据不应重复发送"), "Coach 增量重复发送旧证据")
        try expect(prompt.contains("我接下来应该考虑什么？"), "Coach 提示遗漏用户消息")
    }

    private static func coachCycleReviewContext() throws {
        let bet = Bet(
            title: "验证返回行为",
            sixWeekOutcome: "一人主动返回",
            riskiestAssumption: "首次体验足够有价值"
        )
        let review = BetCycleReview(
            betID: bet.id,
            betTitle: bet.title,
            cycleStartedAt: Date(timeIntervalSince1970: 100),
            reviewedAt: Date(timeIntervalSince1970: 200),
            horizonDays: 7,
            outcome: "一人尝试",
            evidenceGoal: "一次真实尝试",
            riskiestAssumption: "有人愿意尝试",
            evidenceCount: 1,
            externalEvidenceCount: 1,
            strongestEvidenceKind: .attempt,
            conclusion: "尝试成立，但尚无主动返回",
            decision: .adjust
        )
        let data = BetterData(bets: [bet], cycleReviews: [review])
        let prompt = try CodexCoachService.conversationPrompt(
            for: data,
            message: "新周期从哪里开始？",
            fullContext: true,
            now: Date(timeIntervalSince1970: 300)
        )
        try expect(prompt.contains("尝试成立，但尚无主动返回"), "Coach 完整上下文遗漏周期结论")
        try expect(prompt.contains("recent_cycle_reviews"), "Coach 上下文没有周期复盘字段")
    }

    private static func codexEventParsing() throws {
        let jsonl = """
        {"type":"thread.started","thread_id":"thread-check"}
        {"type":"turn.started"}
        {"type":"item.completed","item":{"id":"item-1","type":"agent_message","text":"第一条回复"}}
        {"type":"item.completed","item":{"id":"item-2","type":"agent_message","text":"最终回复"}}
        {"type":"turn.completed"}

        """
        let output = try CodexCoachService.parseJSONL(
            Data(jsonl.utf8),
            resumedThreadID: nil
        )
        try expect(output.threadID == "thread-check", "Codex 事件没有解析线程 ID")
        try expect(output.assistantText == "最终回复", "Codex 事件没有选择最后一条 Agent 回复")
    }

    private static func gitStatusParser() throws {
        let status = " M tracked file\u{0}A  staged file\u{0}?? untracked file\u{0}UU conflict file\u{0}R  renamed file\u{0}old file\u{0}"
        let counts = try GitContextService.parseStatus(Data(status.utf8))
        try expect(counts.staged == 2, "Git status 暂存计数不正确")
        try expect(counts.modified == 1, "Git status 修改计数不正确")
        try expect(counts.untracked == 1, "Git status 未跟踪计数不正确")
        try expect(counts.conflicts == 1, "Git status 冲突计数不正确")
    }

    @MainActor
    private static func gitRepositoryInspectionAndPersistence() throws {
        let fixtureRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("Better Git Fixture \(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: fixtureRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: fixtureRoot) }

        try runProcess("/usr/bin/git", ["init", "-b", "main", fixtureRoot.path])
        try runProcess("/usr/bin/git", ["-C", fixtureRoot.path, "config", "user.name", "Better Check"])
        try runProcess("/usr/bin/git", ["-C", fixtureRoot.path, "config", "user.email", "better-check@example.invalid"])
        let trackedURL = fixtureRoot.appendingPathComponent("tracked file.txt")
        try Data("initial\n".utf8).write(to: trackedURL)
        try runProcess("/usr/bin/git", ["-C", fixtureRoot.path, "add", "tracked file.txt"])
        try runProcess("/usr/bin/git", ["-C", fixtureRoot.path, "commit", "-m", "initial fixture"])

        try Data("changed\n".utf8).write(to: trackedURL)
        let stagedURL = fixtureRoot.appendingPathComponent("staged file.txt")
        try Data("staged\n".utf8).write(to: stagedURL)
        try runProcess("/usr/bin/git", ["-C", fixtureRoot.path, "add", "staged file.txt"])
        try Data("untracked\n".utf8).write(
            to: fixtureRoot.appendingPathComponent("untracked file.txt")
        )

        let snapshot = try GitContextService.inspectRepository(at: fixtureRoot.path)
        try expect(snapshot.rootPath == fixtureRoot.resolvingSymlinksInPath().path, "Git 根路径没有规范化")
        try expect(snapshot.branch == "main", "Git 分支读取错误")
        try expect(snapshot.headSHA.count == 40, "Git HEAD SHA 不完整")
        try expect(snapshot.stagedCount == 1, "真实仓库暂存计数错误")
        try expect(snapshot.modifiedCount == 1, "真实仓库修改计数错误")
        try expect(snapshot.untrackedCount == 1, "真实仓库未跟踪计数错误")
        try expect(snapshot.conflictCount == 0, "真实仓库错误地产生冲突")
        try expect(snapshot.upstream == nil, "无 upstream 的仓库被错误识别")
        try expect(snapshot.recentCommits.first?.subject == "initial fixture", "Git 最近提交读取错误")

        let store = makeStore()
        try store.addGitRepository(snapshot: snapshot)
        try expect(store.enabledGitRepositories.count == 1, "Git 仓库没有加入关注")
        do {
            try store.addGitRepository(snapshot: snapshot)
            throw CheckFailure.failed("重复 Git 仓库被错误接受")
        } catch BetterStoreError.gitRepositoryAlreadyWatched {}

        let watchID = try require(store.data.gitRepositories.first?.id, "Git 关注记录缺少 ID")
        let failedRefresh = GitRefreshUpdate(
            repositoryID: watchID,
            attemptedAt: .now,
            snapshot: nil,
            errorMessage: "fixture refresh failed"
        )
        try store.applyGitRefreshes([failedRefresh])
        try expect(store.data.gitRepositories.first?.lastError == "fixture refresh failed", "Git 刷新错误没有保存")
        try expect(store.data.gitRepositories.first?.lastSnapshot == snapshot, "Git 刷新失败错误地清除了旧快照")
        try store.setGitRepositoryEnabled(watchID, enabled: false)
        try expect(store.enabledGitRepositories.isEmpty, "禁用 Git 仓库后仍进入启用列表")
        try store.removeGitRepository(watchID)
        try expect(store.data.gitRepositories.isEmpty, "移除 Git 关注失败")

        let limitStore = makeStore()
        for index in 0..<8 {
            var distinctSnapshot = snapshot
            distinctSnapshot.rootPath = fixtureRoot
                .appendingPathComponent("synthetic-\(index)")
                .path
            try limitStore.addGitRepository(snapshot: distinctSnapshot)
        }
        var ninthSnapshot = snapshot
        ninthSnapshot.rootPath = fixtureRoot.appendingPathComponent("synthetic-9").path
        do {
            try limitStore.addGitRepository(snapshot: ninthSnapshot)
            throw CheckFailure.failed("第 9 个 Git 仓库被错误接受")
        } catch BetterStoreError.gitRepositoryLimit {}

        let plainDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Better Non Git \(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: plainDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: plainDirectory) }
        do {
            _ = try GitContextService.inspectRepository(at: plainDirectory.path)
            throw CheckFailure.failed("非 Git 目录被错误接受")
        } catch GitContextError.notRepository(_) {}
    }

    private static func gitContextPrompt() throws {
        let snapshot = GitRepositorySnapshot(
            capturedAt: Date(timeIntervalSince1970: 500),
            rootPath: "/tmp/enabled repo",
            branch: "feature/context",
            headSHA: "1234567890abcdef1234567890abcdef12345678",
            upstream: "origin/feature/context",
            aheadCount: 2,
            behindCount: 1,
            stagedCount: 1,
            modifiedCount: 2,
            untrackedCount: 3,
            conflictCount: 0,
            recentCommits: [
                GitCommitSnapshot(
                    fullSHA: "1234567890abcdef1234567890abcdef12345678",
                    shortSHA: "1234567",
                    committedAt: Date(timeIntervalSince1970: 400),
                    subject: "wire Git context"
                )
            ]
        )
        let enabled = GitRepositoryWatch(
            rootPath: snapshot.rootPath,
            displayName: "enabled-repo",
            lastSnapshot: snapshot
        )
        let disabled = GitRepositoryWatch(
            rootPath: "/tmp/disabled repo",
            displayName: "disabled-repo",
            enabled: false,
            lastSnapshot: snapshot
        )
        let data = BetterData(gitRepositories: [enabled, disabled])
        let prompt = try CodexCoachService.conversationPrompt(
            for: data,
            message: "代码现在走到哪里？",
            fullContext: true,
            now: Date(timeIntervalSince1970: 600)
        )
        try expect(prompt.contains("enabled-repo"), "Coach 上下文遗漏启用 Git 仓库")
        try expect(prompt.contains("wire Git context"), "Coach 上下文遗漏最近提交")
        try expect(!prompt.contains("disabled-repo"), "Coach 上下文包含禁用 Git 仓库")
        try expect(prompt.contains("clean 不等于已发布"), "Coach Prompt 遗漏 Git 证据边界")

        var changed = data
        changed.gitRepositories[0].lastSnapshot?.modifiedCount = 9
        try expect(
            CodexCoachService.contextFingerprint(for: data) != CodexCoachService.contextFingerprint(for: changed),
            "Git 变化没有改变 Coach 上下文指纹"
        )
    }

    @MainActor
    private static func corruptDataPreservation() throws {
        let url = temporaryStorage()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let corrupt = Data("not-json".utf8)
        try corrupt.write(to: url)
        let store = AppStore(storageURL: url, reminders: NoopReminders())
        try expect(store.errorMessage != nil, "损坏数据没有显示错误")
        try expect(try Data(contentsOf: url) == corrupt, "损坏数据被静默覆盖")
    }

    private static func appIconCatalogContract() throws {
        let issues = AppIconCatalog.validationIssues()
        try expect(issues.isEmpty, issues.joined(separator: "；"))
        try expect(AppIconCatalog.all.count == 14, "图标候选数量不是十四个")
        try expect(
            AppIconCatalog.defaultOption.rendering == .nativeSquircle,
            "默认图标没有使用原生 squircle 资源"
        )
    }

    @MainActor
    private static func makeStore() -> AppStore {
        AppStore(storageURL: temporaryStorage(), reminders: NoopReminders())
    }

    private static func temporaryStorage() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("BetterChecks-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("better.json")
    }

    private static func expect(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
        guard try condition() else { throw CheckFailure.failed(message) }
    }

    private static func require<T>(_ value: T?, _ message: String) throws -> T {
        guard let value else { throw CheckFailure.failed(message) }
        return value
    }

    private static func runProcess(_ executable: String, _ arguments: [String]) throws {
        let errorPipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let detail = String(
                decoding: errorPipe.fileHandleForReading.readDataToEndOfFile(),
                as: UTF8.self
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            throw CheckFailure.failed(
                "fixture 命令失败：\(([executable] + arguments).joined(separator: " "))：\(detail)"
            )
        }
    }
}
