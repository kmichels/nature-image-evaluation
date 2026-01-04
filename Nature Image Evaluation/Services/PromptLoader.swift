//
//  PromptLoader.swift
//  Nature Image Evaluation
//
//  Created by Claude Code on 10/27/25.
//

import Foundation

/// Loads evaluation prompts from bundled resources
final class PromptLoader {
    static let shared = PromptLoader()

    private var cachedEvaluationPrompt: String?
    private var cachedCommercialCriteria: String?

    private init() {}

    // MARK: - Prompt Loading

    /// Load the main evaluation prompt
    /// - Returns: The evaluation prompt text
    func loadEvaluationPrompt() -> String {
        if let cached = cachedEvaluationPrompt {
            return cached
        }

        // Try v2 prompt first
        if let url = Bundle.main.url(forResource: "evaluation_prompt_v2", withExtension: "txt") {
            do {
                let prompt = try String(contentsOf: url, encoding: .utf8)
                cachedEvaluationPrompt = prompt
                return prompt
            } catch {
                print("Error loading evaluation_prompt_v2: \(error)")
            }
        }

        // Fall back to original prompt
        guard let url = Bundle.main.url(
            forResource: Constants.evaluationPromptFile,
            withExtension: "txt"
        ) else {
            print("Warning: Could not find \(Constants.evaluationPromptFile).txt in bundle")
            return defaultEvaluationPrompt()
        }

        do {
            let prompt = try String(contentsOf: url, encoding: .utf8)
            cachedEvaluationPrompt = prompt
            return prompt
        } catch {
            print("Error loading evaluation prompt: \(error)")
            return defaultEvaluationPrompt()
        }
    }

    /// Load commercial potential criteria
    /// - Returns: The commercial criteria text
    func loadCommercialCriteria() -> String {
        if let cached = cachedCommercialCriteria {
            return cached
        }

        guard let url = Bundle.main.url(
            forResource: Constants.commercialCriteriaFile,
            withExtension: "txt"
        ) else {
            print("Warning: Could not find \(Constants.commercialCriteriaFile).txt in bundle")
            return ""
        }

        do {
            let criteria = try String(contentsOf: url, encoding: .utf8)
            cachedCommercialCriteria = criteria
            return criteria
        } catch {
            print("Error loading commercial criteria: \(error)")
            return ""
        }
    }

    /// Get the current prompt version (based on modification date)
    /// - Returns: Version string (date-based)
    func getPromptVersion() -> String {
        guard let url = Bundle.main.url(
            forResource: Constants.evaluationPromptFile,
            withExtension: "txt"
        ) else {
            return "1.0.0"
        }

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let modDate = attributes[.modificationDate] as? Date {
                return Formatters.versionDate.string(from: modDate)
            }
        } catch {
            print("Error getting prompt version: \(error)")
        }

        return "1.0.0"
    }

    /// Clear cached prompts (useful if prompts are updated)
    func clearCache() {
        cachedEvaluationPrompt = nil
        cachedCommercialCriteria = nil
    }

    // MARK: - Default Prompts

    private func defaultEvaluationPrompt() -> String {
        """
        You are an expert photography critic specializing in nature, landscape, and wildlife photography. Analyze the provided image using the following criteria, providing both numerical ratings (1-10) and specific observations.

        ## 1. OVERALL COMPOSITION ANALYSIS (Weight: 30%)
        Rate 1-10 and evaluate visual hierarchy, balance, compositional techniques, framing, negative space, and depth.

        ## 2. IMAGE QUALITY ASSESSMENT (Weight: 25%)
        Rate 1-10 and evaluate focus accuracy, technical execution, noise levels, dynamic range, and overall quality factors.

        ## 3. COMMERCIAL SELLABILITY (Weight: 25%)
        Rate 1-10 based on mass market appeal, wall art suitability, subject recognizability, emotional accessibility, and market factors.

        ## 4. ARTISTIC MERIT (Weight: 20%)
        Rate 1-10 based on uniqueness of perspective, emotional depth, creative use of light and color, coherence of vision, and technical innovation.

        ## FINAL CLASSIFICATION
        Based on scores above, recommend primary placement:
        - PORTFOLIO: High artistic merit (7+) regardless of commercial appeal
        - STORE: High commercial appeal (7+) with acceptable quality
        - BOTH: Scores 7+ in both categories
        - PRACTICE/ARCHIVE: Neither criterion strongly met

        ## SPECIFIC FEEDBACK
        Provide 2-3 specific, actionable observations about:
        1. What works strongest in this image
        2. What could be improved (be specific about technique)
        3. Market positioning (similar successful work, pricing tier suggestion)

        Output format:
        {
          "composition_score": X,
          "quality_score": X,
          "sellability_score": X,
          "artistic_score": X,
          "overall_weighted_score": X,
          "primary_placement": "PORTFOLIO/STORE/BOTH/ARCHIVE",
          "strengths": ["..."],
          "improvements": ["..."],
          "market_comparison": "...",
          "technical_innovations": ["..."],
          "print_size_recommendation": "optimal size range",
          "price_tier_suggestion": "LOW/MID/HIGH"
        }
        """
    }
}
