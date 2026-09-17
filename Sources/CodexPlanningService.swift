import Combine
import Foundation

enum CodexPlannerError: LocalizedError {
    case noActiveBets
    case finishCurrentFocusFirst
    case executableNotFound
    case executionFailed(String)
    case emptyOutput
    case invalidSuggestion(String)

    var errorDescription: String? {
        switch self {
        case .noActiveBets:
            "请先创建至少一条 7 天或 14 天押注。"
        case .finishCurrentFocusFirst:
            "请先完成今天的焦点并记录实际情况，再让 Codex 安排下一天。"
        case .executableNotFound:
            "找不到 Codex CLI。Better 会检查 /opt/homebrew/bin/codex 和 /usr/local/bin/codex。"
        case let .executionFailed(detail):
            "Codex 规划失败：\(detail)"
        case .emptyOutput:
            "Codex 没有返回规划结果。"
        case let .invalidSuggestion(detail):
            "Codex 返回的建议无法采用：\(detail)"
        }
    }
}

@MainActor
final class CodexPlanningService: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var suggestion: CodexFocusSuggestion?
    @Published private(set) var errorMessage: String?

    func generate(from data: BetterData) async {
        guard !isRunning else { return }
        isRunning = true
        suggestion = nil
        errorMessage = nil
        defer { isRunning = false }

        do {
            let result = try await Task.detached(priority: .userInitiated) {
                try Self.runCodex(with: data)
            }.value
            suggestion = result
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearSuggestion() {
        suggestion = nil
        errorMessage = nil
    }

    nonisolated static func planningPrompt(for data: BetterData, now: Date = .now) throws -> String {
        let activeBets = data.bets.filter { $0.status == .active }
        guard !activeBets.isEmpty else { throw CodexPlannerError.noActiveBets }
        guard data.currentFocus == nil else { throw CodexPlannerError.finishCurrentFocusFirst }

        let calendar = Calendar.current
        let context = PlanningContext(
            planningDate: now,
            activeBets: activeBets.map { bet in
                let elapsed = max(calendar.dateComponents([.day], from: bet.createdAt, to: now).day ?? 0, 0)
                return PlanningBet(
                    id: bet.id,
                    title: bet.title,
                    horizonDays: bet.resolvedHorizonDays,
                    daysElapsed: elapsed,
                    daysRemaining: max(bet.resolvedHorizonDays - elapsed, 0),
                    outcome: bet.sixWeekOutcome,
                    evidenceGoal: bet.evidenceGoal ?? bet.sixWeekOutcome,
                    riskiestAssumption: bet.riskiestAssumption
                )
            },
            recentEvidence: Array(data.evidence.prefix(14)).map {
                PlanningEvidence(
                    betID: $0.betID,
                    action: $0.action,
                    expectedEvidence: $0.expectedEvidence,
                    actualEvidence: $0.actualEvidence,
                    unresolvedQuestion: $0.unresolvedQuestion,
                    evidenceKind: $0.kind,
                    recordedAt: $0.recordedAt,
                    adaptationNote: $0.adaptationNote ?? "",
                    energyLevel: $0.energyLevel
                )
            },
            parkedIdeas: data.parkedIdeas.prefix(20).map(\.title)
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let contextJSON = String(decoding: try encoder.encode(context), as: UTF8.self)

        return """
        你是 Better 的滚动日计划器。下面是用户主动提供的有限上下文。

        你的任务是只选择下一次要做的一件事。7 天或 14 天押注中的结果和证据门槛相对稳定，但每日行动必须根据最近实际证据、阻碍、未知问题和精力状态滚动变化。

        必须遵守：
        1. 只能从 active_bets 中选择一个 bet_id，不能创造新项目或新押注。
        2. 只规划下一次专注，不生成一周任务表。
        3. 优先验证最危险的假设，优先取得真实用户或业务行为证据。
        4. 如果最近没有得到预期证据，缩小行动或改变验证方法，不要简单重复。
        5. 如果出现阻碍或精力较低，减小范围，但保留证据价值。
        6. 行动必须能在 25、50 或 90 分钟之一完成；默认选 50。
        7. rationale 要解释建议如何响应最近的实际情况，并指出它放弃了什么。
        8. 不调用工具，不修改文件，不输出 JSON 以外的内容。

        Better 上下文：
        \(contextJSON)
        """
    }

    nonisolated static func validate(_ suggestion: CodexFocusSuggestion, against data: BetterData) throws {
        guard data.bets.contains(where: { $0.id == suggestion.betID && $0.status == .active }) else {
            throw CodexPlannerError.invalidSuggestion("选择了不存在或已停放的押注")
        }
        guard !suggestion.action.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CodexPlannerError.invalidSuggestion("行动为空")
        }
        guard !suggestion.expectedEvidence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CodexPlannerError.invalidSuggestion("预期证据为空")
        }
        guard [25, 50, 90].contains(suggestion.durationMinutes) else {
            throw CodexPlannerError.invalidSuggestion("时长必须是 25、50 或 90 分钟")
        }
        guard !suggestion.rationale.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CodexPlannerError.invalidSuggestion("理由为空")
        }
    }

    nonisolated private static func runCodex(with data: BetterData) throws -> CodexFocusSuggestion {
        let prompt = try planningPrompt(for: data)
        let executable = try codexExecutable()
        let fileManager = FileManager.default
        let temporaryDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("Better-Codex-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryDirectory) }

        let schemaURL = temporaryDirectory.appendingPathComponent("focus-schema.json")
        let outputURL = temporaryDirectory.appendingPathComponent("focus.json")
        let errorURL = temporaryDirectory.appendingPathComponent("codex.stderr.log")
        try Data(outputSchema.utf8).write(to: schemaURL, options: .atomic)
        fileManager.createFile(atPath: errorURL.path, contents: nil)

        let errorHandle = try FileHandle(forWritingTo: errorURL)
        defer { try? errorHandle.close() }

        let workingDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Better", isDirectory: true)
        try fileManager.createDirectory(at: workingDirectory, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = executable
        process.currentDirectoryURL = workingDirectory
        process.arguments = [
            "exec",
            "--sandbox", "read-only",
            "--ephemeral",
            "--ignore-rules",
            "--skip-git-repo-check",
            "--color", "never",
            "--output-schema", schemaURL.path,
            "--output-last-message", outputURL.path,
            prompt
        ]
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        process.environment = environment
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errorHandle

        try process.run()
        process.waitUntilExit()
        try? errorHandle.synchronize()

        guard process.terminationStatus == 0 else {
            let detail = (try? String(contentsOf: errorURL, encoding: .utf8))?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "退出码 \(process.terminationStatus)"
            throw CodexPlannerError.executionFailed(String(detail.suffix(1_500)))
        }
        guard fileManager.fileExists(atPath: outputURL.path) else {
            throw CodexPlannerError.emptyOutput
        }
        let output = try Data(contentsOf: outputURL)
        guard !output.isEmpty else { throw CodexPlannerError.emptyOutput }
        let suggestion = try JSONDecoder().decode(CodexFocusSuggestion.self, from: output)
        try validate(suggestion, against: data)
        return suggestion
    }

    nonisolated static func codexExecutable() throws -> URL {
        let environment = ProcessInfo.processInfo.environment
        let configured = environment["BETTER_CODEX_PATH"].map(URL.init(fileURLWithPath:))
        let candidates = [
            configured,
            URL(fileURLWithPath: "/opt/homebrew/bin/codex"),
            URL(fileURLWithPath: "/usr/local/bin/codex")
        ].compactMap { $0 }
        guard let executable = candidates.first(where: {
            FileManager.default.isExecutableFile(atPath: $0.path)
        }) else {
            throw CodexPlannerError.executableNotFound
        }
        return executable
    }

    nonisolated static let outputSchema = """
    {
      "type": "object",
      "properties": {
        "bet_id": { "type": "string" },
        "action": { "type": "string" },
        "expected_evidence": { "type": "string" },
        "evidence_kind": {
          "type": "string",
          "enum": ["problem", "attempt", "returnUse", "commitment", "payment", "deliverable", "reproducibleLearning"]
        },
        "duration_minutes": { "type": "integer", "enum": [25, 50, 90] },
        "rationale": { "type": "string" }
      },
      "required": ["bet_id", "action", "expected_evidence", "evidence_kind", "duration_minutes", "rationale"],
      "additionalProperties": false
    }
    """
}

private struct PlanningContext: Encodable {
    let planningDate: Date
    let activeBets: [PlanningBet]
    let recentEvidence: [PlanningEvidence]
    let parkedIdeas: [String]

    enum CodingKeys: String, CodingKey {
        case planningDate = "planning_date"
        case activeBets = "active_bets"
        case recentEvidence = "recent_evidence"
        case parkedIdeas = "parked_ideas_do_not_start"
    }
}

private struct PlanningBet: Encodable {
    let id: UUID
    let title: String
    let horizonDays: Int
    let daysElapsed: Int
    let daysRemaining: Int
    let outcome: String
    let evidenceGoal: String
    let riskiestAssumption: String

    enum CodingKeys: String, CodingKey {
        case id, title, outcome
        case horizonDays = "horizon_days"
        case daysElapsed = "days_elapsed"
        case daysRemaining = "days_remaining"
        case evidenceGoal = "evidence_goal"
        case riskiestAssumption = "riskiest_assumption"
    }
}

private struct PlanningEvidence: Encodable {
    let betID: UUID
    let action: String
    let expectedEvidence: String
    let actualEvidence: String
    let unresolvedQuestion: String
    let evidenceKind: EvidenceKind
    let recordedAt: Date
    let adaptationNote: String
    let energyLevel: Int?

    enum CodingKeys: String, CodingKey {
        case action
        case betID = "bet_id"
        case expectedEvidence = "expected_evidence"
        case actualEvidence = "actual_evidence"
        case unresolvedQuestion = "unresolved_question"
        case evidenceKind = "evidence_kind"
        case recordedAt = "recorded_at"
        case adaptationNote = "adaptation_note"
        case energyLevel = "energy_level"
    }
}
