//
//  DateFormatter.swift
//  TextureRssReader
//
//  Created by Aliaksandr Kiklevich on 6.02.26.
//

import Foundation

final class CommonDateFormatter {
    static let shared = CommonDateFormatter()
    
    private let backendFormatters: [DateFormatter]

    init() {
        func formatter(_ format: String) -> DateFormatter {
            let formatter = DateFormatter()
            formatter.locale = Locale.current
            formatter.timeZone = TimeZone.current
            formatter.dateFormat = format
            return formatter
        }

        backendFormatters = [
            formatter("EEE, dd MMM yyyy HH:mm:ss Z"),
            formatter("EEE, dd MMM yyyy HH:mm Z"),
            formatter("dd MMM yyyy HH:mm:ss Z"),
            formatter("yyyy-MM-dd'T'HH:mm:ssZ"),
            formatter("yyyy-MM-dd'T'HH:mm:ss.SSSZ")
        ]
    }

    func formatDate(fromString string: String) -> Date? {
        for formatter in backendFormatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }
    
    func formatString(fromDate date: Date) -> String {
        return date.formatted(.dateTime
            .day()
            .month(.abbreviated)
            .year()
            .hour()
            .minute()
        )
    }
}
