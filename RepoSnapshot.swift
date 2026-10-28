import Foundation

/// The tracked files of a repository at one commit, with every parent directory derived.
public struct RepoSnapshot: Sendable {
    public let files: Set<String>
    public let directories: Set<String>
    private let sortedPaths: [String]

    public init<S: Sequence>(files: S) where S.Element == String {
        let fileSet = Set(files.filter { !$0.isEmpty })
        var dirs = Set<String>()
        for path in fileSet {
            var parts = path.split(separator: "/").map(String.init)
            while parts.count > 1 {
                parts.removeLast()
                dirs.insert(parts.joined(separator: "/"))
            }
        }
        self.files = fileSet
        self.directories = dirs
        self.sortedPaths = (Array(fileSet) + Array(dirs)).sorted()
    }

    public func exists(_ path: String) -> Bool {
        files.contains(path) || directories.contains(path)
    }

    /// Resolves a reference the way a reader would: relative to the instruction file's
    /// folder, then to the repo root, then as a tail of a deeper path
    /// (`Synchronizer/Foo.swift` matches `Sources/Kit/Synchronizer/Foo.swift`).
    /// Returns the matched repo path, or nil if nothing tracked matches.
    public func resolve(_ reference: String, relativeTo base: String) -> String? {
        let stripped = reference.hasPrefix("./") ? String(reference.dropFirst(2)) : reference
        let candidates = [
            PathMath.normalize(base.isEmpty ? stripped : base + "/" + stripped),
            PathMath.normalize(stripped)
        ]
        for case let candidate? in candidates where exists(candidate) {
            return candidate
        }
        guard let tail = PathMath.normalize(stripped), !tail.hasPrefix("..") else { return nil }
        let suffix = "/" + tail
        return sortedPaths.first { $0.hasSuffix(suffix) }
    }
}

enum PathMath {
    /// Collapses `.` and `..` segments. Returns nil when `..` climbs above the root.
    static func normalize(_ path: String) -> String? {
        var stack: [Substring] = []
        for part in path.split(separator: "/") {
            switch part {
            case ".": continue
            case "..":
                guard !stack.isEmpty else { return nil }
                stack.removeLast()
            default: stack.append(part)
            }
        }
        return stack.isEmpty ? nil : stack.joined(separator: "/")
    }

    /// True when `path` is `anchor` or sits inside the `anchor` directory.
    static func path(_ path: String, isWithin anchor: String) -> Bool {
        path == anchor || path.hasPrefix(anchor + "/")
    }
}
