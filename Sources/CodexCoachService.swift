import Combine
import Foundation

enum CodexCoachError: LocalizedError {
    case emptyMessage
    case executionFailed(String)
    case invalidEventStream(String)
    case missingThreadID
    case emptyReply
    case resumeAndRebuildFailed(resume: String, rebuild: String)

    var errorDescription: String? {
        switch self {
        case .emptyMessage:
            "请先写下你想和 Better Coach 讨论的内容。"
        case let .executionFailed(detail):
            "Better Coach 运行失败：\(detail)"
        case let .invalidEventStream(detail):
            "Codex 返回了无法识别的会话事件：\(detail)"
        case .missingThreadID:
            "Codex 创建了回复，但没有返回可恢复的线程 ID。"
        case .emptyReply:
            "Better Coach 没有返回可显示的回复。"
        case let .resumeAndRebuildFailed(resume, rebuild):
            "原会话恢复失败：\(resume)\n重新建立会话也失败：\(rebuild)"
        }
    }
}

struct CoachReplyResult: Equatable {
    let threadID: String
    let assistantText: String
    let contextFingerprint: String
    let rebuiltThread: Bool
}

struct CoachSuggestionResult: Equatable {
    let threadID: String
    let suggestion: CodexFocusSuggestion
    let assistantText: String
    let contextFingerprint: String
    let rebuiltThread: Bool
}

