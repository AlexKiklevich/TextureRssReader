//
//  DefaultRssService.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 2.02.26.
//

import Foundation

protocol RssService {
    func fetchItems(snapshots: [RssItemSnapshot], parentCatalog: RssCatalogSource) async -> [RssFeedResult]
}

final class DefaultRssService: RssService {
    private let networkClient: NetworkClient
    private let parserFactory: () -> RssFeedParser

    init(
        networkClient: NetworkClient = URLSessionNetworkClient(),
        parserFactory: @escaping () -> RssFeedParser = { RssFeedParser() }
    ) {
        self.networkClient = networkClient
        self.parserFactory = parserFactory
    }

    func fetchItems(snapshots: [RssItemSnapshot], parentCatalog: RssCatalogSource) async -> [RssFeedResult] {
        await withTaskGroup(of: RssFeedResult.self) { group in
            for snapshot in snapshots {
                group.addTask { [networkClient, parserFactory] in
                    await self.fetch(
                        snapshot: snapshot,
                        parentCatalog: parentCatalog,
                        networkClient: networkClient,
                        parser: parserFactory()
                    )
                }
            }

            var results: [RssFeedResult] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
    }

    private func fetch(
        snapshot: RssItemSnapshot,
        parentCatalog: RssCatalogSource,
        networkClient: NetworkClient,
        parser: RssFeedParser
    ) async -> RssFeedResult {
        let data: Data
        do {
            data = try await networkClient.data(from: snapshot.url)
        } catch let error as NetworkClientError {
            return RssFeedResult(
                snapshot: snapshot,
                items: [],
                parentCatalog: parentCatalog,
                error: RssServiceError(networkError: error)
            )
        } catch {
            return RssFeedResult(
                snapshot: snapshot,
                items: [],
                parentCatalog: parentCatalog,
                error: RssServiceError(networkError: error)
            )
        }

        do {
            let parsedItems = try parser.parse(data: data)
            let items = parsedItems.map { parsed in
                RssItem(
                    title: parsed.title,
                    link: parsed.link,
                    summary: parsed.summary,
                    publishedAt: parsed.publishedAt,
                    imageURL: parsed.imageURL,
                    parentCatalog: parentCatalog
                )
            }
            return RssFeedResult(snapshot: snapshot, items: items, parentCatalog: parentCatalog, error: nil)
        } catch let error as RssParsingError {
            return RssFeedResult(
                snapshot: snapshot,
                items: [],
                parentCatalog: parentCatalog,
                error: RssServiceError(parsingError: error)
            )
        } catch {
            return RssFeedResult(
                snapshot: snapshot,
                items: [],
                parentCatalog: parentCatalog,
                error: RssServiceError(parsingError: error)
            )
        }
    }
}
