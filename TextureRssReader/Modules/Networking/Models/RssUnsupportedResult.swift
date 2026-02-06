//
//  RssUnsupportedResult.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 6.02.26.
//

import Foundation

enum RssUnsupportedReason: Hashable {
    case notRss
    case network(underlying: String)
    case parsing(underlying: String)
}

struct RssUnsupportedResult: Hashable {
    let url: URL
    let reason: RssUnsupportedReason
}
