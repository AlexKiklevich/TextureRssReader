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
    
    func readCatalogs() async throws -> [RssCatalogResult]? {
        let result: [RssCatalogResult]? = try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                autoreleasepool {
                    do {
                        let realm = try Realm(configuration: configuration)
                        let objects: [RssCatalogResult] = realm.objects(StoredRssCatalog.self).compactMap{ $0.toRssCatalogResult() }
                        continuation.resume(returning: objects)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
        return result
    }

    func upsertCatalogSource(_ source: RssCatalogSource) async throws {
        if let existing = try await readCatalog(source: source) {
            let updated = RssCatalogResult(
                catalogSource: source,
                rssSnapshots: existing.rssSnapshots,
                error: nil
            )
            try await saveCatalog(result: updated)
            return
        }
        let newResult = RssCatalogResult(
            catalogSource: source,
            rssSnapshots: [],
            error: nil
        )
        try await saveCatalog(result: newResult)
    }

    func deleteCatalog(source: RssCatalogSource) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                autoreleasepool {
                    do {
                        let realm = try Realm(configuration: configuration)
                        let sourceURL = source.url.absoluteString
                        let catalogs = realm.objects(StoredRssCatalog.self)
                            .filter("catalogSourceURL == %@", sourceURL)
                        let items = realm.objects(StoredRssItem.self)
                            .filter("catalogURL == %@", sourceURL)

                        try realm.write {
                            if !catalogs.isEmpty {
                                realm.delete(catalogs)
                            }
                            if !items.isEmpty {
                                realm.delete(items)
                            }
                        }
                        continuation.resume(returning: ())
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    func readCatalogSources() async throws -> [RssCatalogSource] {
        let catalogs = try await readCatalogs() ?? []
        var uniqueSources: [RssCatalogSource] = []
        var seenURLs = Set<String>()

        for catalog in catalogs {
            let source = catalog.catalogSource
            let key = source.url.absoluteString
            guard seenURLs.insert(key).inserted else { continue }
            uniqueSources.append(source)
        }
        return uniqueSources
    }

    func deleteAllData() async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                autoreleasepool {
                    do {
                        let realm = try Realm(configuration: configuration)
                        let catalogs = realm.objects(StoredRssCatalog.self)
                        let items = realm.objects(StoredRssItem.self)

                        try realm.write {
                            if !catalogs.isEmpty {
                                realm.delete(catalogs)
                            }
                            if !items.isEmpty {
                                realm.delete(items)
                            }
                        }
                        continuation.resume(returning: ())
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
}
