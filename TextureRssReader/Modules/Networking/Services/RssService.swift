//
//  DefaultRssService.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 2.02.26.
//

import Foundation

protocol RssService {
    func fetchItems(sources: [RssSource]) async -> [RssFeedResult]
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

    func fetchItems(sources: [RssSource]) async -> [RssFeedResult] {
        await withTaskGroup(of: RssFeedResult.self) { group in
            for source in sources {
                group.addTask { [networkClient, parserFactory] in
                    await self.fetch(
                        source: source,
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
        source: RssSource,
        networkClient: NetworkClient,
        parser: RssFeedParser
    ) async -> RssFeedResult {
        let data: Data
        do {
            data = try await networkClient.data(from: source.url)
        } catch let error as NetworkClientError {
            return RssFeedResult(source: source, items: [], error: RssServiceError(networkError: error))
        } catch {
            return RssFeedResult(source: source, items: [], error: RssServiceError(networkError: error))
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
                    source: source
                )
            }
            return RssFeedResult(source: source, items: items, error: nil)
        } catch let error as RssParsingError {
            return RssFeedResult(source: source, items: [], error: RssServiceError(parsingError: error))
        } catch {
            return RssFeedResult(source: source, items: [], error: RssServiceError(parsingError: error))
        }
    }
}
