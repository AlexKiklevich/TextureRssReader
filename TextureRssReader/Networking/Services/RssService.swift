//
//  RssService.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 2.02.26.
//

protocol RssService {
    func fetchItems(sources: [RssSource]) async -> [RssFeedResult]
}
