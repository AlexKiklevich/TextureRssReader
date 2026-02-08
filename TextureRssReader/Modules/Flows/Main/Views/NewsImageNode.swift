//
//  NewsImageNode.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 8.02.26.
//

import AsyncDisplayKit

final class NewsImageNode: ASNetworkImageNode {
    private let cache: RssImageCache
    private let downloader = ASPINRemoteImageDownloader.shared()
    
    init(cache: RssImageCache) {
        self.cache = cache
        super.init(cache: cache, downloader: downloader)
        self.delegate = self
    }
}

extension NewsImageNode: ASNetworkImageNodeDelegate {
    func imageNode(_ imageNode: ASNetworkImageNode, didLoad image: UIImage, info: ASNetworkImageLoadInfo) {
        cache.imageDidLoad(image, withInfo: info)
    }
}
