//
//  RssCatalogServiceError.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 6.02.26.
//

enum RssCatalogServiceError: Error, Hashable {
    case network(underlying: String)
    case parsing(underlying: String)

    init(networkError: Error) {
        self = .network(underlying: String(describing: networkError))
    }

    init(parsingError: Error) {
        self = .parsing(underlying: String(describing: parsingError))
    }
}
