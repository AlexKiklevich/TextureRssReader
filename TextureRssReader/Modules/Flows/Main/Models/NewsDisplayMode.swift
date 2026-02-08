//
//  NewsDisplayMode.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 8.02.26.
//

import Foundation

enum NewsDisplayMode: Hashable {
    case common
    case extended

    mutating func toggle() {
        switch self {
        case .common:
            self = .extended
        case .extended:
            self = .common
        }
    }

    var navigationButtonTitle: String {
        switch self {
        case .common:
            return "Common"
        case .extended:
            return "Extended"
        }
    }

    var usesExtendedCell: Bool {
        self == .extended
    }
}
