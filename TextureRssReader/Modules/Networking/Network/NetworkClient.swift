//
//  NetworkClient.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 2.02.26.
//

import Foundation

protocol NetworkClient {
    func data(from url: URL) async throws -> Data
}
