//
//  DefaultRssCatalogService.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 6.02.26.
//

import Foundation

protocol RssCatalogService {
    func fetchCatalog(from source: RssCatalogSource) async -> RssCatalogResult
}

final class DefaultRssCatalogService: RssCatalogService {
    private let networkClient: NetworkClient
    private let parser: RssCatalogParser

    init(
        networkClient: NetworkClient = URLSessionNetworkClient(),
        parser: RssCatalogParser = RssCatalogParser()
    ) {
        self.networkClient = networkClient
        self.parser = parser
    }

    func fetchCatalog(from source: RssCatalogSource) async -> RssCatalogResult {
        let data: Data
        do {
            data = try await networkClient.data(from: source.url)
        } catch let error as NetworkClientError {
            return RssCatalogResult(
                catalogSource: source,
                rssSnapshots: [],
                error: RssCatalogServiceError(networkError: error)
            )
        } catch {
            return RssCatalogResult(
                catalogSource: source,
                rssSnapshots: [],
                error: RssCatalogServiceError(networkError: error)
            )
        }

        do {
            let items = try parser.parse(data: data, baseURL: source.url)
            return RssCatalogResult(catalogSource: source, rssSnapshots: items, error: nil)
        } catch let error as RssCatalogParsingError {
            return RssCatalogResult(
                catalogSource: source,
                rssSnapshots: [],
                error: RssCatalogServiceError(parsingError: error)
            )
        } catch {
            return RssCatalogResult(
                catalogSource: source,
                rssSnapshots: [],
                error: RssCatalogServiceError(parsingError: error)
            )
        }
    }
}
