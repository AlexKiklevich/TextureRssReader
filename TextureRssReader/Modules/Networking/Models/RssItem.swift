//
//  RssItem.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 2.02.26.
//

import Foundation

struct RssItem: Hashable {
    let title: String
    let link: URL?
    let summary: String?
    let publishedAt: Date?
    let imageURL: URL?
    let parentCatalog: RssCatalogSource
}
