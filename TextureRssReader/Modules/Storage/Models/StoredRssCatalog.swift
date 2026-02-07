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
    @Persisted var rssUrls: List<String>
    @Persisted var storedAt: Date = Date()

    convenience init(result: RssCatalogResult) {
        self.init()
        id = result.catalogSource.url.hashValue
        catalogSourceTitle = result.catalogSource.title
        catalogSourceURL = result.catalogSource.url.absoluteString
        storedAt = Date()

        for url in result.rssUrls {
            rssUrls.append(url.absoluteString)
        }
    }

    func toRssCatalogResult() -> RssCatalogResult? {
        guard let parsedCatalogSourceURL = URL(string: catalogSourceURL) else {
            return nil
        }
        let catalogSource = RssCatalogSource(title: catalogSourceTitle, url: parsedCatalogSourceURL)
        let mappedUrls: [URL] = rssUrls.compactMap(URL.init(string:))
        return RssCatalogResult(
            catalogSource: catalogSource,
            rssUrls: mappedUrls,
            error: nil
        )
    }
}
