//
//  APIErrorTests.swift
//  Nature Image EvaluationTests
//
//  Created by Claude Code on 01/04/26.
//

@testable import Nature_Image_Evaluation
import XCTest

final class APIErrorTests: XCTestCase {
    // MARK: - Error Description Tests

    func testInvalidURL_HasDescription() {
        let error = APIError.invalidURL
        XCTAssertNotNil(error.errorDescription)
        XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
    }

    func testInvalidAPIKey_HasDescription() {
        let error = APIError.invalidAPIKey
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("API key") ?? false)
    }

    func testInvalidResponse_HasDescription() {
        let error = APIError.invalidResponse
        XCTAssertNotNil(error.errorDescription)
    }

    func testParsingFailed_HasDescription() {
        let error = APIError.parsingFailed("Test parsing error")
        XCTAssertNotNil(error.errorDescription)
    }

    func testRateLimitExceeded_WithRetryAfter_HasDescription() {
        let error = APIError.rateLimitExceeded(retryAfter: 30)
        XCTAssertNotNil(error.errorDescription)
    }

    func testRateLimitExceeded_WithoutRetryAfter_HasDescription() {
        let error = APIError.rateLimitExceeded(retryAfter: nil)
        XCTAssertNotNil(error.errorDescription)
    }

    func testAuthenticationFailed_HasDescription() {
        let error = APIError.authenticationFailed
        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription?.contains("Authentication") ?? false)
    }

    func testNetworkError_HasDescription() {
        let underlyingError = URLError(.notConnectedToInternet)
        let error = APIError.networkError(underlyingError)
        XCTAssertNotNil(error.errorDescription)
    }

    func testProviderSpecificError_HasDescription() {
        let error = APIError.providerSpecificError("Custom provider error")
        XCTAssertNotNil(error.errorDescription)
    }

    // MARK: - Error Pattern Matching Tests

    func testPatternMatching_InvalidURL() {
        let error = APIError.invalidURL
        if case APIError.invalidURL = error {
            // Success
        } else {
            XCTFail("Pattern should match invalidURL")
        }
    }

    func testPatternMatching_RateLimitExceededWithRetry() {
        let error = APIError.rateLimitExceeded(retryAfter: 60)
        if case let APIError.rateLimitExceeded(retry) = error {
            XCTAssertEqual(retry, 60)
        } else {
            XCTFail("Pattern should match rateLimitExceeded with retry value")
        }
    }

    func testPatternMatching_ParsingFailed() {
        let error = APIError.parsingFailed("Test message")
        if case let APIError.parsingFailed(message) = error {
            XCTAssertEqual(message, "Test message")
        } else {
            XCTFail("Pattern should match parsingFailed")
        }
    }

    func testPatternMatching_NetworkError() {
        let urlError = URLError(.timedOut)
        let error = APIError.networkError(urlError)
        if case let APIError.networkError(underlyingError) = error {
            XCTAssertTrue(underlyingError is URLError)
        } else {
            XCTFail("Pattern should match networkError")
        }
    }
}
