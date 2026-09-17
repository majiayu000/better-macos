import Combine
import Foundation

enum GitContextError: LocalizedError {
    case executableUnavailable
    case directoryUnavailable(String)
    case notRepository(String)
    case commandFailed(command: String, detail: String)
    case malformedOutput(String)

    var errorDescription: String? {
        switch self {
        case .executableUnavailable:
            "找不到系统 Git（/usr/bin/git）。"
        case let .directoryUnavailable(path):
            "仓库目录不可用：\(path)"
        case let .notRepository(path):
            "所选目录不在 Git 仓库中：\(path)"
        case let .commandFailed(command, detail):
            "Git 读取失败（\(command)）：\(detail)"
        case let .malformedOutput(detail):
            "Git 返回了无法识别的数据：\(detail)"
        }
    }
}

struct GitRefreshUpdate {
    let repositoryID: UUID
    let attemptedAt: Date
    let snapshot: GitRepositorySnapshot?
    let errorMessage: String?
}

struct GitWorkingTreeCounts: Equatable {
    var staged = 0
    var modified = 0
    var untracked = 0
    var conflicts = 0
}

@MainActor
final class GitContextService: ObservableObject {
    @Published private(set) var isRefreshing = false
    @Published private(set) var errorMessage: String?

    func inspect(path: String) async -> GitRepositorySnapshot? {
        guard !isRefreshing else { return nil }
        isRefreshing = true
        errorMessage = nil
        defer { isRefreshing = false }

        do {
            return try await Task.detached(priority: .userInitiated) {
                try Self.inspectRepository(at: path)
            }.value
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func refresh(_ repositories: [GitRepositoryWatch]) async -> [GitRefreshUpdate] {
        guard !isRefreshing else { return [] }
        let enabled = repositories.filter(\.enabled)
        guard !enabled.isEmpty else {
            errorMessage = nil
            return []
        }

        isRefreshing = true
        errorMessage = nil
        defer { isRefreshing = false }

        let updates = await Task.detached(priority: .utility) {
            enabled.map { repository in
                let attemptedAt = Date.now
                do {
                    let snapshot = try Self.inspectRepository(
                        at: repository.rootPath,
                        now: attemptedAt
                    )
                    return GitRefreshUpdate(
                        repositoryID: repository.id,
                        attemptedAt: attemptedAt,
                        snapshot: snapshot,
                        errorMessage: nil
                    )
                } catch {
                    return GitRefreshUpdate(
                        repositoryID: repository.id,
                        attemptedAt: attemptedAt,
                        snapshot: nil,
                        errorMessage: error.localizedDescription
                    )
                }
            }
        }.value

        let failures = updates.compactMap(\.errorMessage)
        if !failures.isEmpty {
            errorMessage = failures.joined(separator: "\n")
        }
        return updates
    }

    func clearError() {
        errorMessage = nil
    }

    nonisolated static func inspectRepository(
        at selectedPath: String,
        now: Date = .now
    ) throws -> GitRepositorySnapshot {
        let gitURL = URL(fileURLWithPath: "/usr/bin/git")
        guard FileManager.default.isExecutableFile(atPath: gitURL.path) else {
            throw GitContextError.executableUnavailable
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: selectedPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw GitContextError.directoryUnavailable(selectedPath)
        }

        let rootResult = try runGit(
            ["rev-parse", "--show-toplevel"],
            at: selectedPath,
            allowFailure: true
        )
        guard rootResult.exitCode == 0 else {
            throw GitContextError.notRepository(selectedPath)
        }
        let rawRoot = rootResult.trimmedStdout
        guard !rawRoot.isEmpty else {
            throw GitContextError.malformedOutput("仓库根路径为空")
        }
        let rootPath = URL(fileURLWithPath: rawRoot)
            .resolvingSymlinksInPath()
            .standardizedFileURL.path

        let headSHA = try requiredGitText(["rev-parse", "HEAD"], at: rootPath)
        let branchResult = try runGit(
            ["symbolic-ref", "--quiet", "--short", "HEAD"],
            at: rootPath,
            allowFailure: true
        )
        let branch: String
        if branchResult.exitCode == 0, !branchResult.trimmedStdout.isEmpty {
            branch = branchResult.trimmedStdout
        } else {
            let shortHead = try requiredGitText(["rev-parse", "--short", "HEAD"], at: rootPath)
            branch = "detached@\(shortHead)"
        }

        let status = try runGit(
            ["status", "--porcelain=v1", "-z", "--untracked-files=normal"],
            at: rootPath
        )
        let counts = try parseStatus(status.stdoutData)

        let upstreamResult = try runGit(
            ["rev-parse", "--abbrev-ref", "--symbolic-full-name", "@{upstream}"],
            at: rootPath,
            allowFailure: true
        )
        var upstream: String?
        var aheadCount: Int?
        var behindCount: Int?
        if upstreamResult.exitCode == 0, !upstreamResult.trimmedStdout.isEmpty {
            upstream = upstreamResult.trimmedStdout
            let countsText = try requiredGitText(
                ["rev-list", "--left-right", "--count", "HEAD...@{upstream}"],
                at: rootPath
            )
            let parts = countsText.split(whereSeparator: \Character.isWhitespace)
            guard parts.count == 2,
                  let ahead = Int(parts[0]),
                  let behind = Int(parts[1]) else {
                throw GitContextError.malformedOutput("ahead/behind 不是两个整数")
            }
            aheadCount = ahead
            behindCount = behind
        }

        let logResult = try runGit(
            ["log", "-5", "--format=%H%x1f%h%x1f%ct%x1f%s%x1e"],
            at: rootPath
        )
        let recentCommits = try parseCommits(logResult.stdoutData)

        return GitRepositorySnapshot(
            capturedAt: now,
            rootPath: rootPath,
            branch: branch,
            headSHA: headSHA,
            upstream: upstream,
            aheadCount: aheadCount,
            behindCount: behindCount,
            stagedCount: counts.staged,
            modifiedCount: counts.modified,
            untrackedCount: counts.untracked,
            conflictCount: counts.conflicts,
            recentCommits: recentCommits
        )
    }

    nonisolated static func parseStatus(_ data: Data) throws -> GitWorkingTreeCounts {
        let text = String(decoding: data, as: UTF8.self)
        let records = text.split(separator: "\u{0}", omittingEmptySubsequences: true)
        let conflictCodes: Set<String> = ["DD", "AU", "UD", "UA", "DU", "AA", "UU"]
        var counts = GitWorkingTreeCounts()
        var index = 0

        while index < records.count {
            let record = String(records[index])
            guard record.count >= 3 else {
                throw GitContextError.malformedOutput(String(record.prefix(120)))
            }
            let code = String(record.prefix(2))
            if code == "??" {
                counts.untracked += 1
                index += 1
                continue
            }
            if code == "!!" {
                index += 1
                continue
            }

            if conflictCodes.contains(code) {
                counts.conflicts += 1
            } else {
                let characters = Array(code)
                if characters[0] != " " { counts.staged += 1 }
                if characters[1] != " " { counts.modified += 1 }
            }

            let isRenameOrCopy = code.contains("R") || code.contains("C")
            index += isRenameOrCopy ? 2 : 1
        }
        return counts
    }

    nonisolated static func parseCommits(_ data: Data) throws -> [GitCommitSnapshot] {
        let text = String(decoding: data, as: UTF8.self)
        return try text
            .split(separator: "\u{1E}", omittingEmptySubsequences: false)
            .compactMap { rawRecord in
                let record = String(rawRecord).trimmingCharacters(in: .newlines)
                guard !record.isEmpty else { return nil }
                let fields = record.split(
                    separator: "\u{1F}",
                    maxSplits: 3,
                    omittingEmptySubsequences: false
                )
                guard fields.count == 4,
                      let timestamp = TimeInterval(fields[2]) else {
                    throw GitContextError.malformedOutput("提交记录字段不完整")
                }
                return GitCommitSnapshot(
                    fullSHA: String(fields[0]).trimmingCharacters(in: .whitespacesAndNewlines),
                    shortSHA: String(fields[1]),
                    committedAt: Date(timeIntervalSince1970: timestamp),
                    subject: String(fields[3]).trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
    }

    nonisolated private static func requiredGitText(
        _ arguments: [String],
        at path: String
    ) throws -> String {
        let result = try runGit(arguments, at: path)
        guard !result.trimmedStdout.isEmpty else {
            throw GitContextError.malformedOutput(arguments.joined(separator: " "))
        }
        return result.trimmedStdout
    }

    nonisolated private static func runGit(
        _ arguments: [String],
        at repositoryPath: String,
        allowFailure: Bool = false
    ) throws -> GitCommandResult {
        let fileManager = FileManager.default
        let temporaryDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("Better-Git-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: temporaryDirectory) }

        let outputURL = temporaryDirectory.appendingPathComponent("stdout")
        let errorURL = temporaryDirectory.appendingPathComponent("stderr")
        fileManager.createFile(atPath: outputURL.path, contents: nil)
        fileManager.createFile(atPath: errorURL.path, contents: nil)
        let outputHandle = try FileHandle(forWritingTo: outputURL)
        let errorHandle = try FileHandle(forWritingTo: errorURL)
        defer {
            try? outputHandle.close()
            try? errorHandle.close()
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", repositoryPath] + arguments
        process.standardOutput = outputHandle
        process.standardError = errorHandle
        var environment = ProcessInfo.processInfo.environment
        environment["GIT_OPTIONAL_LOCKS"] = "0"
        environment["GIT_TERMINAL_PROMPT"] = "0"
        process.environment = environment

        try process.run()
        process.waitUntilExit()
        try outputHandle.synchronize()
        try errorHandle.synchronize()

        let stdout = try Data(contentsOf: outputURL)
        let stderr = try Data(contentsOf: errorURL)
        let result = GitCommandResult(
            exitCode: process.terminationStatus,
            stdoutData: stdout,
            stderrData: stderr
        )
        if !allowFailure, result.exitCode != 0 {
            let detail = result.trimmedStderr.isEmpty
                ? "退出码 \(result.exitCode)"
                : String(result.trimmedStderr.suffix(1_000))
            throw GitContextError.commandFailed(
                command: arguments.joined(separator: " "),
                detail: detail
            )
        }
        return result
    }
}

private struct GitCommandResult {
    let exitCode: Int32
    let stdoutData: Data
    let stderrData: Data

    var trimmedStdout: String {
        String(decoding: stdoutData, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedStderr: String {
        String(decoding: stderrData, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
