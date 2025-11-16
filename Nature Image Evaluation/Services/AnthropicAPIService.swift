//
//  AnthropicAPIService.swift
//  Nature Image Evaluation
//
//  Created by Claude Code on 10/27/25.
//

import Foundation

/// Anthropic Claude API implementation
final class AnthropicAPIService: APIProviderProtocol {

    let provider: Constants.APIProvider = .anthropic

    private let session: URLSession
    private let decoder = JSONDecoder()

    init() {
        // Create a custom URLSession configuration with proper timeout handling
        let configuration = URLSessionConfiguration.default

        // Timeout Configuration
        configuration.timeoutIntervalForRequest = Constants.networkRequestTimeout
        configuration.timeoutIntervalForResource = Constants.networkResourceTimeout

        // Connection settings
        configuration.waitsForConnectivity = true
        configuration.allowsCellularAccess = true
        configuration.allowsExpensiveNetworkAccess = true
        configuration.allowsConstrainedNetworkAccess = true

        // Network service type for better performance
        configuration.networkServiceType = .responsiveData

        // DNS and cache settings
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData

        self.session = URLSession(configuration: configuration)
    }

    init(session: URLSession) {
        self.session = session
    }

    // MARK: - Helper Methods

    private func sanitizeError(_ error: Error) -> String {
        // Remove any API key patterns from error messages
        var message = error.localizedDescription
        message = message.replacingOccurrences(
            of: #"sk-ant-[a-zA-Z0-9_-]+"#,
            with: "[REDACTED]",
            options: .regularExpression
        )
        // Also remove any x-api-key headers that might be exposed
        message = message.replacingOccurrences(
            of: #"x-api-key[\":\s]+[^\s\"]+"#,
            with: "x-api-key: [REDACTED]",
            options: .regularExpression
        )
        return message
    }

    // MARK: - APIProviderProtocol

    func evaluateImage(
        imageBase64: String,
        prompt: String,
        apiKey: String,
        model: String? = nil
    ) async throws -> EvaluationResponse {
        // Build request
        guard let url = URL(string: Constants.anthropicAPIURL) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        // Build request body
        let requestBody = AnthropicRequest(
            model: model ?? Constants.anthropicDefaultModel,
            maxTokens: 4096,
            messages: [
                Message(
                    role: "user",
                    content: [
                        MessageContent.image(
                            ImageContent(
                                type: "image",
                                source: ImageSource(
                                    type: "base64",
                                    mediaType: "image/jpeg",
                                    data: imageBase64
                                )
                            )
                        ),
                        MessageContent.text(
                            TextContent(
                                type: "text",
                                text: prompt
                            )
                        )
                    ]
                )
            ]
        )

        request.httpBody = try JSONEncoder().encode(requestBody)

        // Make request with retry logic
        return try await performRequestWithRetry(request: request, apiKey: apiKey)
    }

    func parseResponse(_ response: Data) throws -> EvaluationResponse {
        let anthropicResponse = try decoder.decode(AnthropicResponse.self, from: response)

        // Extract the JSON from the response content
        guard let content = anthropicResponse.content.first?.text else {
            throw APIError.invalidResponse
        }

        // Parse the evaluation JSON
        let evaluationData = try parseEvaluationJSON(from: content)

        // Validate scores are within expected range (0-10)
        try validateScores(evaluationData)

        return EvaluationResponse(
            compositionScore: evaluationData.compositionScore,
            qualityScore: evaluationData.qualityScore,
            sellabilityScore: evaluationData.sellabilityScore,
            artisticScore: evaluationData.artisticScore,
            overallWeightedScore: evaluationData.overallWeightedScore,
            primaryPlacement: evaluationData.primaryPlacement,
            strengths: evaluationData.strengths,
            improvements: evaluationData.improvements,
            marketComparison: evaluationData.marketComparison,
            technicalInnovations: evaluationData.technicalInnovations,
            printSizeRecommendation: evaluationData.printSizeRecommendation,
            priceTierSuggestion: evaluationData.priceTierSuggestion,
            title: evaluationData.title,
            descriptionText: evaluationData.description,
            keywords: evaluationData.keywords,
            altText: evaluationData.altText,
            suggestedCategories: evaluationData.suggestedCategories,
            bestUseCases: evaluationData.bestUseCases,
            suggestedPriceTier: evaluationData.suggestedPriceTier,
            inputTokens: anthropicResponse.usage.inputTokens,
            outputTokens: anthropicResponse.usage.outputTokens,
            rawResponse: content
        )
    }

