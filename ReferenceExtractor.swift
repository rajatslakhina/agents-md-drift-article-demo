import Foundation

/// A path-like token found in an instruction file, with the 1-based line it sits on.
public struct Reference: Hashable, Sendable {
    public let text: String
    public let line: Int

    public init(text: String, line: Int) {
        self.text = text
        self.line = line
    }
}

/// Pulls path-like references out of an AGENTS.md / CLAUDE.md file.
///
/// Only code spans (`like/this.swift`) and fenced code blocks are read. Prose is
/// ignored on purpose: a path an author bothered to put in backticks is a path
/// they expect an agent to open, run or edit.
public enum ReferenceExtractor {
    /// Extensions that make a slash-free token count as a file reference (`Package.swift`).
    public static let fileExtensions: Set<String> = [
        "swift", "md", "yml", "yaml", "sh", "plist", "json", "xcodeproj", "xcworkspace",
        "rb", "py", "toml", "metal", "entitlements", "xcconfig", "txt", "h", "m", "c",
        "resolved", "xcscheme", "strings", "xcstrings", "js", "ts", "kt", "rs", "gradle", "docc"
    ]

    private static let rejectedPrefixes = ["-", "http", "$", "~", "/", "@", "<", "{", "#", "%"]
    private static let rejectedCharacters = Set("<>{}$=|*?[]\"()")
    private static let edgeTrim = CharacterSet(charactersIn: "\"'(),;:")

    /// Every path-like reference in `markdown`, in reading order. A token repeated on
    /// the same line is reported once; the same token on two lines is reported twice,
    /// because each line has its own last-edited date.
    public static func references(in markdown: String) -> [Reference] {
        var result: [Reference] = []
        var inFence = false
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false)
        for (index, rawLine) in lines.enumerated() {
            let line = String(rawLine)
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                inFence.toggle()
                continue
            }
            let spans = inFence ? [line] : codeSpans(in: line)
            var seenOnLine = Set<String>()
            for span in spans {
                for token in pathTokens(in: span) where seenOnLine.insert(token).inserted {
                    result.append(Reference(text: token, line: index + 1))
                }
            }
        }
        return result
    }

    /// The contents of single-backtick code spans on one line.
    static func codeSpans(in line: String) -> [String] {
        var spans: [String] = []
        var current = ""
        var open = false
        for character in line {
            if character == "`" {
                if open { spans.append(current) }
                current = ""
                open.toggle()
            } else if open {
                current.append(character)
            }
        }
        return spans.filter { !$0.isEmpty }
    }

    /// Whitespace-separated tokens of a span that look like repository paths.
    static func pathTokens(in span: String) -> [String] {
        span.split(whereSeparator: \.isWhitespace).compactMap { normalizedPath(String($0)) }
    }

    /// Returns the cleaned token if it looks like a repo-relative path, otherwise nil.
    public static func normalizedPath(_ raw: String) -> String? {
        var token = raw.trimmingCharacters(in: edgeTrim)
        guard !token.isEmpty, !token.contains("://") else { return nil }
        if rejectedPrefixes.contains(where: { token.hasPrefix($0) }) { return nil }
        if token.contains(where: { rejectedCharacters.contains($0) }) { return nil }
        // A trailing slash marks a directory (`Nodes/`), so it counts as a path.
        let markedDirectory = token.hasSuffix("/")
        while token.hasSuffix("/") { token.removeLast() }
        guard token != ".", token != "..", token.contains(where: \.isLetter) else { return nil }
        if markedDirectory || token.contains("/") { return token }
        guard let dot = token.lastIndex(of: "."), dot != token.startIndex else { return nil }
        let ext = token[token.index(after: dot)...].lowercased()
        return fileExtensions.contains(ext) ? token : nil
    }
}
