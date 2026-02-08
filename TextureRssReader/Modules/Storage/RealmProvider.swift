import Foundation
@preconcurrency import RealmSwift

final class RealmProvider: @unchecked Sendable {
    
    struct ReadResult {
        let catalog: RssCatalogSource
        let rssItems: [RssItem]
    }
    
    private let configuration: Realm.Configuration
    private let queue = DispatchQueue(label: "TextureRssReader.RealmProvider", qos: .utility)

    init(configuration: Realm.Configuration = .defaultConfiguration) {
        self.configuration = configuration
    }

    func saveRss(items: [RssItem]) async throws {
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

    func readRss(catalogs: [RssCatalogSource]) async throws -> [ReadResult] {
        let result: [ReadResult] = try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                autoreleasepool {
                    do {
                        let realm = try Realm(configuration: configuration)
                        let objects = realm.objects(StoredRssItem.self)
                        var results = [ReadResult]()
                        for catalog in catalogs {
                            let items = objects.filter("catalogURL == %@", catalog.url.absoluteString)
                            results.append(ReadResult(catalog: catalog, rssItems: items.compactMap { $0.toRssItem() }))
                        }
                        continuation.resume(returning: results)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
        return result
    }

    func saveCatalog(result: RssCatalogResult) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                autoreleasepool {
                    do {
                        let realm = try Realm(configuration: configuration)
                        let object = StoredRssCatalog(result: result)
                        try realm.write {
                            let duplicates = realm.objects(StoredRssCatalog.self)
                                .filter("catalogSourceURL == %@", result.catalogSource.url.absoluteString)
                            if !duplicates.isEmpty {
                                realm.delete(duplicates)
                            }
                            realm.add(object, update: .modified)
                        }
                        continuation.resume(returning: ())
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    func readCatalog(source: RssCatalogSource) async throws -> RssCatalogResult? {
        let result: RssCatalogResult? = try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                autoreleasepool {
                    do {
                        let realm = try Realm(configuration: configuration)
                        let object = realm.objects(StoredRssCatalog.self)
                            .filter("catalogSourceURL == %@", source.url.absoluteString)
                            .first
                        continuation.resume(returning: object?.toRssCatalogResult())
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
        return result
    }
}
