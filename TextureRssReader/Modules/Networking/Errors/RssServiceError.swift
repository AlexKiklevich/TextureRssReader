//
//  RssServiceError.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 2.02.26.
//

enum RssServiceError: Error, Hashable {
    case invalidResponse
    case network(underlying: String)
    case parsing(underlying: String)

    init(networkError: Error) {
        self = .network(underlying: String(describing: networkError))
    }

    init(parsingError: Error) {
        self = .parsing(underlying: String(describing: parsingError))
    }
}
