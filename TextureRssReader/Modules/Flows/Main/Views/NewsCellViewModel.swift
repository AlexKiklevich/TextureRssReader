//
//  NewsCellViewModel.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 8.02.26.
//

import AsyncDisplayKit

struct NewsCellViewModel {
    let item: NewsRowModel
    let imageCache: RssImageCache
    
    init(item: NewsRowModel, imageCache: RssImageCache) {
        self.item = item
        self.imageCache = imageCache
    }
}
    
