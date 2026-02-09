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
}
