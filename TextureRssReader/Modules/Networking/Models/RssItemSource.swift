//
//  RssItemSource.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 7.02.26.
//

import Foundation

struct RssItemSource: Hashable {
    let catalog: RssCatalogSource
    let url: URL
}
