import Foundation

/// What the auditor needs to know about a repository's past. The demo app uses
/// `RecordedHistory`; the `drift-audit` CLI answers the same questions with git.
public protocol ChangeHistory {
    /// Number of commits that touched `path` (a file, or anything under a directory)
    /// strictly after `date`.
    func commits(touching path: String, after date: Date) -> Int
    /// The last commit date at which something matching `reference` (as a full path or
    /// a path tail) was tracked, or nil if it never was.
    func lastSeen(_ reference: String) -> Date?
    /// True when the path is git-ignored: local or generated output, not drift.
    func isIgnored(_ reference: String) -> Bool
}

/// How one reference in an instruction file relates to the code today.
public enum AnchorStatus: Equatable, Sendable {
    /// The path exists. `commitsSinceWritten` counts commits to it after the line
    /// that names it was last edited.
    case live(path: String, commitsSinceWritten: Int)
    /// The path was tracked once and is gone: the instruction is now false.
    case removed(lastSeen: Date)
    /// Ignored by git: build output or machine-local files the line describes.
    case ignored
    /// Never tracked: placeholders, prose like `async/await`, package slugs.
    case unresolved
}

public struct AnchorFinding: Equatable, Sendable {
    public let reference: Reference
    public let status: AnchorStatus
}

public struct InstructionAudit: Equatable, Sendable {
    public let file: String
    public let findings: [AnchorFinding]

    public var live: [AnchorFinding] {
        findings.filter { if case .live = $0.status { return true } else { return false } }
    }
    /// Live anchors whose code has changed since the sentence about them was written.
    public var changedSinceWritten: [AnchorFinding] {
        findings.filter {
            if case .live(_, let commits) = $0.status { return commits > 0 } else { return false }
        }
    }
    public var removed: [AnchorFinding] {
        findings.filter { if case .removed = $0.status { return true } else { return false } }
    }
}

public struct DriftAuditor {
    public let snapshot: RepoSnapshot
    public let history: ChangeHistory

    public init(snapshot: RepoSnapshot, history: ChangeHistory) {
        self.snapshot = snapshot
        self.history = history
    }

    /// Audits one instruction file.
    /// - Parameters:
    ///   - path: repo path of the instruction file, e.g. `ios/AGENTS.md`.
    ///   - markdown: its contents.
    ///   - lineWrittenAt: when a 1-based line was last edited (git blame). Lines with
    ///     no date are still checked for existence but not for drift.
    public func audit(path: String, markdown: String, lineWrittenAt: (Int) -> Date?) -> InstructionAudit {
        let base = path.split(separator: "/").dropLast().joined(separator: "/")
        let findings = ReferenceExtractor.references(in: markdown).map { reference -> AnchorFinding in
            AnchorFinding(reference: reference, status: status(of: reference, base: base, lineWrittenAt: lineWrittenAt))
        }
        return InstructionAudit(file: path, findings: findings)
    }

    private func status(of reference: Reference, base: String, lineWrittenAt: (Int) -> Date?) -> AnchorStatus {
        if let target = snapshot.resolve(reference.text, relativeTo: base) {
            let commits = lineWrittenAt(reference.line).map { history.commits(touching: target, after: $0) } ?? 0
            return .live(path: target, commitsSinceWritten: commits)
        }
        if history.isIgnored(reference.text) { return .ignored }
        if let seen = history.lastSeen(reference.text) { return .removed(lastSeen: seen) }
        return .unresolved
    }
}

/// An in-memory history: a list of (path, date) change events plus ignore rules.
public struct RecordedHistory: ChangeHistory, Sendable {
    public struct Change: Sendable {
        public let path: String
        public let date: Date
        public init(path: String, date: Date) { self.path = path; self.date = date }
    }

    public let changes: [Change]
    public let ignoredPrefixes: [String]

    public init(changes: [Change], ignoredPrefixes: [String] = []) {
        self.changes = changes
        self.ignoredPrefixes = ignoredPrefixes
    }

    public func commits(touching path: String, after date: Date) -> Int {
        changes.filter { PathMath.path($0.path, isWithin: path) && $0.date > date }.count
    }

    public func lastSeen(_ reference: String) -> Date? {
        guard let tail = PathMath.normalize(reference.hasPrefix("./") ? String(reference.dropFirst(2)) : reference) else {
            return nil
        }
        return changes
            .filter { change in
                PathMath.path(change.path, isWithin: tail) || change.path.hasSuffix("/" + tail)
                    || change.path.contains("/" + tail + "/")
            }
            .map(\.date)
            .max()
    }

    public func isIgnored(_ reference: String) -> Bool {
        let path = reference.hasPrefix("./") ? String(reference.dropFirst(2)) : reference
        return ignoredPrefixes.contains { PathMath.path(path, isWithin: $0) }
    }
}
