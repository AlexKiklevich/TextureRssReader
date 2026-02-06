//
//  RssFeedParser.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 2.02.26.
//

import Foundation

final class RssFeedParser: NSObject {
    
    private struct Element {
        static let item = "item"
        static let title = "title"
        static let link = "link"
        static let guid = "guid"
        static let description = "description"
        static let contentEncoded = "content:encoded"
        static let pubDate = "pubDate"
        static let enclosure = "enclosure"
        static let mediaContent = "media:content"
        static let mediaThumbnail = "media:thumbnail"
    }
    
    private struct AttributeKey {
        static let type = "type"
        static let medium = "medium"
        static let url = "url"
        static let href = "href"
    }
    
    private struct AttributeConstant {
        static let imageTypePrefix = "image/"
        static let imageValue = "image"
    }
    
    private var items: [ParsedRssItem] = []
    private var currentItem: CurrentItem?
    private var currentText = ""
    private let dateFormatter = CommonDateFormatter.shared

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
        if elementName == Element.item {
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
        if elementName == Element.item {
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
            case Element.title:
                currentItem.title = text
            case Element.link:
                currentItem.link = text
            case Element.guid:
                currentItem.guid = text
            case Element.description:
                if currentItem.summary == nil {
                    currentItem.summary = text
                }
                if currentItem.imageUrl == nil,
                   let imageUrl = Self.firstImageURL(in: text) {
                    currentItem.imageUrl = imageUrl
                }
            case Element.contentEncoded:
                currentItem.summary = text
                if currentItem.imageUrl == nil,
                   let imageUrl = Self.firstImageURL(in: text) {
                    currentItem.imageUrl = imageUrl
                }
            case Element.pubDate:
                currentItem.publishedAt = dateFormatter.formatDate(fromString: text)
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

private extension RssFeedParser {
    static func imageURL(from elementName: String, attributes: [String: String]) -> String? {
        let normalized = elementName.lowercased()
        guard normalized == Element.enclosure
                || normalized == Element.mediaContent
                || normalized == Element.mediaThumbnail else {
            return nil
        }
        guard let urlString = attributes[AttributeKey.url] ?? attributes[AttributeKey.href] else {
            return nil
        }

        let type = attributes[AttributeKey.type]?.lowercased()
        let medium = attributes[AttributeKey.medium]?.lowercased()
        let isImage = (type?.hasPrefix(AttributeConstant.imageTypePrefix) ?? false)
        || medium == AttributeConstant.imageValue
        || normalized == Element.mediaThumbnail
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
