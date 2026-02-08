//
//  NewsCellViewModel.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 8.02.26.
//

import AsyncDisplayKit

struct NewsCellViewModel {
    let item: NewsRowModel
    let imageService: RssImageService
    
    init(item: NewsRowModel, imageService: RssImageService) {
        self.item = item
        self.imageService = imageService
    }
}
    
