import Foundation
@preconcurrency import RealmSwift

final class RealmProvider: @unchecked Sendable {
    private let configuration: Realm.Configuration
    private let queue = DispatchQueue(label: "TextureRssReader.RealmProvider", qos: .utility)

    init(configuration: Realm.Configuration = .defaultConfiguration) {
        self.configuration = configuration
    }

    func save(items: [RssItem]) async throws {
        guard !items.isEmpty else { return }
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                autoreleasepool {
                    do {
                        let realm = try Realm(configuration: configuration)
                        let objects = items.map(StoredRssItem.init(item:))
                        try realm.write {
                            realm.add(objects, update: .modified)
                        }
                        continuation.resume(returning: ())
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    func read() async throws -> [RssItem] {
        let result: [RssItem] = try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                autoreleasepool {
                    do {
                        let realm = try Realm(configuration: configuration)
                        let objects = realm.objects(StoredRssItem.self)
                        continuation.resume(returning: objects.compactMap { $0.toRssItem() })
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
        return result
    }
}

@objc(StoredRssItem)
private final class StoredRssItem: Object {
    @Persisted(primaryKey: true) var id: String = ""
    @Persisted var title: String = ""
    @Persisted var link: String?
    @Persisted var summary: String?
    @Persisted var publishedAt: Date?
    @Persisted var imageURL: String?
    @Persisted var sourceTitle: String = ""
    @Persisted var sourceURL: String = ""
    @Persisted var storedAt: Date = Date()

    convenience init(item: RssItem) {
        self.init()
        id = Self.makeID(for: item)
        title = item.title
        link = item.link?.absoluteString
        summary = item.summary
        publishedAt = item.publishedAt
        imageURL = item.imageURL?.absoluteString
        sourceTitle = item.source.title
        sourceURL = item.source.url.absoluteString
        storedAt = Date()
    }

    func toRssItem() -> RssItem? {
        guard let sourceURL = URL(string: sourceURL) else { return nil }
        return RssItem(
            title: title,
            link: link.flatMap(URL.init(string:)),
            summary: summary,
            publishedAt: publishedAt,
            imageURL: imageURL.flatMap(URL.init(string:)),
            source: RssSource(title: sourceTitle, url: sourceURL)
        )
    }

    nonisolated private static func makeID(for item: RssItem) -> String {
        let sourcePart = item.source.url.absoluteString
        if let link = item.link?.absoluteString, !link.isEmpty {
            return sourcePart + "|" + link
        }
        let datePart = String(item.publishedAt?.timeIntervalSince1970 ?? 0)
        return sourcePart + "|" + item.title + "|" + datePart
    }
}
