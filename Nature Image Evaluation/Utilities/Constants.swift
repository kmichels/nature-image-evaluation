//
//  Constants.swift
//  Nature Image Evaluation
//
//  Created by Claude Code on 10/27/25.
//

import Foundation
import CoreGraphics

struct Constants {
    // MARK: - API Configuration

    /// Anthropic API
    static let anthropicAPIURL = "https://api.anthropic.com/v1/messages"
    static let anthropicDefaultModel = "claude-opus-4-5-20251101"

    /// Available Anthropic Models (2025)
    static let anthropicModels = [
        AnthropicModel(id: "claude-opus-4-5-20251101", name: "Claude Opus 4.5", description: "Latest & best for coding, agents & complex reasoning", inputCost: 5.0, outputCost: 25.0),
        AnthropicModel(id: "claude-opus-4-1", name: "Claude Opus 4.1", description: "Previous best for complex reasoning", inputCost: 15.0, outputCost: 75.0),
        AnthropicModel(id: "claude-sonnet-4-5", name: "Claude Sonnet 4.5", description: "Balanced performance & cost", inputCost: 3.0, outputCost: 15.0),
        AnthropicModel(id: "claude-haiku-4-5", name: "Claude Haiku 4.5", description: "Fast & cheaper option", inputCost: 1.0, outputCost: 5.0),
        AnthropicModel(id: "claude-haiku-3-5", name: "Claude Haiku 3.5", description: "Most economical choice", inputCost: 0.25, outputCost: 1.25)
    ]

    /// OpenAI API (for future GPT-4 Vision support)
    static let openAIAPIURL = "https://api.openai.com/v1/chat/completions"
    static let openAIDefaultModel = "gpt-4-vision-preview"

    // MARK: - Network Configuration

    /// Timeout for individual network requests (seconds)
    static let networkRequestTimeout: TimeInterval = 60.0

    /// Timeout for entire resource download (seconds)
    static let networkResourceTimeout: TimeInterval = 120.0

    /// Maximum retries for network failures
    static let maxNetworkRetries: Int = 3

    // MARK: - Rate Limiting

    /// Default delay between API requests (seconds)
    static let defaultRequestDelay: TimeInterval = 2.0

    /// Minimum delay between requests (seconds)
    static let minimumRequestDelay: TimeInterval = 1.0

    /// Maximum delay between requests (seconds)
    static let maximumRequestDelay: TimeInterval = 5.0

    /// Default maximum batch size for processing
    static let maxBatchSize: Int = 15

    /// Minimum batch size
    static let minBatchSize: Int = 5

    /// Maximum batch size
    static let maximumBatchSize: Int = 25

    /// Default backoff time when rate limit hit (seconds)
    static let rateLimitBackoffSeconds: TimeInterval = 30.0

    /// Anthropic API rate limits (requests per minute)
    static let anthropicRPMLimit: Int = 50

    /// Warning threshold for remaining requests
    static let rateLimitWarningThreshold: Int = 10

    // MARK: - Image Processing

    /// Maximum dimension for images sent to API (pixels)
    /// Anthropic recommends 1568 max; larger images may exceed 5MB API limit
    static let maxImageDimension: Int = 1568

    /// Thumbnail size for gallery display
    static let thumbnailSize: CGSize = CGSize(width: 100, height: 100)

    /// JPEG compression quality for processed images (0.85 balances quality vs size)
    static let jpegCompressionQuality: CGFloat = 0.85

    // MARK: - Pricing (per million tokens)

    /// Anthropic Claude Sonnet 4.x input token cost
    static let anthropicInputTokenCostPerMillion = 3.00  // $3 per million

    /// Anthropic Claude Sonnet 4.x output token cost
    static let anthropicOutputTokenCostPerMillion = 15.00 // $15 per million

    /// OpenAI GPT-4 Vision input token cost (approximate)
    static let openAIInputTokenCostPerMillion = 10.00  // $10 per million

    /// OpenAI GPT-4 Vision output token cost (approximate)
    static let openAIOutputTokenCostPerMillion = 30.00 // $30 per million

    // MARK: - File Storage

    /// Application Support folder name
    static let appSupportFolder = "Nature Image Evaluation"

    /// Processed images subfolder
    static let processedImagesFolder = "ProcessedImages"

    /// Database subfolder
    static let databaseFolder = "Database"

    /// Thumbnails subfolder
    static let thumbnailsFolder = "Thumbnails"

    // MARK: - Keychain

    /// Keychain service name
    static let keychainServiceName = "com.konradmichels.natureimageevaluation"

    /// Keychain account for Anthropic API key
    static let keychainAnthropicAPIKeyAccount = "anthropic_api_key"

    /// Keychain account for OpenAI API key
    static let keychainOpenAIAPIKeyAccount = "openai_api_key"

    // MARK: - Evaluation Weights

    /// Composition score weight
    static let compositionWeight = 0.30

    /// Technical quality score weight
    static let qualityWeight = 0.25

    /// Commercial sellability score weight
    static let sellabilityWeight = 0.25

    /// Artistic merit score weight
    static let artisticWeight = 0.20

    // MARK: - Resource Files

    /// Evaluation prompt file name
    static let evaluationPromptFile = "Suggested_AI_Prompt"

    /// Commercial criteria file name
    static let commercialCriteriaFile = "Suggested_commercial_potential_criteria"

    // MARK: - API Provider Enum

    enum APIProvider: String, CaseIterable {
        case anthropic = "Anthropic Claude"
        case openai = "OpenAI GPT-4 Vision"

        var displayName: String {
            return self.rawValue
        }

        var defaultModel: String {
            switch self {
            case .anthropic:
                return Constants.anthropicDefaultModel
            case .openai:
                return Constants.openAIDefaultModel
            }
        }
    }
}

// MARK: - Anthropic Model Definition

struct AnthropicModel: Identifiable, Hashable {
    let id: String
    let name: String
    let description: String
    let inputCost: Double  // Cost per million tokens
    let outputCost: Double // Cost per million tokens

    var displayName: String {
        "\(name) - \(description)"
    }

    var costDisplay: String {
        "$\(String(format: "%.2f", inputCost))/$\(String(format: "%.2f", outputCost)) per M tokens"
    }
}
