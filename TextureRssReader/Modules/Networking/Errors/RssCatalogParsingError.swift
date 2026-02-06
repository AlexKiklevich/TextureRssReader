//
//  RssCatalogParsingError.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 6.02.26.
//

enum RssCatalogParsingError: Error, Hashable {
    case invalidEncoding
    case parsingFailed
}
