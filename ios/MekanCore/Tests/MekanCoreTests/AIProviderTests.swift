import XCTest
@testable import MekanCore

final class AIProviderTests: XCTestCase {
    func testDetectsPollinationsSecretKey() {
        XCTAssertEqual(AIProviderKind.detect(key: "sk_AbC123xyz789qwe456rty"), .pollinations)
    }

    func testDetectsOpenAIKey() {
        XCTAssertEqual(AIProviderKind.detect(key: "sk-proj-AbC123xyz789qwe456rty"), .openai)
    }

    func testTrimsWhitespaceAroundCopiedKey() {
        XCTAssertEqual(AIProviderKind.detect(key: "  sk_AbC123xyz789qwe456rty\n"), .pollinations)
    }

    func testRejectsNonKeysAndPublishableKeys() {
        XCTAssertNil(AIProviderKind.detect(key: "merhaba dünya"))
        XCTAssertNil(AIProviderKind.detect(key: "sk_kisa"))               // too short to be real
        XCTAssertNil(AIProviderKind.detect(key: "pk_AbC123xyz789qwe456rty")) // publishable, can't authenticate
        XCTAssertNil(AIProviderKind.detect(key: "sk_abc def ghi jkl mno pq")) // contains spaces
    }

    func testPollinationsDefaultModelIsFreeEditingModel() {
        XCTAssertEqual(AIProviderKind.pollinations.defaultModel, "microsoft/mai-image-2.6-flash")
        XCTAssertEqual(AIProviderKind.pollinations.baseURL.absoluteString, "https://gen.pollinations.ai/v1/images/")
        XCTAssertEqual(AIProviderKind.openai.baseURL.absoluteString, "https://api.openai.com/v1/images/")
    }
}
