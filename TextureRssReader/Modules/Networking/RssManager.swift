//
//  RssManager.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 6.02.26.
//

import Foundation

protocol RssManagerDelegate {
    func didStartLoading()
    func didFinishLoading()
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
    private let realmProvider: RealmProvider
    private let userDefaultsProvider: UserDefaultsProvider
    
    init(realmProvider: RealmProvider, userDefaultsProvider: UserDefaultsProvider) {
        self.realmProvider = realmProvider
        self.userDefaultsProvider = userDefaultsProvider
        self.catalogService = DefaultRssCatalogService(networkClient: networkClient)
        self.rssService = DefaultRssService(networkClient: networkClient)
    }
    
    func downloadStoredCatalogs(delegate: RssManagerDelegate) {
        Task {
            delegate.didStartLoading()
            defer {
                delegate.didFinishLoading()
            }
            do {
                guard let catalogs = try await realmProvider.readCatalogs() else {
                    await fetchDefaultCatalogs(delegate: delegate)
                    return
                }
                guard !catalogs.isEmpty else {
                    guard !userDefaultsProvider.getHasLaunchedBefore() else {
                        return
                    }
                    userDefaultsProvider.set(hasLaunchedBefore: true)
                    await fetchDefaultCatalogs(delegate: delegate)
                    return
                }

                guard catalogs.contains(where: { !$0.rssSnapshots.isEmpty }) else {
                    await fetchDefaultCatalogs(delegate: delegate)
                    return
                }
                for catalog in catalogs {
                    await fetchFeedSnapshots(
                        catalog.rssSnapshots,
                        parentSource: catalog.catalogSource,
                        delegate: delegate
                    )
                }
            }
            catch {
                await fetchDefaultCatalogs(delegate: delegate)
            }
        }
    }
    
    private func fetchDefaultCatalogs(delegate: RssManagerDelegate) async {
        let defaultCatalogs = DefaultCatalogs.array
        await fetchSources(defaultCatalogs, delegate: delegate)
    }
    
    func performFetch(catalogs: [RssCatalogSource], delegate: RssManagerDelegate)  {
        Task {
            delegate.didStartLoading()
            defer {
                delegate.didFinishLoading()
            }
            await fetchSources(catalogs, delegate: delegate)
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
            do {
                try await realmProvider.saveCatalog(result: catalogResult)
            } catch {
            }
            delegate.didReceiveCatalog(catalogResult, source: source)
            await fetchFeedSnapshots(catalogResult.rssSnapshots, parentSource: source, delegate: delegate)
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

    private func fetchSources(_ catalogs: [RssCatalogSource], delegate: RssManagerDelegate) async {
        for catalog in catalogs {
            let classification = classify(catalog.url)
            switch classification {
            case .feed:
                await upsertFeedCatalogResult(for: catalog)
                await handleFeed(
                    RssItemSnapshot(title: catalog.title, url: catalog.url),
                    parentCatalog: catalog,
                    delegate: delegate
                )
            case .catalog:
                await handleCatalog(catalog, delegate: delegate)
            }
        }
    }

    private func fetchFeedSnapshots(
        _ snapshots: [RssItemSnapshot],
        parentSource: RssCatalogSource,
        delegate: RssManagerDelegate
    ) async {
        for snapshot in snapshots {
            let feedSource = RssCatalogSource(
                title: "\(parentSource.title). \(snapshot.title)",
                url: snapshot.url
            )
            let feedSnapshot = RssItemSnapshot(title: feedSource.title, url: feedSource.url)
            await handleFeed(feedSnapshot, parentCatalog: feedSource, delegate: delegate)
        }
    }

    private func upsertFeedCatalogResult(for source: RssCatalogSource) async {
        let sourceSnapshot = RssItemSnapshot(title: source.title, url: source.url)
        do {
            let existingResult = try await realmProvider.readCatalog(source: source)
            let snapshots = mergeSnapshots(
                existingResult?.rssSnapshots ?? [],
                with: [sourceSnapshot]
            )
            let catalogSource = existingResult?.catalogSource ?? source
            let updatedResult = RssCatalogResult(
                catalogSource: catalogSource,
                rssSnapshots: snapshots,
                error: nil
            )
            try await realmProvider.saveCatalog(result: updatedResult)
        } catch {
        }
    }

    private func mergeSnapshots(
        _ existing: [RssItemSnapshot],
        with incoming: [RssItemSnapshot]
    ) -> [RssItemSnapshot] {
        var snapshotByURL: [String: RssItemSnapshot] = [:]
        for snapshot in existing {
            snapshotByURL[snapshot.url.absoluteString] = snapshot
        }
        for snapshot in incoming {
            snapshotByURL[snapshot.url.absoluteString] = snapshot
        }

        var orderedSnapshots: [RssItemSnapshot] = []
        var seenURLs = Set<String>()

        for snapshot in existing {
            let key = snapshot.url.absoluteString
            guard let merged = snapshotByURL[key], seenURLs.insert(key).inserted else {
                continue
            }
            orderedSnapshots.append(merged)
        }

        for snapshot in incoming {
            let key = snapshot.url.absoluteString
            guard let merged = snapshotByURL[key], seenURLs.insert(key).inserted else {
                continue
            }
            orderedSnapshots.append(merged)
        }

        return orderedSnapshots
    }
}

private enum SourceClassification {
    case feed
    case catalog
}
