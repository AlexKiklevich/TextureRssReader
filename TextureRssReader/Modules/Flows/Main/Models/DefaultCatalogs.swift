//
//  DefaultCatalogs.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 9.02.26.
//

import Foundation

struct DefaultCatalogs {
    static let array = [
        RssCatalogSource(title: "Rbc", url: URL(string: "https://rssexport.rbc.ru/rbcnews/news/30/full.rss")!),
        RssCatalogSource(title: "Vedomosti", url: URL(string: "https://www.vedomosti.ru/info/rss")!)
    ]
}
