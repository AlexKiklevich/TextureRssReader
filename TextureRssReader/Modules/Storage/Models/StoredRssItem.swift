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
    @Persisted var storedAt: Date = Date()

    convenience init(item: RssItem) {
        self.init()
        id = Self.makeID(for: item).hashValue
        title = item.title
        link = item.link?.absoluteString
        summary = item.summary
        publishedAt = item.publishedAt
        imageURL = item.imageURL?.absoluteString
        catalogTitle = item.parentCatalog.title
        catalogURL = item.parentCatalog.url.absoluteString
        storedAt = Date()
    }

    func toRssItem() -> RssItem? {
        guard let parsedCatalogSourceURL = URL(string: catalogURL) else {
            return nil
        }
        let parentCatalog = RssCatalogSource(title: catalogTitle, url: parsedCatalogSourceURL)
        return RssItem(
            title: title,
            link: link.flatMap(URL.init(string:)),
            summary: summary,
            publishedAt: publishedAt,
            imageURL: imageURL.flatMap(URL.init(string:)),
            parentCatalog: parentCatalog
        )
    }

    private static func makeID(for item: RssItem) -> String {
        let sourcePart = item.parentCatalog.url.absoluteString
        if let link = item.link?.absoluteString, !link.isEmpty {
            return sourcePart + "|" + link
        }
        let datePart = String(item.publishedAt?.timeIntervalSince1970 ?? 0)
        return sourcePart + "|" + item.title + "|" + datePart
    }
}
