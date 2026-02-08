//
//  RssFeedResult.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 2.02.26.
//

struct RssFeedResult: Hashable {
    let snapshot: RssItemSnapshot
    let items: [RssItem]
    let parentCatalog: RssCatalogSource
    let error: RssServiceError?
}
