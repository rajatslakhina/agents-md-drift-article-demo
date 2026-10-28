import Foundation

/// One governed rule in an instruction file.
///
/// A rule is declared by an HTML comment on the line above it, which renders as
/// nothing on GitHub and costs an agent a handful of tokens:
///
/// ```
/// <!-- rule id=docc owner=@docs-team review-by=2027-01-31 decision=ADR-014 anchors=Sources/App/App.docc -->
/// - When you change public API, update the DocC catalog in `Sources/App/App.docc/`.
/// ```
///
/// The rule's text runs until the next blank line, heading or rule comment.
/// Its anchors are the explicit `anchors=` list plus every path referenced in the text.
public struct InstructionRule: Equatable, Sendable {
    public let id: String
    public let owner: String?
    public let reviewBy: Day?
    public let decision: String?
    public let anchors: [String]
    public let text: String
    /// 1-based line of the rule comment.
    public let line: Int
}

/// A calendar day (`2027-01-31`), compared without time zones.
public struct Day: Comparable, Hashable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year; self.month = month; self.day = day
    }

    public init?(_ text: String) {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, (1...12).contains(parts[1]), (1...31).contains(parts[2]) else { return nil }
        year = parts[0]; month = parts[1]; day = parts[2]
    }

    public static func < (lhs: Day, rhs: Day) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    public var description: String { String(format: "%04d-%02d-%02d", year, month, day) }
}

public enum RuleParser {
    public static func rules(in markdown: String) -> [InstructionRule] {
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var rules: [InstructionRule] = []
        var index = 0
        while index < lines.count {
            guard let fields = annotation(lines[index]) else { index += 1; continue }
            let commentLine = index + 1
            var body: [String] = []
            index += 1
            while index < lines.count {
                let line = lines[index]
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty || trimmed.hasPrefix("#") || annotation(line) != nil { break }
                body.append(line)
                index += 1
            }
            let text = body.joined(separator: "\n")
            let explicit = fields["anchors"]?.split(separator: ",").map { String($0) } ?? []
            let referenced = ReferenceExtractor.references(in: text).map(\.text)
            var anchors: [String] = []
            for anchor in explicit + referenced where !anchors.contains(anchor) { anchors.append(anchor) }
            rules.append(InstructionRule(
                id: fields["id"] ?? "rule-\(commentLine)",
                owner: fields["owner"],
                reviewBy: fields["review-by"].flatMap(Day.init),
                decision: fields["decision"],
                anchors: anchors,
                text: text,
                line: commentLine
            ))
        }
        return rules
    }

    /// Parses `<!-- rule key=value key=value -->`, or returns nil.
    static func annotation(_ line: String) -> [String: String]? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("<!--"), trimmed.hasSuffix("-->") else { return nil }
        let inner = trimmed.dropFirst(4).dropLast(3).split(whereSeparator: \.isWhitespace)
        guard inner.first == "rule" else { return nil }
        var fields: [String: String] = [:]
        for pair in inner.dropFirst() {
            let parts = pair.split(separator: "=", maxSplits: 1)
            if parts.count == 2 { fields[String(parts[0])] = String(parts[1]) }
        }
        return fields
    }
}
