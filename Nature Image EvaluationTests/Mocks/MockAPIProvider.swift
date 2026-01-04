//
//  MockAPIProvider.swift
//  Nature Image EvaluationTests
//
//  Created by Claude Code on 01/04/26.
//

import Foundation
@testable import Nature_Image_Evaluation

/// Mock API provider for testing evaluation workflows
final class MockAPIProvider: APIProviderProtocol {
    var provider: Constants.APIProvider = .anthropic

    // MARK: - Mock Configuration

    var mockResponse: EvaluationResponse?
    var mockError: Error?
    var evaluateImageCallCount = 0
    var lastImageBase64: String?
    var lastPrompt: String?
    var lastAPIKey: String?
    var lastModel: String?

    /// Delay to simulate network latency (in seconds)
    var simulatedDelay: TimeInterval = 0

    // MARK: - APIProviderProtocol

    func evaluateImage(
        imageBase64: String,
        prompt: String,
        apiKey: String,
        model: String?
    ) async throws -> EvaluationResponse {
        evaluateImageCallCount += 1
        lastImageBase64 = imageBase64
        lastPrompt = prompt
        lastAPIKey = apiKey
        lastModel = model

        // Simulate network delay
        if simulatedDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }

        if let error = mockError {
            throw error
        }

        guard let response = mockResponse else {
            throw APIError.invalidResponse
        }

        return response
    }

    func parseResponse(_: Data) throws -> EvaluationResponse {
        guard let mockResponse = mockResponse else {
            throw APIError.invalidResponse
        }
        return mockResponse
    }

    func calculateCost(inputTokens: Int, outputTokens: Int) -> Double {
        // Use same formula as AnthropicAPIService
        let inputCost = (Double(inputTokens) / 1_000_000) * Constants.anthropicInputTokenCostPerMillion
        let outputCost = (Double(outputTokens) / 1_000_000) * Constants.anthropicOutputTokenCostPerMillion
        return inputCost + outputCost
    }

    func extractRateLimitInfo(from _: HTTPURLResponse) -> RateLimitInfo? {
        return nil
    }

    // MARK: - Test Helpers

    /// Configure mock to return a successful response
    func setSuccessResponse(
        compositionScore: Double = 8.5,
        qualityScore: Double = 9.0,
        sellabilityScore: Double = 7.5,
        artisticScore: Double = 8.0,
        overallScore: Double = 8.25,
        placement: String = "PORTFOLIO"
    ) {
        mockResponse = EvaluationResponse(
            compositionScore: compositionScore,
            qualityScore: qualityScore,
            sellabilityScore: sellabilityScore,
            artisticScore: artisticScore,
            overallWeightedScore: overallScore,
            primaryPlacement: placement,
            strengths: ["Good composition", "Sharp focus"],
            improvements: ["Consider better lighting"],
            marketComparison: "Comparable to mid-tier stock imagery",
            technicalInnovations: nil,
            printSizeRecommendation: nil,
            priceTierSuggestion: nil,
            title: nil,
            descriptionText: nil,
            keywords: nil,
            altText: nil,
            suggestedCategories: nil,
            bestUseCases: nil,
            suggestedPriceTier: nil,
            inputTokens: 1500,
            outputTokens: 250,
            rawResponse: "{\"test\": true}"
        )
        mockError = nil
    }

    /// Configure mock to return a commercial response with full metadata
    func setCommercialResponse() {
        mockResponse = EvaluationResponse(
            compositionScore: 8.0,
            qualityScore: 8.5,
            sellabilityScore: 9.0,
            artisticScore: 7.5,
            overallWeightedScore: 8.25,
            primaryPlacement: "STORE",
            strengths: ["Commercial appeal", "Clean composition"],
            improvements: ["Add more negative space"],
            marketComparison: "Strong commercial potential",
            technicalInnovations: ["Creative use of depth"],
            printSizeRecommendation: "Up to 24x36",
            priceTierSuggestion: "MID",
            title: "Serene Mountain Lake",
            descriptionText: "A peaceful mountain lake at sunrise",
            keywords: ["nature", "mountain", "lake", "sunrise"],
            altText: "Mountain lake with reflection at sunrise",
            suggestedCategories: ["Nature", "Landscape"],
            bestUseCases: ["Website hero", "Print"],
            suggestedPriceTier: "MID",
            inputTokens: 1600,
            outputTokens: 300,
            rawResponse: "{\"commercial\": true}"
        )
        mockError = nil
    }

    /// Configure mock to throw an error
    func setError(_ error: Error) {
        mockResponse = nil
        mockError = error
    }

    /// Reset mock state
    func reset() {
        mockResponse = nil
        mockError = nil
        evaluateImageCallCount = 0
        lastImageBase64 = nil
        lastPrompt = nil
        lastAPIKey = nil
        lastModel = nil
        simulatedDelay = 0
    }
}
