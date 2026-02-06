//
//  RssFeedParser.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 2.02.26.
//

import Foundation

final class RssFeedParser: NSObject {
    private var items: [ParsedRssItem] = []
    private var currentItem: CurrentItem?
    private var currentText = ""
    private let dateParser = RssDateParser()

    func parse(data: Data) throws -> [ParsedRssItem] {
        items = []
        currentItem = nil
        currentText = ""

        let parser = XMLParser(data: data)
        parser.delegate = self
        let success = parser.parse()
        if !success {
            if let error = parser.parserError {
                throw error
            }
            throw RssParsingError.parsingFailed
        }
        return items
    }
}

extension RssFeedParser: XMLParserDelegate {
    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentText = ""
        if elementName == "item" {
            currentItem = CurrentItem()
            return
        }

        guard var currentItem else { return }
        if currentItem.imageUrl == nil,
           let urlString = Self.imageURL(from: elementName, attributes: attributeDict) {
            currentItem.imageUrl = urlString
            self.currentItem = currentItem
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if elementName == "item" {
            if let currentItem, let parsed = currentItem.toParsedItem() {
                items.append(parsed)
            }
            self.currentItem = nil
            currentText = ""
            return
        }

        guard var currentItem else {
            currentText = ""
            return
        }

        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            switch elementName {
            case "title":
                currentItem.title = text
            case "link":
                currentItem.link = text
            case "guid":
                currentItem.guid = text
            case "description":
                if currentItem.summary == nil {
                    currentItem.summary = text
                }
                if currentItem.imageUrl == nil,
                   let imageUrl = Self.firstImageURL(in: text) {
                    currentItem.imageUrl = imageUrl
                }
            case "content:encoded":
                currentItem.summary = text
                if currentItem.imageUrl == nil,
                   let imageUrl = Self.firstImageURL(in: text) {
                    currentItem.imageUrl = imageUrl
                }
            case "pubDate":
                currentItem.publishedAt = dateParser.parse(text)
            default:
                break
            }
        }

        self.currentItem = currentItem
        currentText = ""
    }
}

private struct CurrentItem {
    var guid: String?
    var title: String?
    var link: String?
    var summary: String?
    var publishedAt: Date?
    var imageUrl: String?

    func toParsedItem() -> ParsedRssItem? {
        let resolvedTitle = (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = resolvedTitle.isEmpty ? "Untitled" : resolvedTitle
        let url = link.flatMap { URL(string: $0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        let imageURL = imageUrl
            .flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .flatMap { URL(string: $0) }

        return ParsedRssItem(
            guid: guid?.trimmingCharacters(in: .whitespacesAndNewlines),
            title: finalTitle,
            link: url,
            summary: summary?.trimmingCharacters(in: .whitespacesAndNewlines),
            publishedAt: publishedAt,
            imageURL: imageURL
        )
    }
}

private struct RssDateParser {
    private let formatters: [DateFormatter]

    init() {
        let locale = Locale(identifier: "en_US_POSIX")
        let timezone = TimeZone(secondsFromGMT: 0)

        func formatter(_ format: String) -> DateFormatter {
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.timeZone = timezone
            formatter.dateFormat = format
            return formatter
        }

        formatters = [
            formatter("EEE, dd MMM yyyy HH:mm:ss Z"),
            formatter("EEE, dd MMM yyyy HH:mm Z"),
            formatter("dd MMM yyyy HH:mm:ss Z"),
            formatter("yyyy-MM-dd'T'HH:mm:ssZ"),
            formatter("yyyy-MM-dd'T'HH:mm:ss.SSSZ")
        ]
    }

    func parse(_ string: String) -> Date? {
        for formatter in formatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }
}

private extension RssFeedParser {
    static func imageURL(from elementName: String, attributes: [String: String]) -> String? {
        let normalized = elementName.lowercased()
        guard normalized == "enclosure" || normalized == "media:content" || normalized == "media:thumbnail" else {
            return nil
        }
        guard let urlString = attributes["url"] ?? attributes["href"] else { return nil }

        let type = attributes["type"]?.lowercased()
        let medium = attributes["medium"]?.lowercased()
        let isImage = (type?.hasPrefix("image/") ?? false) || medium == "image" || normalized == "media:thumbnail"
        if isImage || (type == nil && medium == nil) {
            return urlString
        }
        return nil
    }

    static func firstImageURL(in html: String) -> String? {
        let pattern = "<img[^>]+src\\s*=\\s*[\"']([^\"']+)[\"']"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, options: [], range: range),
              match.numberOfRanges >= 2,
              let urlRange = Range(match.range(at: 1), in: html) else {
            return nil
        }
        return String(html[urlRange])
    }
}