@MainActor
final class CodexCoachService: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var statusMessage: String?

    func send(message: String, from data: BetterData) async -> CoachReplyResult? {
        guard !isRunning else { return nil }
        let cleanMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanMessage.isEmpty else {
            errorMessage = CodexCoachError.emptyMessage.localizedDescription
            return nil
        }

        beginRun()
        defer { isRunning = false }

        do {
            let result = try await Task.detached(priority: .userInitiated) {
                try Self.runConversation(message: cleanMessage, data: data)
            }.value
            if result.rebuiltThread {
                statusMessage = "原对话无法恢复，Better 已带着本地上下文重新建立连接。"
            }
            return result
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func generateSuggestion(from data: BetterData) async -> CoachSuggestionResult? {
        guard !isRunning else { return nil }
        beginRun()
        defer { isRunning = false }

        do {
            let result = try await Task.detached(priority: .userInitiated) {
                try Self.runSuggestion(data: data)
            }.value
            if result.rebuiltThread {
                statusMessage = "原对话无法恢复，Better 已重建连接并重新生成提案。"
            }
            return result
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func clearMessages() {
        errorMessage = nil
        statusMessage = nil
    }

    nonisolated static func conversationPrompt(
        for data: BetterData,
        message: String,
        fullContext: Bool,
        now: Date = .now
    ) throws -> String {
        let context = try contextJSON(for: data, fullContext: fullContext, now: now)
        let scope = fullContext ? "完整恢复上下文" : "自上次对话后的上下文变化"

        return """
        你是 Better Coach。你的职责是帮助用户根据真实证据收拢注意力，而不是扩展任务清单。

        对话规则：
        1. 先回应用户真正的问题；信息不足时最多追问一个最关键的问题。
        2. 只能围绕当前 7 天或 14 天押注、周期复盘、最近证据、阻碍、未知问题和精力状态讨论。
        3. 不创造新项目，不把广泛想法展开成 Todo 列表，不假装存在客户或业务指标。
        4. 你可以提出方向或比较取舍，但不要声称已经修改 Better 数据。
        5. 只有用户明确请求下一步提案时，才收敛为一个 25、50 或 90 分钟行动。
        6. 不调用工具，不修改文件。用简洁、自然的中文回复。
        7. Git 快照只表示本地实现活动：clean 不等于已发布，commit 不等于用户价值，ahead/behind 可能因未 fetch 而过期。
        8. 不把提交数量、分支数量或代码改动冒充为用户尝试、主动返回、承诺或付费证据。

        \(scope)：
        \(context)

        用户这次说：
        \(message)
        """
    }

    nonisolated static func contextFingerprint(for data: BetterData) -> String {
        let betParts = data.bets
            .sorted { $0.id.uuidString < $1.id.uuidString }
            .map { "\($0.id.uuidString):\($0.status.rawValue):\($0.resolvedHorizonDays)" }
        let focusPart = data.currentFocus.map {
            "focus:\($0.id.uuidString):\($0.isRunning ? "running" : "planned")"
        } ?? "focus:none"
        let evidenceParts = data.evidence.prefix(14).map { $0.id.uuidString }
        let reviewParts = data.cycleReviews.prefix(8).map { $0.id.uuidString }
        let gitParts = data.gitRepositories
            .filter(\.enabled)
            .map { repository in
                let snapshot = repository.lastSnapshot
                return [
                    repository.id.uuidString,
                    snapshot?.headSHA ?? "no-head",
                    String(snapshot?.capturedAt.timeIntervalSince1970 ?? 0),
                    String(snapshot?.stagedCount ?? 0),
                    String(snapshot?.modifiedCount ?? 0),
                    String(snapshot?.untrackedCount ?? 0),
                    String(snapshot?.conflictCount ?? 0),
                    repository.lastError ?? "ok"
                ].joined(separator: ":")
            }
        let pendingPart = data.pendingReviewEvidenceID?.uuidString ?? "pending:none"
        return (betParts + [focusPart] + evidenceParts + reviewParts + gitParts + [pendingPart])
            .joined(separator: "|")
    }

    nonisolated static func assistantSummary(for suggestion: CodexFocusSuggestion) -> String {
        """
        我建议下一步只做：\(suggestion.action)
        预期证据：\(suggestion.expectedEvidence)
        \(suggestion.rationale)
        """
    }

    private func beginRun() {
        isRunning = true
        errorMessage = nil
        statusMessage = nil
    }

    nonisolated private static func runConversation(
        message: String,
        data: BetterData
    ) throws -> CoachReplyResult {
        let fingerprint = contextFingerprint(for: data)

        if let threadID = data.coach.threadID {
            do {
                let prompt = try conversationPrompt(
                    for: data,
                    message: message,
                    fullContext: false
                )
                let output = try runCLI(prompt: prompt, resuming: threadID, outputSchema: nil)
                return CoachReplyResult(
                    threadID: threadID,
                    assistantText: output.assistantText,
                    contextFingerprint: fingerprint,
                    rebuiltThread: false
                )
            } catch {
                let resumeError = error.localizedDescription
                do {
                    let prompt = try conversationPrompt(
                        for: data,
                        message: message,
                        fullContext: true
                    )
                    let output = try runCLI(prompt: prompt, resuming: nil, outputSchema: nil)
                    guard let rebuiltThreadID = output.threadID else {
                        throw CodexCoachError.missingThreadID
                    }
                    return CoachReplyResult(
                        threadID: rebuiltThreadID,
                        assistantText: output.assistantText,
                        contextFingerprint: fingerprint,
                        rebuiltThread: true
                    )
                } catch {
                    throw CodexCoachError.resumeAndRebuildFailed(
                        resume: resumeError,
                        rebuild: error.localizedDescription
                    )
                }
            }
        }

        let prompt = try conversationPrompt(for: data, message: message, fullContext: true)
        let output = try runCLI(prompt: prompt, resuming: nil, outputSchema: nil)
        guard let threadID = output.threadID else { throw CodexCoachError.missingThreadID }
        return CoachReplyResult(
            threadID: threadID,
            assistantText: output.assistantText,
            contextFingerprint: fingerprint,
            rebuiltThread: false
        )
    }

    nonisolated private static func runSuggestion(data: BetterData) throws -> CoachSuggestionResult {
        let request = "请根据我们已经讨论的情况，生成下一次唯一行动提案。"
        let planningPrompt = try CodexPlanningService.planningPrompt(for: data)
        let proposalContext = try conversationPrompt(
            for: data,
            message: request,
            fullContext: data.coach.threadID == nil
        )
        let fingerprint = contextFingerprint(for: data)
        let prompt = """
        \(proposalContext)

        \(planningPrompt)

        这是 Better Coach 对话中的结构化提案步骤。结合当前线程里用户补充的信息，只返回符合 Schema 的 JSON。
        """

        if let threadID = data.coach.threadID {
            let output: CLIOutput
            do {
                output = try runCLI(
                    prompt: prompt,
                    resuming: threadID,
                    outputSchema: CodexPlanningService.outputSchema
                )
            } catch {
                let resumeError = error.localizedDescription
                do {
                    let recoveryContext = try conversationPrompt(
                        for: data,
                        message: request,
                        fullContext: true
                    )
                    let recoveryPrompt = """
                    \(recoveryContext)

                    \(planningPrompt)
                    只返回符合 Schema 的 JSON。
                    """
                    let output = try runCLI(
                        prompt: recoveryPrompt,
                        resuming: nil,
                        outputSchema: CodexPlanningService.outputSchema
                    )
                    guard let rebuiltThreadID = output.threadID else {
                        throw CodexCoachError.missingThreadID
                    }
                    let suggestion = try decodeSuggestion(from: output.assistantText, data: data)
                    return CoachSuggestionResult(
                        threadID: rebuiltThreadID,
                        suggestion: suggestion,
                        assistantText: assistantSummary(for: suggestion),
                        contextFingerprint: fingerprint,
                        rebuiltThread: true
                    )
                } catch {
                    throw CodexCoachError.resumeAndRebuildFailed(
                        resume: resumeError,
                        rebuild: error.localizedDescription
                    )
                }
            }

            let suggestion = try decodeSuggestion(from: output.assistantText, data: data)
            return CoachSuggestionResult(
                threadID: threadID,
                suggestion: suggestion,
                assistantText: assistantSummary(for: suggestion),
                contextFingerprint: fingerprint,
                rebuiltThread: false
            )
        }

        let initialContext = try conversationPrompt(
            for: data,
            message: request,
            fullContext: true
        )
        let initialPrompt = """
        \(initialContext)

        \(planningPrompt)
        只返回符合 Schema 的 JSON。
        """
        let output = try runCLI(
            prompt: initialPrompt,
            resuming: nil,
            outputSchema: CodexPlanningService.outputSchema
        )
        guard let threadID = output.threadID else { throw CodexCoachError.missingThreadID }
        let suggestion = try decodeSuggestion(from: output.assistantText, data: data)
        return CoachSuggestionResult(
            threadID: threadID,
            suggestion: suggestion,
            assistantText: assistantSummary(for: suggestion),
            contextFingerprint: fingerprint,
            rebuiltThread: false
        )
    }

    nonisolated private static func decodeSuggestion(
        from text: String,
        data: BetterData
    ) throws -> CodexFocusSuggestion {
        guard let encoded = text.data(using: .utf8) else {
            throw CodexCoachError.invalidEventStream("提案不是 UTF-8 文本")
        }
        let suggestion = try JSONDecoder().decode(CodexFocusSuggestion.self, from: encoded)
        try CodexPlanningService.validate(suggestion, against: data)
        return suggestion
    }

    nonisolated private static func contextJSON(
        for data: BetterData,
        fullContext: Bool,
        now: Date
    ) throws -> String {
        let evidence: [EvidenceRecord]
        if fullContext || data.coach.lastUsedAt == nil {
            evidence = Array(data.evidence.prefix(14))
        } else if let lastUsedAt = data.coach.lastUsedAt {
            evidence = Array(data.evidence.filter { $0.recordedAt > lastUsedAt }.prefix(14))
        } else {
            evidence = []
        }

        let packet = CoachContextPacket(
            generatedAt: now,
            scope: fullContext ? "full" : "delta",
            activeBets: data.bets.filter { $0.status == .active },
            currentFocus: data.currentFocus,
            recentEvidence: evidence,
            pendingReviewEvidenceID: data.pendingReviewEvidenceID,
            recentCycleReviews: fullContext
                ? Array(data.cycleReviews.prefix(8))
                : Array(data.cycleReviews.filter { review in
                    guard let lastUsedAt = data.coach.lastUsedAt else { return true }
                    return review.reviewedAt > lastUsedAt
                }.prefix(8)),
            gitRepositories: data.gitRepositories
                .filter(\.enabled)
                .compactMap { repository in
                    guard let snapshot = repository.lastSnapshot else { return nil }
                    return GitCoachContext(
                        displayName: repository.displayName,
                        rootPath: repository.rootPath,
                        snapshot: snapshot
                    )
                },
            parkedIdeas: fullContext ? data.parkedIdeas.prefix(20).map(\.title) : [],
            recentConversation: fullContext ? Array(data.coach.messages.suffix(12)) : []
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return String(decoding: try encoder.encode(packet), as: UTF8.self)
    }

    nonisolated private static func runCLI(
        prompt: String,
        resuming threadID: String?,
        outputSchema: String?
    ) throws -> CLIOutput {
        let executable = try CodexPlanningService.codexExecutable()
        let fileManager = FileManager.default
        let temporaryDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("Better-Coach-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryDirectory) }

        let outputURL = temporaryDirectory.appendingPathComponent("codex.jsonl")
        let errorURL = temporaryDirectory.appendingPathComponent("codex.stderr.log")
        fileManager.createFile(atPath: outputURL.path, contents: nil)
        fileManager.createFile(atPath: errorURL.path, contents: nil)

        var arguments: [String]
        if threadID != nil {
            arguments = [
                "exec", "resume",
                "--ignore-rules",
                "--skip-git-repo-check",
                "--json"
            ]
        } else {
            arguments = [
                "exec",
                "--sandbox", "read-only",
                "--ignore-rules",
                "--skip-git-repo-check",
                "--json"
            ]
        }

        if let outputSchema {
            let schemaURL = temporaryDirectory.appendingPathComponent("output-schema.json")
            try Data(outputSchema.utf8).write(to: schemaURL, options: .atomic)
            arguments.append(contentsOf: ["--output-schema", schemaURL.path])
        }
        if let threadID {
            arguments.append(threadID)
        }
        arguments.append(prompt)

        let outputHandle = try FileHandle(forWritingTo: outputURL)
        let errorHandle = try FileHandle(forWritingTo: errorURL)
        defer {
            try? outputHandle.close()
            try? errorHandle.close()
        }

        let workingDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Better", isDirectory: true)
        try fileManager.createDirectory(at: workingDirectory, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = executable
        process.currentDirectoryURL = workingDirectory
        process.arguments = arguments
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        process.environment = environment
        process.standardOutput = outputHandle
        process.standardError = errorHandle

        try process.run()
        process.waitUntilExit()
        try outputHandle.synchronize()
        try errorHandle.synchronize()

        let outputData = try Data(contentsOf: outputURL)
        let stderr = (try? String(contentsOf: errorURL, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard process.terminationStatus == 0 else {
            let detail = stderr.isEmpty ? "退出码 \(process.terminationStatus)" : String(stderr.suffix(1_500))
            throw CodexCoachError.executionFailed(detail)
        }

        return try parseJSONL(outputData, resumedThreadID: threadID)
    }

    nonisolated static func parseJSONL(
        _ data: Data,
        resumedThreadID: String?
    ) throws -> CLIOutput {
        guard let text = String(data: data, encoding: .utf8) else {
            throw CodexCoachError.invalidEventStream("输出不是 UTF-8")
        }

        var observedThreadID: String?
        var assistantMessages: [String] = []
        var eventErrors: [String] = []

        for line in text.split(whereSeparator: \Character.isNewline) {
            guard let lineData = String(line).data(using: .utf8),
                  let event = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let type = event["type"] as? String else {
                throw CodexCoachError.invalidEventStream(String(line.prefix(300)))
            }

            if type == "thread.started", let threadID = event["thread_id"] as? String {
                observedThreadID = threadID
            } else if type == "item.completed",
                      let item = event["item"] as? [String: Any],
                      item["type"] as? String == "agent_message",
                      let message = item["text"] as? String,
                      !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                assistantMessages.append(message)
            } else if type == "error", let message = event["message"] as? String {
                eventErrors.append(message)
            }
        }

        guard let assistantText = assistantMessages.last else {
            if let eventError = eventErrors.last {
                throw CodexCoachError.executionFailed(eventError)
            }
            throw CodexCoachError.emptyReply
        }
        return CLIOutput(
            threadID: observedThreadID ?? resumedThreadID,
            assistantText: assistantText
        )
    }
}

private struct CoachContextPacket: Encodable {
    let generatedAt: Date
    let scope: String
    let activeBets: [Bet]
    let currentFocus: FocusPlan?
    let recentEvidence: [EvidenceRecord]
    let pendingReviewEvidenceID: UUID?
    let recentCycleReviews: [BetCycleReview]
    let gitRepositories: [GitCoachContext]
    let parkedIdeas: [String]
    let recentConversation: [CoachMessage]
}

private struct GitCoachContext: Encodable {
    let displayName: String
    let rootPath: String
    let snapshot: GitRepositorySnapshot
}

struct CLIOutput {
    let threadID: String?
    let assistantText: String
}
