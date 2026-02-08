//
//  NewsRowModel.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 8.02.26.
//

import Foundation

struct NewsRowModel: Hashable, Identifiable {
    let id: UUID
    let title: String
    let summary: String?
    let imageURL: URL?

    init(
        id: UUID = UUID(),
        title: String,
        summary: String? = nil,
        imageURL: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.imageURL = imageURL
    }
}
