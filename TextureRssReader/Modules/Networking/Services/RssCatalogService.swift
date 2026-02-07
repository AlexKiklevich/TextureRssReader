//
//  DefaultRssCatalogService.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 6.02.26.
//

import Foundation

protocol RssCatalogService {
    func fetchCatalog(from url: URL) async -> RssCatalogResult
}

final class DefaultRssCatalogService: RssCatalogService {
    private let networkClient: NetworkClient
    private let parserFactory: () -> RssCatalogParser

    init(
        networkClient: NetworkClient = URLSessionNetworkClient(),
        parserFactory: @escaping () -> RssCatalogParser = { RssCatalogParser() }
    ) {
        self.networkClient = networkClient
        self.parserFactory = parserFactory
    }

    func fetchCatalog(from url: URL) async -> RssCatalogResult {
        let data: Data
        do {
            data = try await networkClient.data(from: url)
        } catch let error as NetworkClientError {
            return RssCatalogResult(catalogURL: url, sources: [], error: RssCatalogServiceError(networkError: error))
        } catch {
            return RssCatalogResult(catalogURL: url, sources: [], error: RssCatalogServiceError(networkError: error))
        }

        do {
            let sources = try parserFactory().parse(data: data, baseURL: url)
            return RssCatalogResult(catalogURL: url, sources: sources, error: nil)
        } catch let error as RssCatalogParsingError {
            return RssCatalogResult(catalogURL: url, sources: [], error: RssCatalogServiceError(parsingError: error))
        } catch {
            return RssCatalogResult(catalogURL: url, sources: [], error: RssCatalogServiceError(parsingError: error))
        }
    }
}
