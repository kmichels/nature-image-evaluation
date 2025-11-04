//
//  APIProviderProtocol.swift
//  Nature Image Evaluation
//
//  Created by Claude Code on 10/27/25.
//

import Foundation

/// Protocol that all API providers must conform to
protocol APIProviderProtocol {
    /// The provider type
    var provider: Constants.APIProvider { get }

    /// Evaluate an image using the provider's API
    /// - Parameters:
    ///   - imageBase64: Base64 encoded image
    ///   - prompt: The evaluation prompt
    ///   - apiKey: API key for authentication
    ///   - model: The model identifier to use (optional, uses default if nil)
    /// - Returns: Evaluation response
    func evaluateImage(
        imageBase64: String,
        prompt: String,
        apiKey: String,
        model: String?
    ) async throws -> EvaluationResponse

    /// Parse the provider's response into our standard format
    /// - Parameter response: Raw response from API
    /// - Returns: Parsed evaluation response
    func parseResponse(_ response: Data) throws -> EvaluationResponse

    /// Calculate cost based on token usage
    /// - Parameters:
    ///   - inputTokens: Number of input tokens
    ///   - outputTokens: Number of output tokens
    /// - Returns: Estimated cost in dollars
    func calculateCost(inputTokens: Int, outputTokens: Int) -> Double

    /// Extract rate limit information from response headers
    /// - Parameter response: HTTP response
    /// - Returns: Rate limit information if available
    func extractRateLimitInfo(from response: HTTPURLResponse) -> RateLimitInfo?
}

// MARK: - Common Response Models

/// Standardized evaluation response
struct EvaluationResponse {
    let compositionScore: Double
    let qualityScore: Double
    let sellabilityScore: Double
    let artisticScore: Double
    let overallWeightedScore: Double
    let primaryPlacement: String
    let strengths: [String]
    let improvements: [String]
    let marketComparison: String
    let technicalInnovations: [String]?
    let printSizeRecommendation: String?
    let priceTierSuggestion: String?

    // Commercial metadata (for STORE or BOTH placement)
    let title: String?
    let descriptionText: String?
    let keywords: [String]?
    let altText: String?
    let suggestedCategories: [String]?
    let bestUseCases: [String]?
    let suggestedPriceTier: String?

    // API usage
    let inputTokens: Int
    let outputTokens: Int
    let rawResponse: String
}

/// Rate limit information
struct RateLimitInfo {
    let requestsRemaining: Int?
    let inputTokensRemaining: Int?
    let outputTokensRemaining: Int?
    let requestsReset: Date?
    let tokensReset: Date?
    let retryAfter: TimeInterval?
}

// MARK: - API Error

enum APIError: LocalizedError {
    case invalidURL
    case invalidAPIKey
    case rateLimitExceeded(retryAfter: TimeInterval?)
    case authenticationFailed
    case invalidResponse
    case parsingFailed(String)
    case networkError(Error)
    case providerSpecificError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidAPIKey:
            return "Invalid or missing API key"
        case .rateLimitExceeded(let retryAfter):
            if let retryAfter = retryAfter {
                return "Rate limit exceeded. Retry after \(Int(retryAfter)) seconds"
            }
            return "Rate limit exceeded. Please wait before retrying"
        case .authenticationFailed:
            return "Authentication failed. Please check your API key"
        case .invalidResponse:
            return "Invalid response from API"
        case .parsingFailed(let message):
            return "Failed to parse response: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .providerSpecificError(let message):
            return message
        }
    }
}