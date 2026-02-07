//
//  RssCatalogParser.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 6.02.26.
//

import UIKit

final class RssCatalogParser {
    
    private struct Constants {
        static let rssIndicators = ["/rss/", ".rss", "rss.xml"]
        static let urlIndicators = ["http://", "https://", "www.", "/rss"]
    }
    
    func parse(data: Data, baseURL: URL?) throws -> [RssSource] {
        guard let html = String(data: data, encoding: .utf8) else {
            throw RssCatalogParsingError.invalidEncoding
        }

        var sources: [RssSource] = []
        var seen = Set<URL>()
        var index = html.startIndex
        var lastLabel: String?

        while let anchorStart = html.range(of: "<a", options: [.caseInsensitive], range: index..<html.endIndex) {
            let textChunk = String(html[index..<anchorStart.lowerBound])
            if let labelCandidate = Self.lastLabelCandidate(from: textChunk) {
                lastLabel = labelCandidate
            }

            guard let tagEnd = html.range(of: ">", range: anchorStart.lowerBound..<html.endIndex) else {
                break
            }

            let tag = String(html[anchorStart.lowerBound..<tagEnd.upperBound])
            let href = Self.extractHref(from: tag)

            guard let closeRange = html.range(of: "</a>", options: [.caseInsensitive], range: tagEnd.upperBound..<html.endIndex) else {
                index = tagEnd.upperBound
                continue
            }

            let anchorText = String(html[tagEnd.upperBound..<closeRange.lowerBound])
            index = closeRange.upperBound

            guard let href, let url = Self.resolveURL(href, baseURL: baseURL) else { continue }
            guard Self.isLikelyRssURL(url) else { continue }
            guard !seen.contains(url) else { continue }

            let resolvedTitle = Self.resolveTitle(anchorText: anchorText, fallback: lastLabel, url: url)
            sources.append(RssSource(title: resolvedTitle, url: url))
            seen.insert(url)
        }

        return sources
    }
}

private extension RssCatalogParser {
    static func resolveURL(_ href: String, baseURL: URL?) -> URL? {
        let trimmed = href.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let baseURL,
           let resolved = URL(string: trimmed, relativeTo: baseURL)?.absoluteURL {
            return resolved
        }
        return URL(string: trimmed)
    }

    static func extractHref(from tag: String) -> String? {
        let pattern = "(?i)href\\s*=\\s*(\"([^\"]*)\"|'([^']*)'|([^\\s>]+))"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(tag.startIndex..<tag.endIndex, in: tag)
        guard let match = regex.firstMatch(in: tag, options: [], range: range) else { return nil }
        for index in 2...4 {
            if match.numberOfRanges > index,
               let hrefRange = Range(match.range(at: index), in: tag) {
                return String(tag[hrefRange])
            }
        }
        return nil
    }

    static func resolveTitle(anchorText: String, fallback: String?, url: URL) -> String {
        let cleanedAnchor = cleanText(anchorText)
        if cleanedAnchor.isEmpty || looksLikeURL(cleanedAnchor) {
            if let fallback, !fallback.isEmpty {
                return fallback
            }
        }
        if cleanedAnchor.isEmpty {
            return url.absoluteString
        }
        return cleanedAnchor
    }

    static func looksLikeURL(_ text: String) -> Bool {
        let lower = text.lowercased()
        return Constants.urlIndicators.contains { lower.contains($0) }
    }

    static func isLikelyRssURL(_ url: URL) -> Bool {
        let lower = url.absoluteString.lowercased()
        return Constants.rssIndicators.contains { lower.contains($0) }
    }

    static func lastLabelCandidate(from text: String) -> String? {
        let cleaned = cleanText(text)
        guard !cleaned.isEmpty else { return nil }
        let separators = CharacterSet(charactersIn: "\n\r•|—")
        let parts = cleaned
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.last
    }

    static func cleanText(_ text: String) -> String {
        let withoutTags = text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        let decoded = decodeHTMLEntities(withoutTags)
        let collapsed = decoded.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        return collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func decodeHTMLEntities(_ text: String) -> String {
        guard let data = text.data(using: .utf8) else { return text }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        if let attributed = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
            return attributed.string
        }
        return text
    }
}
