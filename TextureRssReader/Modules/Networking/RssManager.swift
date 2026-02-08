//
//  RssManager.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 6.02.26.
//

import Foundation

protocol RssManagerDelegate {
    func didReceiveCatalog(_ result: RssCatalogResult, source: RssCatalogSource)
    func didReceiveFeedItems(_ result: [RssFeedResult], snapshots: [RssItemSnapshot])
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
                await handleFeed(
                    RssItemSnapshot(title: source.title, url: source.url), parentCatalog: source, delegate: delegate
                )
            }
        case .catalog:
            Task {
                await handleCatalog(source, delegate: delegate)
            }
        }
    }

    private func handleFeed(
        _ snapshot: RssItemSnapshot,
        parentCatalog: RssCatalogSource,
        delegate: RssManagerDelegate
    ) async {
        let feedResults = await rssService.fetchItems(snapshots: [snapshot], parentCatalog: parentCatalog)
        guard let feedResult = feedResults.first else {
            let fallback = RssUnsupportedResult(url: snapshot.url, reason: .notRss)
            delegate.didReceiveUnsupported(fallback, url: snapshot.url)
            return
        }
        guard let error = feedResult.error else {
            delegate.didReceiveFeedItems(feedResults, snapshots: [snapshot])
            return
        }
        guard case .network(let underlying) = error else {
            let unsupported = RssUnsupportedResult(url: snapshot.url, reason: .notRss)
            delegate.didReceiveUnsupported(unsupported, url: snapshot.url)
            return
        }
        let unsupported = RssUnsupportedResult(url: snapshot.url, reason: .network(underlying: underlying))
        delegate.didReceiveUnsupported(unsupported, url: snapshot.url)
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
