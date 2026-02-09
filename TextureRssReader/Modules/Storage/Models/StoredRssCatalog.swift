//
//  StoredRssCatalog.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 7.02.26.
//

import RealmSwift

@objc(StoredRssCatalog)
final class StoredRssCatalog: Object {
    @Persisted(primaryKey: true) var id: Int = 0
    @Persisted var catalogSourceTitle: String = ""
    @Persisted var catalogSourceURL: String = ""
    @Persisted var rssTitles: List<String>
    @Persisted var rssUrls: List<String>
    @Persisted var storedAt: Date = Date()

    convenience init(result: RssCatalogResult) {
        self.init()
        id = result.catalogSource.url.hashValue
        catalogSourceTitle = result.catalogSource.title
        catalogSourceURL = result.catalogSource.url.absoluteString
        storedAt = Date()

        for snapshot in result.rssSnapshots {
            rssTitles.append(snapshot.title)
            rssUrls.append(snapshot.url.absoluteString)
        }
    }

    func toRssCatalogResult() -> RssCatalogResult? {
        guard let parsedCatalogSourceURL = URL(string: catalogSourceURL) else {
            return nil
        }
        let catalogSource = RssCatalogSource(title: catalogSourceTitle, url: parsedCatalogSourceURL)
        var mappedSnapshots: [RssItemSnapshot] = []

        for (index, urlString) in rssUrls.enumerated() {
            guard let url = URL(string: urlString) else { continue }
            let title = rssTitles.indices.contains(index) ? rssTitles[index] : urlString
            mappedSnapshots.append(
                RssItemSnapshot(
                    title: title,
                    url: url
                )
            )
        }

        return RssCatalogResult(
            catalogSource: catalogSource,
            rssSnapshots: mappedSnapshots,
            error: nil
        )
    }
}
