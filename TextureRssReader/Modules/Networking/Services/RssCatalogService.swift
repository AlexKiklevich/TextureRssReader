//
//  RssCatalogService.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 6.02.26.
//

import Foundation

protocol RssCatalogService {
    func fetchCatalog(from url: URL) async -> RssCatalogResult
}
