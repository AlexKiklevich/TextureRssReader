//
//  AppService.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 8.02.26.
//

import Foundation

final class AppService {
    let rssImageService: RssImageService = DefaultRssImageService()
    let rssManager: RssManager
    let realmProvider = RealmProvider()
    let userDefaultsProvider = UserDefaultsProvider()

    init() {
        self.rssManager = RssManager(realmProvider: realmProvider, userDefaultsProvider: userDefaultsProvider)
    }
}
