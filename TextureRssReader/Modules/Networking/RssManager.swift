//
//  RssManager.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 6.02.26.
//

import Foundation

protocol RssManagerDelegate {
    func didReceiveCatalog(_ result: RssCatalogResult, source: RssSource)
    func didReceiveFeedItems(_ result: [RssFeedResult], sources: [RssSource])
    func didReceiveUnsupported(_ result: RssUnsupportedResult, source: RssSource)
}

final class RssManager {
    
    private struct Constants {
        static let rssSuffix = ".rss"
        static let xmlSuffix = ".xml"
        static let rssPathComponent = "rss"
    }
    
    private let networkClient: NetworkClient = URLSessionNetworkClient()
    private let catalogService: RssCatalogService
    private let rssService: RssService
    
    init() {
        catalogService = DefaultRssCatalogService(networkClient: networkClient)
        rssService = DefaultRssService(networkClient: networkClient)
    }
    
    func performFetch(sources: [RssSource], delegate: RssManagerDelegate)  {
        for source in sources {
             handleSource(source, delegate: delegate)
        }
    }

    private func handleSource(_ source: RssSource, delegate: RssManagerDelegate)  {
        let classification = classify(source.url)
        switch classification {
        case .feed:
            Task {
                await handleFeed(source, delegate: delegate)
            }
        case .catalog:
            Task {
                await handleCatalog(source, delegate: delegate)
            }
        }
    }

    private func handleFeed(_ source: RssSource, delegate: RssManagerDelegate) async {
        let feedResults = await rssService.fetchItems(sources: [source])
        guard let feedResult = feedResults.first else {
            let fallback = RssUnsupportedResult(url: source.url, reason: .notRss)
            delegate.didReceiveUnsupported(fallback, source: source)
            return
        }
        guard let error = feedResult.error else {
            delegate.didReceiveFeedItems(feedResults, sources: [source])
            return
        }
        guard case .network(let underlying) = error else {
            let unsupported = RssUnsupportedResult(url: source.url, reason: .notRss)
            delegate.didReceiveUnsupported(unsupported, source: source)
            return
        }
        let unsupported = RssUnsupportedResult(url: source.url, reason: .network(underlying: underlying))
        delegate.didReceiveUnsupported(unsupported, source: source)
    }

    private func handleCatalog(_ source: RssSource, delegate: RssManagerDelegate) async {
        let catalogResult = await catalogService.fetchCatalog(from: source)
        guard let error = catalogResult.error else {
            delegate.didReceiveCatalog(catalogResult, source: source)
            return
        }
        let unsupported = RssUnsupportedResult(url: source.url, reason: unsupportedReason(for: error))
        delegate.didReceiveUnsupported(unsupported, source: source)
        return
    }

    private func unsupportedReason(for error: RssCatalogServiceError) -> RssUnsupportedReason {
        switch error {
        case .network(let underlying):
            return .network(underlying: underlying)
        case .parsing(let underlying):
            return .parsing(underlying: underlying)
        }
    }

    private func classify(_ url: URL) -> SourceClassification {
        let path = url.path.lowercased()
        if path.hasSuffix(Constants.rssSuffix) || path.hasSuffix(Constants.xmlSuffix) {
            return .feed
        }
        if path.contains(Constants.rssPathComponent) {
            return .catalog
        }
        return .catalog
    }
}

private enum SourceClassification {
    case feed
    case catalog
}
