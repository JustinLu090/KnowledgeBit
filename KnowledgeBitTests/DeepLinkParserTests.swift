import XCTest
@testable import KnowledgeBit

final class DeepLinkParserTests: XCTestCase {

  func testParseWordSetURLSuccess() throws {
    let id = UUID()
    let url = try XCTUnwrap(URL(string: "knowledgebit://wordSet?wordSetId=\(id.uuidString)"))
    XCTAssertEqual(DeepLinkParser.parseWordSetURL(url), id)
  }

  func testParseWordSetURLWrongScheme() throws {
    let id = UUID()
    let url = try XCTUnwrap(URL(string: "http://wordSet?wordSetId=\(id.uuidString)"))
    XCTAssertNil(DeepLinkParser.parseWordSetURL(url))
  }

  func testParseWordSetURLInvalidUUID() throws {
    let url = try XCTUnwrap(URL(string: "knowledgebit://wordSet?wordSetId=not-a-uuid"))
    XCTAssertNil(DeepLinkParser.parseWordSetURL(url))
  }

  func testParseBattleURLSuccess() throws {
    let id = UUID()
    let url = try XCTUnwrap(URL(string: "knowledgebit://battle?wordSetId=\(id.uuidString)"))
    XCTAssertEqual(DeepLinkParser.parseBattleURL(url), id)
  }

  func testParseBattleURLWrongHost() throws {
    let id = UUID()
    let url = try XCTUnwrap(URL(string: "knowledgebit://wordset?wordSetId=\(id.uuidString)"))
    XCTAssertNil(DeepLinkParser.parseBattleURL(url))
  }

  func testParseInviteURLHttpsJoinPath() throws {
    let url = try XCTUnwrap(URL(string: "https://knowledgebit-link-proxy.vercel.app/join/my_invite-1"))
    let parsed = DeepLinkParser.parseInviteURL(url)
    XCTAssertEqual(parsed?.code, "my_invite-1")
  }

  func testParseInviteURLCustomScheme() throws {
    let url = try XCTUnwrap(URL(string: "knowledgebit://join/abc123"))
    let parsed = DeepLinkParser.parseInviteURL(url)
    XCTAssertEqual(parsed?.code, "abc123")
  }

  func testParseInviteURLRejectsInvalidCharacters() throws {
    let url = try XCTUnwrap(URL(string: "https://knowledgebit-link-proxy.vercel.app/join/bad@code"))
    XCTAssertNil(DeepLinkParser.parseInviteURL(url))
  }

  func testParseInviteURLRejectsTooLongCode() throws {
    let longCode = String(repeating: "a", count: 33)
    let url = try XCTUnwrap(URL(string: "https://knowledgebit-link-proxy.vercel.app/join/\(longCode)"))
    XCTAssertNil(DeepLinkParser.parseInviteURL(url))
  }
}
