//
//  ParsedRssItem.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 2.02.26.
//

import Foundation

struct ParsedRssItem: Hashable {
    let guid: String?
    let title: String
    let link: URL?
    let summary: String?
    let publishedAt: Date?
    let imageURL: URL?
}
