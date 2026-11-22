//
//  MarkdownText.swift
//  VatSight
//
//  Renders event descriptions: block structure from `MarkdownParser`, inline styling from
//  Foundation's Markdown support, plus automatic links for bare URLs. Rendered output is
//  cached per source string so scrolling never re-parses.
//

import SwiftUI
import UIKit

// MARK: - Rendered Model

private struct RenderedListItem {
    let level: Int
    let marker: String
    let text: AttributedString
}

private enum RenderedMarkdownBlock {
    case heading(level: Int, text: AttributedString)
    case paragraph(AttributedString)
    case list([RenderedListItem])
    case quote(AttributedString)
    case rule
    case image(url: URL, alt: String)
    case code(String)
}

private final class RenderedMarkdown {
    let blocks: [RenderedMarkdownBlock]
    let preview: AttributedString

    init(blocks: [RenderedMarkdownBlock], preview: AttributedString) {
        self.blocks = blocks
        self.preview = preview
    }
}

// MARK: - Inline Rendering

enum MarkdownInline {
    private static let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    /// Inline Markdown (bold, italics, code, links) with bare URLs turned into links.
    static func attributed(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            allowsExtendedAttributes: false,
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        var result = (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
        linkify(&result)
        return result
    }

    /// Adds `.link` to any URL the data detector finds that isn't already part of a link.
    static func linkify(_ attributed: inout AttributedString) {
        guard let detector else { return }
        let plain = String(attributed.characters)
        let matches = detector.matches(in: plain, range: NSRange(plain.startIndex..., in: plain))
        for match in matches {
            guard var url = match.url, let range = Range(match.range, in: plain) else { continue }
            if url.scheme == nil, let withScheme = URL(string: "https://" + url.absoluteString) {
                url = withScheme
            }
            let offset = plain.distance(from: plain.startIndex, to: range.lowerBound)
            let length = plain.distance(from: range.lowerBound, to: range.upperBound)
            let start = attributed.characters.index(attributed.startIndex, offsetBy: offset)
            let end = attributed.characters.index(start, offsetBy: length)
            let attributedRange = start..<end
            guard !attributed[attributedRange].runs.contains(where: { $0.link != nil }) else { continue }
            attributed[attributedRange].link = url
        }
    }
}

// MARK: - Cache

private enum MarkdownRenderCache {
    private static let cache: NSCache<NSString, RenderedMarkdown> = {
        let cache = NSCache<NSString, RenderedMarkdown>()
        cache.countLimit = 400
        return cache
    }()

    static func render(_ source: String) -> RenderedMarkdown {
        let key = source as NSString
        if let cached = cache.object(forKey: key) { return cached }

        let blocks: [RenderedMarkdownBlock] = MarkdownParser.blocks(from: source).map { block in
            switch block {
            case .heading(let level, let text):
                return .heading(level: level, text: MarkdownInline.attributed(text))
            case .paragraph(let text):
                return .paragraph(MarkdownInline.attributed(text))
            case .list(let items):
                let rendered = items.map { item -> RenderedListItem in
                    let marker: String
                    if let number = item.number {
                        marker = "\(number)."
                    } else {
                        marker = item.level == 0 ? "•" : "◦"
                    }
                    return RenderedListItem(level: item.level, marker: marker, text: MarkdownInline.attributed(item.text))
                }
                return .list(rendered)
            case .quote(let text):
                return .quote(MarkdownInline.attributed(text))
            case .rule:
                return .rule
            case .image(let url, let alt):
                return .image(url: url, alt: alt)
            case .code(let text):
                return .code(text)
            }
        }

        // One-paragraph preview for cards: text blocks joined with spaces, newlines flattened.
        var preview = AttributedString()
        for block in blocks {
            let piece: AttributedString?
            switch block {
            case .heading(_, let text), .paragraph(let text), .quote(let text): piece = text
            case .list(let items):
                piece = items.reduce(into: AttributedString()) { partial, item in
                    if !partial.characters.isEmpty { partial += AttributedString(" · ") }
                    partial += item.text
                }
            case .rule, .image, .code: piece = nil
            }
            guard var piece else { continue }
            piece = flattenNewlines(piece)
            if !preview.characters.isEmpty { preview += AttributedString(" ") }
            preview += piece
        }

        let rendered = RenderedMarkdown(blocks: blocks, preview: preview)
        cache.setObject(rendered, forKey: key)
        return rendered
    }

    private static func flattenNewlines(_ text: AttributedString) -> AttributedString {
        var copy = text
        while let range = copy.characters.firstIndex(of: "\n") {
            copy.replaceSubrange(range..<copy.characters.index(after: range), with: AttributedString(" "))
        }
        return copy
    }
}

// MARK: - Views

/// Full block rendering for detail screens.
struct MarkdownText: View {
    let source: String

    init(_ source: String) {
        self.source = source
    }

    var body: some View {
        let rendered = MarkdownRenderCache.render(source)
        VStack(alignment: .leading, spacing: 12) {
            ForEach(rendered.blocks.indices, id: \.self) { index in
                blockView(rendered.blocks[index])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func blockView(_ block: RenderedMarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(text)
                .font(headingFont(level))
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 4)
        case .paragraph(let text):
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        case .list(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(items.indices, id: \.self) { index in
                    let item = items[index]
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(item.marker)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        Text(item.text)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.leading, CGFloat(item.level) * 16)
                }
            }
        case .quote(let text):
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(.tertiary)
                    .frame(width: 3)
                Text(text)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .rule:
            Divider()
                .padding(.vertical, 4)
        case .image(let url, let alt):
            RemoteImage(url: url, contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: 260)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityLabel(alt.isEmpty ? "Image" : alt)
        case .code(let text):
            Text(text)
                .font(.footnote.monospaced())
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .textSelection(.enabled)
        }
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: return .title2.bold()
        case 2: return .title3.bold()
        default: return .headline
        }
    }
}

/// Single-paragraph inline rendering for cards (apply `.lineLimit` at the call site).
struct MarkdownPreviewText: View {
    let source: String

    init(_ source: String) {
        self.source = source
    }

    var body: some View {
        Text(MarkdownRenderCache.render(source).preview)
    }
}

// MARK: - In-App Links

private struct IdentifiableURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

/// Opens web links (Markdown links, `Link`, data-detected URLs) in an in-app Safari sheet,
/// matching how the rest of the app presents web content. Other schemes go to the system.
private struct InAppLinkModifier: ViewModifier {
    @State private var presentedURL: IdentifiableURL?

    func body(content: Content) -> some View {
        content
            .environment(\.openURL, OpenURLAction { url in
                guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
                    return .systemAction
                }
                presentedURL = IdentifiableURL(url: url)
                return .handled
            })
            .sheet(item: $presentedURL) { item in
                SafariView(url: item.url)
                    .ignoresSafeArea()
            }
    }
}

extension View {
    func opensWebLinksInApp() -> some View {
        modifier(InAppLinkModifier())
    }
}
