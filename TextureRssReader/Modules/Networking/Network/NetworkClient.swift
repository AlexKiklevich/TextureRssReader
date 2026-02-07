//
//  URLSessionNetworkClient.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 2.02.26.
//

import Foundation

protocol NetworkClient {
    func data(from url: URL) async throws -> Data
}

final class URLSessionNetworkClient: NetworkClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func data(from url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkClientError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkClientError.statusCode(httpResponse.statusCode)
        }
        return data
    }
}
