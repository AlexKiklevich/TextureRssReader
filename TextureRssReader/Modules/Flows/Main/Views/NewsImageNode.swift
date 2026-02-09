//
//  NewsImageNode.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 8.02.26.
//

import AsyncDisplayKit

final class NewsImageNode: ASNetworkImageNode {
    private let service: RssImageService
    
    init(service: RssImageService) {
        self.service = service
        super.init(cache: service, downloader: service.downloader)
        self.delegate = self
    }
}

extension NewsImageNode: ASNetworkImageNodeDelegate {
    func imageNode(_ imageNode: ASNetworkImageNode, didLoad image: UIImage, info: ASNetworkImageLoadInfo) {
        service.imageDidLoad(image, withInfo: info)
    }
}
