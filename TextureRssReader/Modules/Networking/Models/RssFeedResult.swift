//
//  RssFeedResult.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 2.02.26.
//

struct RssFeedResult: Hashable {
    let source: RssItemSource
    let items: [RssItem]
    let error: RssServiceError?
}
