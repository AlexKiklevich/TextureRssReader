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
    
    func parse(data: Data, baseURL: URL?) throws -> [URL] {
        guard let html = String(data: data, encoding: .utf8) else {
            throw RssCatalogParsingError.invalidEncoding
        }

        var items: [URL] = []
        var seen = Set<URL>()
        var index = html.startIndex

        while let anchorStart = html.range(of: "<a", options: [.caseInsensitive], range: index..<html.endIndex) {
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

            items.append(url)
            seen.insert(url)
        }

        return items
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

    static func looksLikeURL(_ text: String) -> Bool {
        let lower = text.lowercased()
        return Constants.urlIndicators.contains { lower.contains($0) }
    }

    static func isLikelyRssURL(_ url: URL) -> Bool {
        let lower = url.absoluteString.lowercased()
        return Constants.rssIndicators.contains { lower.contains($0) }
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
