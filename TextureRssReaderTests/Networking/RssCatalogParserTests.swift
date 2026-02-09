import XCTest
@testable import TextureRssReader

final class RssCatalogParserTests: XCTestCase {
    func testParseCatalogUsesNearestLabelAndResolvesRelativeURLs() throws {
        let data = try fixtureData(named: "rss_catalog_vedomosti")
        let parser = RssCatalogParser()
        let baseURL = URL(string: "https://www.vedomosti.ru/info/rss")!

        let sources = try parser.parse(data: data, baseURL: baseURL)

        XCTAssertEqual(sources.count, 2)
        XCTAssertEqual(sources[0].title, "Все новости")
        XCTAssertEqual(sources[0].url.absoluteString, "https://www.vedomosti.ru/rss/news")
        XCTAssertEqual(sources[1].title, "Политика")
        XCTAssertEqual(sources[1].url.absoluteString, "https://www.vedomosti.ru/rss/politics")
    }

    func testParseCatalogUsesAnchorTextWhenAvailable() throws {
        let html = "<a href=\"https://example.com/rss/main\">Main feed</a>"
        let data = Data(html.utf8)
        let parser = RssCatalogParser()

        let sources = try parser.parse(data: data, baseURL: nil)

        XCTAssertEqual(sources.count, 1)
        XCTAssertEqual(sources[0].title, "Main feed")
        XCTAssertEqual(sources[0].url.absoluteString, "https://example.com/rss/main")
    }

    private func fixtureData(named name: String) throws -> Data {
        let bundle = Bundle(for: Self.self)
        guard let url = bundle.url(forResource: name, withExtension: "html") else {
            throw XCTestError(.failureWhileWaiting, userInfo: [NSLocalizedDescriptionKey: "Missing fixture: \(name).html"])
        }
        return try Data(contentsOf: url)
    }
}
