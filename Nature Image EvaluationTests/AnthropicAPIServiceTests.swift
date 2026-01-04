//
//  AnthropicAPIServiceTests.swift
//  Nature Image EvaluationTests
//
//  Created by Claude Code on 01/04/26.
//

@testable import Nature_Image_Evaluation
import XCTest

final class AnthropicAPIServiceTests: XCTestCase {
    var sut: AnthropicAPIService!

    override func setUp() {
        super.setUp()
        sut = AnthropicAPIService()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - parseResponse Tests

    func testParseResponse_ValidResponse_ReturnsEvaluationResponse() throws {
        let json = MockAPIResponses.validEvaluationResponse()

        let result = try sut.parseResponse(json)

        XCTAssertEqual(result.compositionScore, 8.5)
        XCTAssertEqual(result.qualityScore, 9.0)
        XCTAssertEqual(result.sellabilityScore, 7.5)
        XCTAssertEqual(result.artisticScore, 8.0)
        XCTAssertEqual(result.overallWeightedScore, 8.25)
        XCTAssertEqual(result.primaryPlacement, "PORTFOLIO")
        XCTAssertEqual(result.strengths.count, 2)
        XCTAssertEqual(result.improvements.count, 1)
    }

    func testParseResponse_CommercialResponse_ReturnsMetadata() throws {
        let json = MockAPIResponses.commercialResponse()

        let result = try sut.parseResponse(json)

        XCTAssertEqual(result.primaryPlacement, "STORE")
        XCTAssertEqual(result.title, "Serene Mountain Lake")
        XCTAssertEqual(result.descriptionText, "A peaceful mountain lake at sunrise")
        XCTAssertNotNil(result.keywords)
        XCTAssertEqual(result.keywords?.count, 4)
        XCTAssertEqual(result.suggestedPriceTier, "MID")
    }

    func testParseResponse_InvalidJSON_ThrowsError() {
        let invalidData = "not json".data(using: .utf8)!

        // parseResponse throws DecodingError for invalid JSON (not wrapped in APIError)
        XCTAssertThrowsError(try sut.parseResponse(invalidData))
    }

    func testParseResponse_MalformedResponse_ThrowsError() {
        // parseResponse expects AnthropicResponse format, not error responses
        // Error responses are handled in performRequestWithRetry, not parseResponse
        let malformedData = "{}".data(using: .utf8)!

        XCTAssertThrowsError(try sut.parseResponse(malformedData))
    }

    // MARK: - calculateCost Tests

    func testCalculateCost_StandardTokens_ReturnsCorrectCost() {
        let inputTokens = 1000
        let outputTokens = 500

        let cost = sut.calculateCost(inputTokens: inputTokens, outputTokens: outputTokens)

        // Using Constants for cost calculation
        let expectedInputCost = (Double(inputTokens) / 1_000_000) * Constants.anthropicInputTokenCostPerMillion
        let expectedOutputCost = (Double(outputTokens) / 1_000_000) * Constants.anthropicOutputTokenCostPerMillion
        let expectedTotal = expectedInputCost + expectedOutputCost

        XCTAssertEqual(cost, expectedTotal, accuracy: 0.000001)
    }

    func testCalculateCost_ZeroTokens_ReturnsZero() {
        let cost = sut.calculateCost(inputTokens: 0, outputTokens: 0)
        XCTAssertEqual(cost, 0)
    }

    func testCalculateCost_LargeTokenCount_ReturnsCorrectCost() {
        let inputTokens = 100_000
        let outputTokens = 50000

        let cost = sut.calculateCost(inputTokens: inputTokens, outputTokens: outputTokens)

        XCTAssertGreaterThan(cost, 0)
    }

    // MARK: - extractRateLimitInfo Tests

    func testExtractRateLimitInfo_ValidHeaders_ReturnsInfo() {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        let headers = MockAPIResponses.rateLimitHeaders(
            requestsRemaining: 100,
            tokensRemaining: 50000
        )
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!

        let info = sut.extractRateLimitInfo(from: response)

        XCTAssertNotNil(info)
        XCTAssertEqual(info?.requestsRemaining, 100)
        XCTAssertEqual(info?.inputTokensRemaining, 50000)
    }

    func testExtractRateLimitInfo_WithRetryAfter_IncludesRetryTime() {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        let headers = MockAPIResponses.rateLimitHeaders(
            requestsRemaining: 0,
            tokensRemaining: 0,
            retryAfter: 30
        )
        let response = HTTPURLResponse(
            url: url,
            statusCode: 429,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!

        let info = sut.extractRateLimitInfo(from: response)

        XCTAssertNotNil(info)
        XCTAssertEqual(info?.requestsRemaining, 0)
        XCTAssertEqual(info?.retryAfter, 30)
    }

    func testExtractRateLimitInfo_NoHeaders_ReturnsObjectWithNilFields() {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        )!

        let info = sut.extractRateLimitInfo(from: response)

        // extractRateLimitInfo always returns a RateLimitInfo, but with nil fields when no headers
        XCTAssertNotNil(info)
        XCTAssertNil(info?.requestsRemaining)
        XCTAssertNil(info?.inputTokensRemaining)
        XCTAssertNil(info?.retryAfter)
    }
}