    func calculateCost(inputTokens: Int, outputTokens: Int) -> Double {
        let inputCost = (Double(inputTokens) / 1_000_000) * Constants.anthropicInputTokenCostPerMillion
        let outputCost = (Double(outputTokens) / 1_000_000) * Constants.anthropicOutputTokenCostPerMillion
        return inputCost + outputCost
    }

    func extractRateLimitInfo(from response: HTTPURLResponse) -> RateLimitInfo? {
        let headers = response.allHeaderFields

        let requestsRemaining = (headers["anthropic-ratelimit-requests-remaining"] as? String).flatMap(Int.init)
        let inputTokensRemaining = (headers["anthropic-ratelimit-input-tokens-remaining"] as? String).flatMap(Int.init)
        let outputTokensRemaining = (headers["anthropic-ratelimit-output-tokens-remaining"] as? String).flatMap(Int.init)

        let requestsReset = (headers["anthropic-ratelimit-requests-reset"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) }
        let tokensReset = (headers["anthropic-ratelimit-tokens-reset"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) }

        let retryAfter = (headers["retry-after"] as? String).flatMap(TimeInterval.init)

        return RateLimitInfo(
            requestsRemaining: requestsRemaining,
            inputTokensRemaining: inputTokensRemaining,
            outputTokensRemaining: outputTokensRemaining,
            requestsReset: requestsReset,
            tokensReset: tokensReset,
            retryAfter: retryAfter
        )
    }

    // MARK: - Private Methods

    private func performRequestWithRetry(
        request: URLRequest,
        apiKey: String,
        maxRetries: Int = Constants.maxNetworkRetries
    ) async throws -> EvaluationResponse {
        var currentRetry = 0

        while currentRetry < maxRetries {
            do {
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }

                // Check for rate limit
                if httpResponse.statusCode == 429 {
                    let rateLimitInfo = extractRateLimitInfo(from: httpResponse)
                    let retryAfter = rateLimitInfo?.retryAfter ?? Constants.rateLimitBackoffSeconds

                    if currentRetry < maxRetries - 1 {
                        print("Rate limit hit. Waiting \(retryAfter) seconds before retry...")
                        try await Task.sleep(nanoseconds: UInt64(retryAfter * 1_000_000_000))
                        currentRetry += 1
                        continue
                    } else {
                        throw APIError.rateLimitExceeded(retryAfter: retryAfter)
                    }
                }

                // Check for authentication error
                if httpResponse.statusCode == 401 {
                    throw APIError.authenticationFailed
                }

                // Check for success
                if httpResponse.statusCode == 200 {
                    return try parseResponse(data)
                }

                // Handle other errors
                if let errorResponse = try? decoder.decode(AnthropicErrorResponse.self, from: data) {
                    throw APIError.providerSpecificError(errorResponse.error.message)
                }

                throw APIError.invalidResponse

            } catch let error as APIError {
                throw error
            } catch {
                // Check for timeout error
                if let nsError = error as NSError?,
                   nsError.domain == NSURLErrorDomain {
                    switch nsError.code {
                    case NSURLErrorTimedOut:
                        print("Request timed out after \(Constants.networkRequestTimeout) seconds")
                        throw APIError.networkError(NSError(
                            domain: NSURLErrorDomain,
                            code: NSURLErrorTimedOut,
                            userInfo: [
                                NSLocalizedDescriptionKey: "Request timed out. The server took too long to respond. Please try again or check your internet connection."
                            ]
                        ))

                    case NSURLErrorCannotFindHost:
                        print("DNS resolution failed. This may be a macOS sandbox issue.")
                        print("Error details: \(sanitizeError(nsError))")
                        throw APIError.networkError(NSError(
                            domain: NSURLErrorDomain,
                            code: NSURLErrorCannotFindHost,
                            userInfo: [
                                NSLocalizedDescriptionKey: "Cannot resolve api.anthropic.com. This may be a macOS sandbox DNS issue. Try restarting the app or check your network settings."
                            ]
                        ))

                    case NSURLErrorNotConnectedToInternet:
                        throw APIError.networkError(NSError(
                            domain: NSURLErrorDomain,
                            code: NSURLErrorNotConnectedToInternet,
                            userInfo: [
                                NSLocalizedDescriptionKey: "No internet connection. Please check your network settings and try again."
                            ]
                        ))

                    default:
                        break
                    }
                }

                if currentRetry < maxRetries - 1 {
                    // Exponential backoff for network errors
                    let backoffTime = TimeInterval(pow(2.0, Double(currentRetry)))
                    print("Network error. Retrying in \(backoffTime) seconds...")
                    try await Task.sleep(nanoseconds: UInt64(backoffTime * 1_000_000_000))
                    currentRetry += 1
                    continue
                }
                throw APIError.networkError(error)
            }
        }

