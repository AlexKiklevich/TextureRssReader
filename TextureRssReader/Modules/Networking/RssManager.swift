//
//  RssManager.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 6.02.26.
//

import Foundation

protocol RssManagerDelegate {
    func didReceiveCatalog(_ result: RssCatalogResult, source: RssCatalogSource)
    func didReceiveFeedItems(_ result: [RssFeedResult], sources: [RssItemSource])
    func didReceiveUnsupported(_ result: RssUnsupportedResult, url: URL)
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
    
    func performFetch(catalogs: [RssCatalogSource], delegate: RssManagerDelegate)  {
        for catalog in catalogs {
             handleSource(catalog, delegate: delegate)
        }
    }

    private func handleSource(_ source: RssCatalogSource, delegate: RssManagerDelegate)  {
        let classification = classify(source.url)
        switch classification {
        case .feed:
            Task {
                await handleFeed(RssItemSource(catalog: source, url: source.url), delegate: delegate)
            }
        case .catalog:
            Task {
                await handleCatalog(source, delegate: delegate)
            }
        }
    }

    private func handleFeed(_ source: RssItemSource, delegate: RssManagerDelegate) async {
        let feedResults = await rssService.fetchItems(sources: [source])
        guard let feedResult = feedResults.first else {
            let fallback = RssUnsupportedResult(url: source.url, reason: .notRss)
            delegate.didReceiveUnsupported(fallback, url: source.url)
            return
        }
        guard let error = feedResult.error else {
            delegate.didReceiveFeedItems(feedResults, sources: [source])
            return
        }
        guard case .network(let underlying) = error else {
            let unsupported = RssUnsupportedResult(url: source.url, reason: .notRss)
            delegate.didReceiveUnsupported(unsupported, url: source.url)
            return
        }
        let unsupported = RssUnsupportedResult(url: source.url, reason: .network(underlying: underlying))
        delegate.didReceiveUnsupported(unsupported, url: source.url)
    }

    private func handleCatalog(_ source: RssCatalogSource, delegate: RssManagerDelegate) async {
        let catalogResult = await catalogService.fetchCatalog(from: source)
        guard let error = catalogResult.error else {
            delegate.didReceiveCatalog(catalogResult, source: source)
            return
        }
        let unsupported = RssUnsupportedResult(url: source.url, reason: unsupportedReason(for: error))
        delegate.didReceiveUnsupported(unsupported, url: source.url)
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
