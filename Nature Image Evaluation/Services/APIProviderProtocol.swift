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
            return "The API service URL is not configured correctly. Please contact support if this issue persists."

        case .invalidAPIKey:
            return "Your API key appears to be missing or invalid. Please check your API key in Settings and ensure you've copied it correctly."

        case .rateLimitExceeded(let retryAfter):
            if let retryAfter = retryAfter {
                let minutes = Int(retryAfter) / 60
                if minutes > 0 {
                    return "You've reached the API rate limit. Please wait \(minutes) minute\(minutes == 1 ? "" : "s") before continuing, or reduce the batch size in Settings."
                } else {
                    return "API rate limit reached. Waiting \(Int(retryAfter)) seconds before retrying..."
                }
            }
            return "You've reached the API rate limit. Please wait a moment before continuing, or try reducing the batch size in Settings."

        case .authenticationFailed:
            return "Authentication failed. Your API key may be invalid or expired. Please verify your API key in Settings and ensure your account is active."

        case .invalidResponse:
            return "Received an unexpected response from the API service. This might be a temporary issue. Please try again in a moment."

        case .parsingFailed(let message):
            // Make technical parsing errors more user-friendly
            if message.contains("score") && message.contains("outside valid range") {
                return "The AI service returned invalid score values. Please try evaluating this image again."
            } else if message.contains("empty") {
                return "The AI service didn't provide complete evaluation data. Please try again."
            } else {
                return "Could not process the evaluation results. Please try again or contact support if the issue persists."
            }

        case .networkError(let error):
            // Already handled with specific messages in AnthropicAPIService
            return error.localizedDescription

        case .providerSpecificError(let message):
            // Make provider errors more user-friendly
            if message.lowercased().contains("overloaded") {
                return "The AI service is currently experiencing high demand. Your request will be retried automatically."
            } else if message.lowercased().contains("timeout") {
                return "The request took too long to complete. Please check your internet connection and try again."
            } else {
                return message
            }
        }
    }

    /// User-friendly recovery suggestion for each error type
    var recoverySuggestion: String? {
        switch self {
        case .invalidAPIKey, .authenticationFailed:
            return "Go to Settings > API Configuration to update your API key."

        case .rateLimitExceeded:
            return "Consider reducing the batch size or adding delays between requests in Settings > Rate Limiting."

        case .networkError:
            return "Check your internet connection and try again. If using a VPN, try disabling it temporarily."

        case .providerSpecificError(let message) where message.lowercased().contains("overloaded"):
            return "The system will automatically retry. You can also try again during off-peak hours."

        default:
            return "If this problem continues, please try restarting the app or contact support."
        }
    }
}