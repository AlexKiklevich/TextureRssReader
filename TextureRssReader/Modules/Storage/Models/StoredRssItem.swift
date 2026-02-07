//
//  StoredRssItem.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 7.02.26.
//

import RealmSwift

@objc(StoredRssItem)
final class StoredRssItem: Object {
    @Persisted(primaryKey: true) var id: Int = 0
    @Persisted var title: String = ""
    @Persisted var link: String?
    @Persisted var summary: String?
    @Persisted var publishedAt: Date?
    @Persisted var imageURL: String?
    @Persisted var catalogTitle: String = ""
    @Persisted var catalogURL: String = ""
    @Persisted var itemSourceURL: String = ""
    @Persisted var storedAt: Date = Date()

    convenience init(item: RssItem) {
        self.init()
        id = Self.makeID(for: item).hashValue
        title = item.title
        link = item.link?.absoluteString
        summary = item.summary
        publishedAt = item.publishedAt
        imageURL = item.imageURL?.absoluteString
        catalogTitle = item.source.catalog.title
        catalogURL = item.source.catalog.url.absoluteString
        itemSourceURL = item.source.url.absoluteString
        storedAt = Date()
    }

    func toRssItem() -> RssItem? {
        guard let parsedCatalogSourceURL = URL(string: catalogURL),
              let parsedItemSourceURL = URL(string: itemSourceURL) else {
            return nil
        }
        let catalogSource = RssCatalogSource(title: catalogTitle, url: parsedCatalogSourceURL)
        let itemSource = RssItemSource(catalog: catalogSource, url: parsedItemSourceURL)
        return RssItem(
            title: title,
            link: link.flatMap(URL.init(string:)),
            summary: summary,
            publishedAt: publishedAt,
            imageURL: imageURL.flatMap(URL.init(string:)),
            source: itemSource
        )
    }

    private static func makeID(for item: RssItem) -> String {
        let sourcePart = item.source.url.absoluteString
        if let link = item.link?.absoluteString, !link.isEmpty {
            return sourcePart + "|" + link
        }
        let datePart = String(item.publishedAt?.timeIntervalSince1970 ?? 0)
        return sourcePart + "|" + item.title + "|" + datePart
    }
}
