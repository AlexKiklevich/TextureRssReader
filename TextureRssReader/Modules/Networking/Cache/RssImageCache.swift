//
//  RssImageCache.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 8.02.26.
//

import AsyncDisplayKit

protocol RssImageCache: ASImageCacheProtocol {
    func imageDidLoad(_ image: UIImage, withInfo info: ASNetworkImageLoadInfo)
}

final class DefaultRssImageCache: NSObject, RssImageCache {
    
    private struct Constants {
        let totalCostLimit: Int = 100 * 1024 * 1024 // 100 MB
    }
    private let cache: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        cache.totalCostLimit = Constants().totalCostLimit
        return cache
    }()
    
    func cachedImage(
        with URL: URL,
        callbackQueue: dispatch_queue_t
    ) async -> ((any ASImageContainerProtocol)?, ASImageCacheType) {
        guard let image = cache.object(forKey: URL as NSURL) else {
            return (nil, .asynchronous)
        }
        return (image, .asynchronous)
    }
    
    func imageDidLoad(_ image: UIImage, withInfo info: ASNetworkImageLoadInfo) {
        switch info.sourceType {
        case .unspecified, .fileURL, .download:
            let imageCost = imageCost(image)
            cache.setObject(image, forKey: info.url as NSURL, cost: imageCost)
        default:
            return
        }
    }
    
    private func imageCost(_ image: UIImage) -> Int {
        guard let cg = image.cgImage else {
            return 0
        }
        return cg.bytesPerRow * cg.height
    }
}
