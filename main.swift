import Foundation
import InstructionDrift

// Usage: drift-audit <path-to-git-checkout>
// Audits every AGENTS.md / CLAUDE.md in the checkout and prints one JSON object.

struct Git {
    let repo: String

    func run(_ arguments: [String]) -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "-C", repo] + arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return (-1, "") }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }
}

final class GitHistory: ChangeHistory {
    let git: Git
    private var countCache: [String: Int] = [:]

    init(git: Git) { self.git = git }

    func commits(touching path: String, after date: Date) -> Int {
        let since = Int(date.timeIntervalSince1970) + 1
        let key = "\(path)@\(since)"
        if let cached = countCache[key] { return cached }
        let out = git.run(["rev-list", "--count", "--since=\(since)", "HEAD", "--", path]).output
        let count = Int(out.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        countCache[key] = count
        return count
    }

    func lastSeen(_ reference: String) -> Date? {
        let tail = reference.hasPrefix("./") ? String(reference.dropFirst(2)) : reference
        guard !tail.hasPrefix("..") else { return nil }
        let specs = [":(glob)**/\(tail)", ":(glob)**/\(tail)/**", ":(glob)\(tail)", ":(glob)\(tail)/**"]
        let out = git.run(["log", "--all", "-1", "--format=%ct", "--"] + specs).output
        guard let seconds = TimeInterval(out.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    func isIgnored(_ reference: String) -> Bool {
        let path = reference.hasPrefix("./") ? String(reference.dropFirst(2)) : reference
        guard !path.hasPrefix("..") else { return false }
        return git.run(["check-ignore", "-q", "--no-index", path]).status == 0
            || git.run(["check-ignore", "-q", "--no-index", path + "/x"]).status == 0
    }

    /// git blame: last-edit date for every line of `file` at HEAD.
    func lineDates(_ file: String) -> [Int: Date] {
        let out = git.run(["blame", "--line-porcelain", "HEAD", "--", file]).output
        var dates: [Int: Date] = [:]
        var current: Date?
        var line = 0
        for row in out.split(separator: "\n", omittingEmptySubsequences: false) {
            if row.hasPrefix("committer-time "), let seconds = TimeInterval(row.dropFirst(15)) {
                current = Date(timeIntervalSince1970: seconds)
            } else if row.hasPrefix("\t") {
                line += 1
                dates[line] = current
            }
        }
        return dates
    }
}

let arguments = CommandLine.arguments
guard arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: drift-audit <git-checkout>\n".utf8))
    exit(2)
}
let repoPath = arguments[1]
let git = Git(repo: repoPath)
let tracked = git.run(["ls-files"]).output.split(separator: "\n").map(String.init)
let snapshot = RepoSnapshot(files: tracked)
let history = GitHistory(git: git)
let auditor = DriftAuditor(snapshot: snapshot, history: history)
let head = git.run(["rev-parse", "HEAD"]).output.trimmingCharacters(in: .whitespacesAndNewlines)

let iso = ISO8601DateFormatter()
var seenContents = Set<String>()
var files: [[String: Any]] = []

let instructionFiles = tracked.filter { path in
    let name = (path.split(separator: "/").last.map(String.init) ?? path).lowercased()
    return name == "agents.md" || name == "claude.md"
}.sorted()

for file in instructionFiles {
    let url = URL(fileURLWithPath: repoPath).appendingPathComponent(file)
    // Skip symlinks and byte-identical copies (CLAUDE.md that mirrors AGENTS.md).
    if (try? FileManager.default.destinationOfSymbolicLink(atPath: url.path)) != nil { continue }
    guard let text = try? String(contentsOf: url, encoding: .utf8), seenContents.insert(text).inserted else { continue }
    let dates = history.lineDates(file)
    let audit = auditor.audit(path: file, markdown: text) { dates[$0] }
    let references: [[String: Any]] = audit.findings.map { finding in
        var row: [String: Any] = ["text": finding.reference.text, "line": finding.reference.line]
        if let written = dates[finding.reference.line] { row["lineWritten"] = iso.string(from: written) }
        switch finding.status {
        case .live(let path, let commits):
            row["status"] = "live"; row["target"] = path; row["commitsSinceWritten"] = commits
        case .removed(let lastSeen):
            row["status"] = "removed"; row["lastSeen"] = iso.string(from: lastSeen)
        case .ignored:
            row["status"] = "ignored"
        case .unresolved:
            row["status"] = "unresolved"
        }
        return row
    }
    let lastEdit = git.run(["log", "-1", "--format=%cI", "--", file]).output
        .trimmingCharacters(in: .whitespacesAndNewlines)
    files.append(["path": file, "lastEdited": lastEdit, "references": references])
}

let result: [String: Any] = ["head": head, "files": files]
let json = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
FileHandle.standardOutput.write(json)
FileHandle.standardOutput.write(Data("\n".utf8))
