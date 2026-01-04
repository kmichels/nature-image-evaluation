//
//  MockURLSession.swift
//  Nature Image EvaluationTests
//
//  Created by Claude Code on 01/04/26.
//

import Foundation
@testable import Nature_Image_Evaluation

/// Protocol for URLSession to enable mocking
protocol URLSessionProtocol: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

/// Make URLSession conform to our protocol
extension URLSession: URLSessionProtocol {}

/// Mock URLSession for testing network calls without hitting real APIs
final class MockURLSession: URLSessionProtocol, @unchecked Sendable {
    var mockData: Data?
    var mockResponse: URLResponse?
    var mockError: Error?

    /// Configure mock to return a specific response
    func setMockResponse(data: Data?, statusCode: Int, headers: [String: String]? = nil) {
        mockData = data
        mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.anthropic.com/v1/messages")!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )
        mockError = nil
    }

    /// Configure mock to return an error
    func setMockError(_ error: Error) {
        mockData = nil
        mockResponse = nil
        mockError = error
    }

    func data(for _: URLRequest) async throws -> (Data, URLResponse) {
        if let error = mockError {
            throw error
        }

        guard let data = mockData, let response = mockResponse else {
            throw URLError(.unknown)
        }

        return (data, response)
    }
}

// MARK: - Mock Response Builders

enum MockAPIResponses {
    /// Valid evaluation response JSON
    static func validEvaluationResponse(
        compositionScore: Double = 8.5,
        qualityScore: Double = 9.0,
        sellabilityScore: Double = 7.5,
        artisticScore: Double = 8.0,
        overallScore: Double = 8.25,
        placement: String = "PORTFOLIO"
    ) -> Data {
        let json = """
        {
            "content": [
                {
                    "type": "text",
                    "text": "{\\"composition_score\\": \(compositionScore), \\"quality_score\\": \(qualityScore), \\"sellability_score\\": \(sellabilityScore), \\"artistic_score\\": \(artisticScore), \\"overall_weighted_score\\": \(overallScore), \\"primary_placement\\": \\"\(placement)\\", \\"strengths\\": [\\"Good composition\\", \\"Sharp focus\\"], \\"improvements\\": [\\"Consider better lighting\\"], \\"market_comparison\\": \\"Comparable to mid-tier stock imagery\\"}"
                }
            ],
            "usage": {
                "input_tokens": 1500,
                "output_tokens": 250
            }
        }
        """
        return json.data(using: .utf8)!
    }

    /// Response with commercial metadata (for STORE/BOTH placement)
    static func commercialResponse() -> Data {
        let json = """
        {
            "content": [
                {
                    "type": "text",
                    "text": "{\\"composition_score\\": 8.0, \\"quality_score\\": 8.5, \\"sellability_score\\": 9.0, \\"artistic_score\\": 7.5, \\"overall_weighted_score\\": 8.25, \\"primary_placement\\": \\"STORE\\", \\"strengths\\": [\\"Commercial appeal\\", \\"Clean composition\\"], \\"improvements\\": [\\"Add more negative space\\"], \\"market_comparison\\": \\"Strong commercial potential\\", \\"title\\": \\"Serene Mountain Lake\\", \\"description\\": \\"A peaceful mountain lake at sunrise\\", \\"keywords\\": [\\"nature\\", \\"mountain\\", \\"lake\\", \\"sunrise\\"], \\"alt_text\\": \\"Mountain lake with reflection at sunrise\\", \\"suggested_categories\\": [\\"Nature\\", \\"Landscape\\"], \\"best_use_cases\\": [\\"Website hero\\", \\"Print\\"], \\"suggested_price_tier\\": \\"MID\\"}"
                }
            ],
            "usage": {
                "input_tokens": 1600,
                "output_tokens": 300
            }
        }
        """
        return json.data(using: .utf8)!
    }

    /// Invalid score response (score out of range)
    static func invalidScoreResponse() -> Data {
        let json = """
        {
            "content": [
                {
                    "type": "text",
                    "text": "{\\"composition_score\\": 15.0, \\"quality_score\\": 9.0, \\"sellability_score\\": 7.5, \\"artistic_score\\": 8.0, \\"overall_weighted_score\\": 8.25, \\"primary_placement\\": \\"PORTFOLIO\\", \\"strengths\\": [\\"Test\\"], \\"improvements\\": [\\"Test\\"], \\"market_comparison\\": \\"Test\\"}"
                }
            ],
            "usage": {
                "input_tokens": 1500,
                "output_tokens": 250
            }
        }
        """
        return json.data(using: .utf8)!
    }

    /// Empty strengths response
    static func emptyStrengthsResponse() -> Data {
        let json = """
        {
            "content": [
                {
                    "type": "text",
                    "text": "{\\"composition_score\\": 8.0, \\"quality_score\\": 9.0, \\"sellability_score\\": 7.5, \\"artistic_score\\": 8.0, \\"overall_weighted_score\\": 8.25, \\"primary_placement\\": \\"PORTFOLIO\\", \\"strengths\\": [], \\"improvements\\": [\\"Test\\"], \\"market_comparison\\": \\"Test\\"}"
                }
            ],
            "usage": {
                "input_tokens": 1500,
                "output_tokens": 250
            }
        }
        """
        return json.data(using: .utf8)!
    }

    /// API error response
    static func errorResponse(type: String = "invalid_request_error", message: String = "Test error") -> Data {
        let json = """
        {
            "error": {
                "type": "\(type)",
                "message": "\(message)"
            }
        }
        """
        return json.data(using: .utf8)!
    }

    /// Rate limit headers
    static func rateLimitHeaders(
        requestsRemaining: Int = 100,
        tokensRemaining: Int = 50000,
        retryAfter: Int? = nil
    ) -> [String: String] {
        var headers: [String: String] = [
            "anthropic-ratelimit-requests-remaining": "\(requestsRemaining)",
            "anthropic-ratelimit-input-tokens-remaining": "\(tokensRemaining)",
            "anthropic-ratelimit-output-tokens-remaining": "\(tokensRemaining)",
        ]
        if let retry = retryAfter {
            headers["retry-after"] = "\(retry)"
        }
        return headers
    }
}
