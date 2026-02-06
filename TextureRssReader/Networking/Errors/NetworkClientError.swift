//
//  NetworkClientError.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 2.02.26.
//

enum NetworkClientError: Error, Hashable {
    case invalidResponse
    case statusCode(Int)
}
