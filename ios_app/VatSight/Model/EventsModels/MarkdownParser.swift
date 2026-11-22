//
//  MarkdownParser.swift
//  VatSight
//
//  A small block-level Markdown parser for event descriptions. Foundation's
//  `AttributedString(markdown:)` only handles inline syntax (bold, italics, links, code),
//  so headings, lists, quotes, rules and images are split out here first and each block's
//  text is rendered inline by `MarkdownText`.
//

import Foundation

nonisolated struct MarkdownListItem: Hashable, Sendable {
    /// Nesting depth, 0 for top level.
    let level: Int
    /// The ordinal for ordered lists, nil for bullets.
    let number: Int?
    var text: String
}

nonisolated enum MarkdownBlock: Hashable, Sendable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case list([MarkdownListItem])
    case quote(String)
    case rule
    case image(url: URL, alt: String)
    case code(String)
}

nonisolated enum MarkdownParser {

    // MARK: - Blocks

    static func blocks(from source: String) -> [MarkdownBlock] {
        let normalised = source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalised.components(separatedBy: "\n")

        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []
        var listItems: [MarkdownListItem] = []
        var quote: [String] = []
        var code: [String]? = nil

        func flushParagraph() {
            let text = paragraph.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { blocks.append(.paragraph(text)) }
            paragraph.removeAll()
        }
        func flushList() {
            if !listItems.isEmpty { blocks.append(.list(listItems)) }
            listItems.removeAll()
        }
        func flushQuote() {
            let text = quote.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { blocks.append(.quote(text)) }
            quote.removeAll()
        }
        func flushAll() {
            flushParagraph()
            flushList()
            flushQuote()
        }

        for rawLine in lines {
            let line = rawLine.replacingOccurrences(of: "\t", with: "    ")
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Fenced code blocks are kept verbatim.
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                if let open = code {
                    blocks.append(.code(open.joined(separator: "\n")))
                    code = nil
                } else {
                    flushAll()
                    code = []
                }
                continue
            }
            if code != nil {
                code?.append(rawLine)
                continue
            }

            if trimmed.isEmpty {
                flushAll()
                continue
            }

            // Setext headings: a line of === or --- directly under paragraph text.
            if !paragraph.isEmpty, listItems.isEmpty, quote.isEmpty,
               let underline = setextLevel(trimmed) {
                let text = paragraph.joined(separator: " ").trimmingCharacters(in: .whitespaces)
                paragraph.removeAll()
                blocks.append(.heading(level: underline, text: text))
                continue
            }

            if isThematicBreak(trimmed) {
                flushAll()
                blocks.append(.rule)
                continue
            }

            if let heading = atxHeading(trimmed) {
                flushAll()
                blocks.append(.heading(level: heading.level, text: heading.text))
                continue
            }

            if let image = standaloneImage(trimmed) {
                flushAll()
                blocks.append(.image(url: image.url, alt: image.alt))
                continue
            }

            if let quoted = quoteContent(line) {
                flushParagraph()
                flushList()
                quote.append(quoted)
                continue
            } else if !quote.isEmpty {
                // Lazy continuation of a quote.
                if paragraph.isEmpty && listItems.isEmpty {
                    quote.append(trimmed)
                    continue
                }
                flushQuote()
            }

            if let item = listItem(line) {
                flushParagraph()
                listItems.append(item)
                continue
            }

            if !listItems.isEmpty {
                // Continuation line of the last list item.
                listItems[listItems.count - 1].text += "\n" + trimmed
                continue
            }

            paragraph.append(trimmed)
        }

        if let open = code { blocks.append(.code(open.joined(separator: "\n"))) }
        flushAll()
        return blocks
    }

    // MARK: - Plain Text

    /// The source with Markdown syntax removed. Used for calendar notes, accessibility
    /// and comparing the short description against the full description.
    static func plainText(from source: String) -> String {
        blocks(from: source).compactMap { block -> String? in
            switch block {
            case .heading(_, let text), .paragraph(let text), .quote(let text):
                return stripInline(text)
            case .list(let items):
                return items.map { "• " + stripInline($0.text) }.joined(separator: "\n")
            case .code(let text):
                return text
            case .rule, .image:
                return nil
            }
        }
        .joined(separator: "\n\n")
    }

    /// Removes inline Markdown (links, emphasis, code spans, images) leaving readable text.
    static func stripInline(_ text: String) -> String {
        // Protect backslash-escaped punctuation so the emphasis passes don't consume it.
        var protected = ""
        var escapes: [Character] = []
        var iterator = text.makeIterator()
        while let ch = iterator.next() {
            if ch == "\\", let next = iterator.next() {
                if "\\`*_{}[]()#+-.!>~|".contains(next) {
                    protected.append(Character(UnicodeScalar(0xE000 + escapes.count) ?? "?"))
                    escapes.append(next)
                } else {
                    protected.append(ch)
                    protected.append(next)
                }
            } else {
                protected.append(ch)
            }
        }
        var result = protected
        // Images first, then links: ![alt](url) → "", [text](url) → text
        result = replace(#"!\[[^\]]*\]\([^)]*\)"#, in: result, with: "")
        result = replace(#"\[([^\]]+)\]\([^)]*\)"#, in: result, with: "$1")
        result = replace(#"<(https?://[^>]+)>"#, in: result, with: "$1")
        // Emphasis markers and code spans.
        result = replace(#"(\*\*|__|~~)(.+?)\1"#, in: result, with: "$2")
        result = replace(#"(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?!\w)"#, in: result, with: "$1")
        result = replace(#"(?<![\w_])_(?!\s)(.+?)(?<!\s)_(?![\w])"#, in: result, with: "$1")
        result = replace(#"`([^`]+)`"#, in: result, with: "$1")
        // Restore escaped characters.
        if !escapes.isEmpty {
            result = String(result.map { ch -> Character in
                guard let scalar = ch.unicodeScalars.first, ch.unicodeScalars.count == 1,
                      scalar.value >= 0xE000, Int(scalar.value - 0xE000) < escapes.count
                else { return ch }
                return escapes[Int(scalar.value - 0xE000)]
            })
        }
        return result
    }

    /// Whitespace-collapsed, lowercased plain text for loose comparisons.
    static func comparisonKey(_ source: String) -> String {
        plainText(from: source)
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    // MARK: - Line Classifiers

    private static func setextLevel(_ trimmed: String) -> Int? {
        if trimmed.allSatisfy({ $0 == "=" }) { return 1 }
        if trimmed.count >= 2, trimmed.allSatisfy({ $0 == "-" }) { return 2 }
        return nil
    }

    private static func isThematicBreak(_ trimmed: String) -> Bool {
        let compact = trimmed.filter { $0 != " " }
        guard compact.count >= 3, let first = compact.first, "-*_".contains(first) else { return false }
        return compact.allSatisfy { $0 == first }
    }

    private static func atxHeading(_ trimmed: String) -> (level: Int, text: String)? {
        guard trimmed.hasPrefix("#") else { return nil }
        let hashes = trimmed.prefix { $0 == "#" }
        guard (1...6).contains(hashes.count) else { return nil }
        let rest = trimmed.dropFirst(hashes.count)
        guard rest.isEmpty || rest.first == " " else { return nil }
        var text = rest.trimmingCharacters(in: .whitespaces)
        // Optional closing hashes: "## Title ##"
        while text.hasSuffix("#") { text.removeLast() }
        return (hashes.count, text.trimmingCharacters(in: .whitespaces))
    }

    private static func standaloneImage(_ trimmed: String) -> (url: URL, alt: String)? {
        guard trimmed.hasPrefix("!["), trimmed.hasSuffix(")"),
              let match = firstMatch(#"^!\[([^\]]*)\]\(\s*<?([^)\s>]+)>?(?:\s+"[^"]*")?\s*\)$"#, in: trimmed),
              match.count == 3,
              let url = URL(string: match[2]),
              let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http"
        else { return nil }
        return (url, match[1])
    }

    private static func quoteContent(_ line: String) -> String? {
        let leading = line.prefix { $0 == " " }
        guard leading.count <= 3 else { return nil }
        let rest = line.dropFirst(leading.count)
        guard rest.first == ">" else { return nil }
        var content = rest.dropFirst()
        if content.first == " " { content = content.dropFirst() }
        return String(content)
    }

    private static func listItem(_ line: String) -> MarkdownListItem? {
        let indent = line.prefix { $0 == " " }.count
        let rest = line.dropFirst(indent)
        let level = min(indent / 2, 4)

        if let marker = rest.first, "-*+".contains(marker) {
            let afterMarker = rest.dropFirst()
            guard afterMarker.first == " " else { return nil }
            let text = afterMarker.trimmingCharacters(in: .whitespaces)
            guard !text.isEmpty else { return nil }
            return MarkdownListItem(level: level, number: nil, text: text)
        }

        let digits = rest.prefix { $0.isASCII && $0.isNumber }
        guard (1...9).contains(digits.count) else { return nil }
        let afterDigits = rest.dropFirst(digits.count)
        guard let delimiter = afterDigits.first, delimiter == "." || delimiter == ")" else { return nil }
        let afterDelimiter = afterDigits.dropFirst()
        guard afterDelimiter.first == " " else { return nil }
        let text = afterDelimiter.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        return MarkdownListItem(level: level, number: Int(digits), text: text)
    }

    // MARK: - Regex Helpers

    nonisolated(unsafe) private static var regexCache: [String: NSRegularExpression] = [:]
    private static let regexLock = NSLock()

    private static func regex(_ pattern: String) -> NSRegularExpression? {
        regexLock.lock()
        defer { regexLock.unlock() }
        if let cached = regexCache[pattern] { return cached }
        let compiled = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
        regexCache[pattern] = compiled
        return compiled
    }

    private static func replace(_ pattern: String, in text: String, with template: String) -> String {
        guard let regex = regex(pattern) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: template)
    }

    private static func firstMatch(_ pattern: String, in text: String) -> [String]? {
        guard let regex = regex(pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
        else { return nil }
        return (0..<match.numberOfRanges).map { i in
            Range(match.range(at: i), in: text).map { String(text[$0]) } ?? ""
        }
    }
}
