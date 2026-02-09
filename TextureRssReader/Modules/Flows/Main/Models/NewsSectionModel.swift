//
//  NewsSectionModel.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 8.02.26.
//

import Foundation

struct NewsSectionModel: Hashable, Identifiable {
    let id: UUID
    let title: String
    var isExpanded: Bool
    var items: [NewsRowModel]

    init(
        id: UUID = UUID(),
        title: String,
        isExpanded: Bool = true,
        items: [NewsRowModel]
    ) {
        self.id = id
        self.title = title
        self.isExpanded = isExpanded
        self.items = items
    }

    var visibleItems: [NewsRowModel] {
        isExpanded ? items : []
    }
}
