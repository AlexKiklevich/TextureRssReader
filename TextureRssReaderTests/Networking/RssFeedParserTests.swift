import XCTest
@testable import TextureRssReader

final class RssFeedParserTests: XCTestCase {
    func testParseItemsFromFixture() throws {
        let data = try fixtureData(named: "rss_sample_1")
        let parser = RssFeedParser()

        let items = try parser.parse(data: data)

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].title, "First Item")
        XCTAssertEqual(items[0].guid, "first-guid")
        XCTAssertEqual(items[0].link?.absoluteString, "https://example.com/first")
        XCTAssertEqual(items[0].summary, "Summary 1")
        XCTAssertEqual(items[0].imageURL?.absoluteString, "https://example.com/first.jpg")
        XCTAssertNotNil(items[0].publishedAt)
        XCTAssertEqual(items[1].imageURL?.absoluteString, "https://example.com/second.jpg")
    }

    func testContentEncodedOverridesDescription() throws {
        let data = try fixtureData(named: "rss_sample_2")
        let parser = RssFeedParser()

        let items = try parser.parse(data: data)

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].summary, "Full content summary")
    }

    private func fixtureData(named name: String) throws -> Data {
        let bundle = Bundle(for: Self.self)
        guard let url = bundle.url(forResource: name, withExtension: "xml") else {
            throw XCTestError(.failureWhileWaiting, userInfo: [NSLocalizedDescriptionKey: "Missing fixture: \(name).xml"])
        }
        return try Data(contentsOf: url)
    }
}
