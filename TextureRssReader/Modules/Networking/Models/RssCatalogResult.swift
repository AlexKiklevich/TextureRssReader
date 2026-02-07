//
//  RssCatalogResult.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 6.02.26.
//

import Foundation

struct RssCatalogResult: Hashable {
    let catalogSource: RssSource
    let rssSources: [RssSource]
    let error: RssCatalogServiceError?
}
