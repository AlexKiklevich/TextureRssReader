//
//  RssImageService.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 8.02.26.
//

import AsyncDisplayKit

protocol RssImageService: ASImageCacheProtocol {
    var downloader: ASPINRemoteImageDownloader { get }
    func imageDidLoad(_ image: UIImage, withInfo info: ASNetworkImageLoadInfo)
    func clearCache()
}

final class DefaultRssImageService: NSObject, RssImageService {
    
    private struct Constants {
        let totalCostLimit: Int = 100 * 1024 * 1024 // 100 MB
    }
    private let cache: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        cache.totalCostLimit = Constants().totalCostLimit
        return cache
    }()
    let downloader = ASPINRemoteImageDownloader.shared()
    
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

    func clearCache() {
        cache.removeAllObjects()
    }
    
    private func imageCost(_ image: UIImage) -> Int {
        guard let cg = image.cgImage else {
            return 0
        }
        return cg.bytesPerRow * cg.height
    }
}