        throw APIError.providerSpecificError("Max retries exceeded")
    }

    private func validateScores(_ data: EvaluationData) throws {
        // Validate all scores are within 0-10 range
        let scores = [
            ("Composition", data.compositionScore),
            ("Quality", data.qualityScore),
            ("Sellability", data.sellabilityScore),
            ("Artistic", data.artisticScore),
            ("Overall", data.overallWeightedScore)
        ]

        for (name, score) in scores {
            if score < 0 || score > 10 {
                throw APIError.parsingFailed("\(name) score \(score) is outside valid range (0-10)")
            }
        }

        // Validate required fields are not empty
        if data.strengths.isEmpty {
            throw APIError.parsingFailed("Strengths array cannot be empty")
        }

        if data.improvements.isEmpty {
            throw APIError.parsingFailed("Improvements array cannot be empty")
        }

        // Validate placement value
        let validPlacements = ["PORTFOLIO", "STORE", "BOTH", "ARCHIVE", "PRACTICE"]
        if !validPlacements.contains(data.primaryPlacement) {
            throw APIError.parsingFailed("Invalid placement value: \(data.primaryPlacement)")
        }
    }

    private func parseEvaluationJSON(from content: String) throws -> EvaluationData {
        // Check maximum content length to prevent memory issues
        let maxContentLength = 100_000 // 100KB should be more than enough
        if content.count > maxContentLength {
            throw APIError.parsingFailed("Response content exceeds maximum allowed length")
        }

        // Find JSON content in the response (might be wrapped in markdown)
        // Use non-greedy pattern to get first complete JSON object
        let jsonPattern = #"\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}"#
        guard let range = content.range(of: jsonPattern, options: .regularExpression),
              let jsonData = String(content[range]).data(using: .utf8) else {
            throw APIError.parsingFailed("Could not extract JSON from response")
        }

        do {
            return try decoder.decode(EvaluationData.self, from: jsonData)
        } catch {
            print("❌ Failed to decode JSON: \(sanitizeError(error))")
            throw APIError.parsingFailed("JSON decoding failed: \(sanitizeError(error))")
        }
    }
}

// MARK: - Anthropic Request Models

private struct AnthropicRequest: Encodable {
    let model: String
    let maxTokens: Int
    let messages: [Message]

    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case messages
    }
}

private struct Message: Encodable {
    let role: String
    let content: [MessageContent]
}

private enum MessageContent: Encodable {
    case text(TextContent)
    case image(ImageContent)

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let content):
            try container.encode(content)
        case .image(let content):
            try container.encode(content)
        }
    }
}

private struct TextContent: Encodable {
    let type: String
    let text: String
}

private struct ImageContent: Encodable {
    let type: String
    let source: ImageSource
}

private struct ImageSource: Encodable {
    let type: String
    let mediaType: String
    let data: String

    enum CodingKeys: String, CodingKey {
        case type
        case mediaType = "media_type"
        case data
    }
}

// MARK: - Anthropic Response Models

private struct AnthropicResponse: Decodable {
    let content: [ContentBlock]
    let usage: Usage
}

private struct ContentBlock: Decodable {
    let type: String
    let text: String?
}

private struct Usage: Decodable {
    let inputTokens: Int
    let outputTokens: Int

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

private struct AnthropicErrorResponse: Decodable {
    let error: ErrorDetail
}

private struct ErrorDetail: Decodable {
    let message: String
    let type: String
}

// MARK: - Evaluation Data Model

private struct EvaluationData: Decodable {
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

    // Commercial metadata (optional, for STORE/BOTH placement)
    let title: String?
    let description: String?
    let keywords: [String]?
    let altText: String?
    let suggestedCategories: [String]?
    let bestUseCases: [String]?
    let suggestedPriceTier: String?

    enum CodingKeys: String, CodingKey {
        case compositionScore = "composition_score"
        case qualityScore = "quality_score"
        case sellabilityScore = "sellability_score"
        case artisticScore = "artistic_score"
        case overallWeightedScore = "overall_weighted_score"
        case primaryPlacement = "primary_placement"
        case strengths
        case improvements
        case marketComparison = "market_comparison"
        case technicalInnovations = "technical_innovations"
        case printSizeRecommendation = "print_size_recommendation"
        case priceTierSuggestion = "price_tier_suggestion"
        case title
        case description
        case keywords
        case altText = "alt_text"
        case suggestedCategories = "suggested_categories"
        case bestUseCases = "best_use_cases"
        case suggestedPriceTier = "suggested_price_tier"
    }
}