//
//  AppService.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 8.02.26.
//

import Foundation

final class AppService {
    let rssImageService: RssImageService
    let rssManager: RssManager
    let realmProvider: RealmProvider

    init(
        rssImageService: RssImageService = DefaultRssImageService(),
        rssManager: RssManager = RssManager(),
        realmProvider: RealmProvider = RealmProvider()
    ) {
        self.rssImageService = rssImageService
        self.rssManager = rssManager
        self.realmProvider = realmProvider
    }
}
