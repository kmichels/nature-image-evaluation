//
//  EvaluationManager.swift
//  Nature Image Evaluation
//
//  Created by Claude Code on 10/27/25.
//

import AppKit
import CoreData
import Foundation
import Observation
import os.log

/// Orchestrates the entire image evaluation workflow
@MainActor
@Observable
final class EvaluationManager {
    // MARK: - Observable State

    /// Current processing state
    var isProcessing = false

    /// Current batch being processed (1-based)
    var currentBatch = 0

    /// Total number of batches
    var totalBatches = 0

    /// Current image being processed (1-based)
    var currentImageIndex = 0

    /// Total images to process
    var totalImages = 0

    /// Current progress (0.0 to 1.0)
    var currentProgress: Double = 0.0

    /// Status message for UI
    var statusMessage = "Ready to evaluate images"

    /// Current error if any
    var currentError: Error?

    /// Images queued for evaluation
    var evaluationQueue: [ImageEvaluation] = []

    /// Successfully evaluated images count
    var successfulEvaluations = 0

    /// Failed evaluations count
    var failedEvaluations = 0

    /// Current evaluation session
    private var currentSession: EvaluationSession?

    /// Track provider for this session
    private var currentProvider = {
        // Load selected model from UserDefaults
        let selectedModel = UserDefaults.standard.string(forKey: "selectedAnthropicModel") ?? Constants.anthropicDefaultModel

        // Find the model info
        if let model = Constants.anthropicModels.first(where: { $0.id == selectedModel }) {
            return ProviderInfo(
                identifier: "Anthropic",
                displayName: model.name,
                model: model.id,
                apiVersion: "2024-10-01"
            )
        }

        // Fallback to default
        return ProviderInfo.anthropicClaude
    }()

    // MARK: - Configuration

    /// Delay between API requests (seconds)
    var requestDelay: TimeInterval = Constants.defaultRequestDelay

    /// Maximum batch size
    var maxBatchSize: Int = Constants.maxBatchSize

    /// Image resolution for processing
    var imageResolution: Int = Constants.maxImageDimension

    /// Selected API provider
    var selectedProvider: Constants.APIProvider = .anthropic

    // MARK: - Services

    private let imageProcessor = ImageProcessor.shared
    private let bookmarkManager = BookmarkManager.shared
    private let keychainManager = KeychainManager.shared
    private let promptLoader = PromptLoader.shared
    private var apiService: APIProviderProtocol

    // MARK: - Core Data

    private let persistenceController: PersistenceController
    private let viewContext: NSManagedObjectContext

    // MARK: - Cancellation

    private var evaluationTask: Task<Void, Never>?

    // MARK: - Initialization

    init(persistenceController: PersistenceController) {
        self.persistenceController = persistenceController
        viewContext = persistenceController.container.viewContext
        apiService = AnthropicAPIService()
    }

    // Convenience initializer that can only be called from MainActor context
    init() {
        persistenceController = PersistenceController.shared
        viewContext = persistenceController.container.viewContext
        apiService = AnthropicAPIService()
    }

    // MARK: - Public Methods

    /// Security-scoped folder URL for current evaluation session
    private var activeFolderAccess: URL?

    /// Add images to the evaluation queue
    /// - Parameters:
    ///   - urls: URLs of images to evaluate
    ///   - folderURL: The folder URL that contains the images (for security-scoped access)
    @MainActor
    func addImages(urls: [URL], folderURL: URL? = nil) async {
        statusMessage = "Adding \(urls.count) images to queue..."

        // Start security-scoped access on the folder if provided
        if let folder = folderURL {
            let didStart = folder.startAccessingSecurityScopedResource()
            print("🔐 Security-scoped access for folder: \(didStart ? "GRANTED" : "DENIED") - \(folder.path)")
            if didStart {
                // Store reference to stop access later (don't stop during addImages - keep for evaluation)
                activeFolderAccess = folder
            }
        }

        for (index, url) in urls.enumerated() {
            print("Processing image \(index + 1)/\(urls.count): \(url.path)")

            // Debug: Check file accessibility
            let fileManager = FileManager.default
            let exists = fileManager.fileExists(atPath: url.path)
            let readable = fileManager.isReadableFile(atPath: url.path)
            print("  📁 File exists: \(exists), readable: \(readable)")

            // Try starting security-scoped access on the file itself
            let fileAccessStarted = url.startAccessingSecurityScopedResource()
            print("  🔐 File security access: \(fileAccessStarted ? "started" : "not needed/failed")")

            do {
                // Load image data first, then create NSImage
                // This approach works better with security-scoped resources
                let imageData: Data
                do {
                    imageData = try Data(contentsOf: url)
                    print("  ✅ Loaded \(imageData.count) bytes")
                } catch {
                    print("  ❌ Failed to load file data: \(error.localizedDescription)")
                    continue
                }

                guard let image = NSImage(data: imageData) else {
                    print("  ❌ Failed to create NSImage from data")
                    continue
                }
                print("  ✅ Created NSImage: \(image.size)")

                // Create security-scoped bookmark
                // Note: This might fail if the file is outside allowed locations
                let bookmarkData: Data
                do {
                    bookmarkData = try bookmarkManager.createBookmark(for: url)
                    print("Created bookmark for: \(url.lastPathComponent)")
                } catch {
                    print("Warning: Could not create bookmark for \(url.lastPathComponent): \(error)")
                    // For now, store the URL path as a fallback
                    bookmarkData = url.path.data(using: .utf8) ?? Data()
                }

                // Create Core Data entity
                let imageEval = ImageEvaluation(context: viewContext)
                imageEval.id = UUID()
                imageEval.dateAdded = Date()
                // Store the bookmark data directly as Data
                imageEval.originalFilePath = bookmarkData

                // Get original dimensions
                if let rep = image.representations.first {
                    imageEval.originalWidth = Int32(rep.pixelsWide)
                    imageEval.originalHeight = Int32(rep.pixelsHigh)
                    imageEval.aspectRatio = imageProcessor.calculateAspectRatio(
                        width: CGFloat(rep.pixelsWide),
                        height: CGFloat(rep.pixelsHigh)
                    )
                }

                // Process and save resized image
                statusMessage = "Processing image \(index + 1) of \(urls.count)..."

                if let resized = imageProcessor.resizeForEvaluation(image: image, maxDimension: imageResolution) {
                    print("  ✅ Resized to: \(resized.size)")

                    // Generate unique path for processed image
                    let processedURL = getProcessedImageURL(for: imageEval.id!)
                    print("  📂 Saving to: \(processedURL.path)")

                    // Save processed image
                    let fileSize = try imageProcessor.saveProcessedImage(resized, to: processedURL)
                    imageEval.processedFilePath = processedURL.path
                    imageEval.fileSize = fileSize
                    print("  ✅ Saved processed image: \(fileSize) bytes")

                    // Get processed dimensions
                    if let rep = resized.representations.first {
                        imageEval.processedWidth = Int32(rep.pixelsWide)
                        imageEval.processedHeight = Int32(rep.pixelsHigh)
                    }

                    // Generate and save thumbnail
                    if let thumbnail = imageProcessor.generateThumbnail(image: resized) {
                        imageEval.thumbnailData = imageProcessor.thumbnailToData(thumbnail)
                    }
                } else {
                    print("  ❌ Failed to resize image")
                }

                evaluationQueue.append(imageEval)
                print("  ✅ Added to queue (processedFilePath: \(imageEval.processedFilePath ?? "nil"))")

            } catch {
                print("Error adding image \(url.lastPathComponent): \(error)")
            }
        }

        // Save context
        do {
            try viewContext.save()
            statusMessage = "Added \(evaluationQueue.count) images to queue"
        } catch {
            print("Error saving context: \(error)")
            statusMessage = "Error saving images"
        }
    }

    /// Start evaluating queued images
    @MainActor
    func startEvaluation() async throws {
        guard !evaluationQueue.isEmpty else {
            statusMessage = "No images to evaluate"
            return
        }

        // Refresh the current provider with latest selected model
        let selectedModel = UserDefaults.standard.string(forKey: "selectedAnthropicModel") ?? Constants.anthropicDefaultModel
        if let model = Constants.anthropicModels.first(where: { $0.id == selectedModel }) {
            currentProvider = ProviderInfo(
                identifier: "Anthropic",
                displayName: model.name,
                model: model.id,
                apiVersion: "2024-10-01"
            )
        }

        // Get API key
        guard let apiKey = try keychainManager.getAPIKey(for: selectedProvider) else {
            throw EvaluationError.missingAPIKey
        }

        // Set up API service based on provider
        switch selectedProvider {
        case .anthropic:
            apiService = AnthropicAPIService()
        case .openai:
            // apiService = OpenAIAPIService() // Future implementation
            throw EvaluationError.providerNotImplemented
        }

        // Create evaluation session
        currentSession = createEvaluationSession(type: "batch", imageCount: evaluationQueue.count)

        // Reset counters
        isProcessing = true
        currentError = nil
        successfulEvaluations = 0
        failedEvaluations = 0
        totalImages = evaluationQueue.count

        // Calculate batches
        totalBatches = (totalImages + maxBatchSize - 1) / maxBatchSize

        // Load evaluation prompt
        let prompt = promptLoader.loadEvaluationPrompt()

        // Process in batches
        evaluationTask = Task {
            await processAllBatches(prompt: prompt, apiKey: apiKey)
            await MainActor.run { completeEvaluation() }
        }

        // Wait for the evaluation task to complete before returning
        await evaluationTask?.value
    }

    /// Cancel current evaluation
    func cancelEvaluation() {
        evaluationTask?.cancel()
        evaluationTask = nil
        isProcessing = false
        statusMessage = "Evaluation cancelled"

        // Release security-scoped access
        if let folder = activeFolderAccess {
            folder.stopAccessingSecurityScopedResource()
            activeFolderAccess = nil
            print("🔐 Released security-scoped access for folder (cancelled)")
        }
    }

    /// Clear the evaluation queue
    @MainActor
    func clearQueue() {
        evaluationQueue.removeAll()
        currentProgress = 0
        statusMessage = "Queue cleared"
    }

    /// Get or update API usage stats
    func getAPIUsageStats() -> APIUsageStats? {
        let request: NSFetchRequest<APIUsageStats> = APIUsageStats.fetchRequest()
        request.fetchLimit = 1

        do {
            let stats = try viewContext.fetch(request).first
            return stats ?? createInitialStats()
        } catch {
            print("Error fetching API stats: \(error)")
            return nil
        }
    }

    // MARK: - Batch Processing

    private func processAllBatches(prompt: String, apiKey: String) async {
        for batchIndex in 0 ..< totalBatches {
            guard !Task.isCancelled else { break }
            await processBatch(index: batchIndex, prompt: prompt, apiKey: apiKey)
        }
    }

    private func processBatch(index batchIndex: Int, prompt: String, apiKey: String) async {
        currentBatch = batchIndex + 1
        let startIndex = batchIndex * maxBatchSize
        let endIndex = min(startIndex + maxBatchSize, evaluationQueue.count)
        let batch = Array(evaluationQueue[startIndex ..< endIndex])

        statusMessage = "Processing batch \(currentBatch) of \(totalBatches)..."

        for (index, imageEval) in batch.enumerated() {
            guard !Task.isCancelled else { break }

            currentImageIndex = startIndex + index + 1
            updateProgress()
            statusMessage = "Evaluating image \(currentImageIndex) of \(totalImages) (batch \(currentBatch)/\(totalBatches))..."

            await processImageWithRetry(imageEval, prompt: prompt, apiKey: apiKey)

            // Apply rate limit delay (except for last image in last batch)
            let isLastImage = index == batch.count - 1 && batchIndex == totalBatches - 1
            if !isLastImage {
                statusMessage = "Waiting \(Int(requestDelay)) seconds before next request..."
                try? await Task.sleep(nanoseconds: UInt64(requestDelay * 1_000_000_000))
            }
        }
    }

    private func processImageWithRetry(_ imageEval: ImageEvaluation, prompt: String, apiKey: String) async {
        do {
            try await evaluateImage(imageEval, prompt: prompt, apiKey: apiKey)
            successfulEvaluations += 1
        } catch {
            failedEvaluations += 1
            print("❌ Error evaluating image: \(error)")
            AppLogger.evaluation.error("❌ Error evaluating image: \(error.localizedDescription)")
            currentError = error

            await handleEvaluationError(error, for: imageEval, prompt: prompt, apiKey: apiKey)
        }
    }

    private func handleEvaluationError(_ error: Error, for imageEval: ImageEvaluation, prompt: String, apiKey: String) async {
        if case let APIError.rateLimitExceeded(retryAfter) = error {
            await handleRateLimitError(retryAfter: retryAfter, for: imageEval, prompt: prompt, apiKey: apiKey)
        } else if case let APIError.providerSpecificError(message) = error,
                  message.lowercased().contains("overloaded")
        {
            await handleOverloadedError(for: imageEval, prompt: prompt, apiKey: apiKey)
        } else {
            createFailedEvaluation(for: imageEval, error: error)
            statusMessage = "Evaluation failed: \(error.localizedDescription)"
        }
    }

    private func handleRateLimitError(retryAfter: TimeInterval?, for imageEval: ImageEvaluation, prompt: String, apiKey: String) async {
        let waitTime = retryAfter ?? Constants.rateLimitBackoffSeconds
        statusMessage = "Rate limit hit. Waiting \(Int(waitTime)) seconds..."
        try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))

        do {
            try await evaluateImage(imageEval, prompt: prompt, apiKey: apiKey)
            successfulEvaluations += 1
            failedEvaluations -= 1
        } catch {
            AppLogger.evaluation.warning("⚠️ Retry failed: \(error.localizedDescription)")
            currentError = error
            createFailedEvaluation(for: imageEval, error: error)
        }
    }

    private func handleOverloadedError(for imageEval: ImageEvaluation, prompt: String, apiKey: String) async {
        let baseWaitTime: TimeInterval = 60.0
        let maxRetries = Constants.maxNetworkRetries

        for retryCount in 0 ..< maxRetries {
            let backoffTime = baseWaitTime * pow(2.0, Double(retryCount))
            statusMessage = "API overloaded. Retry \(retryCount + 1)/\(maxRetries) in \(Int(backoffTime)) seconds..."
            try? await Task.sleep(nanoseconds: UInt64(backoffTime * 1_000_000_000))

            do {
                try await evaluateImage(imageEval, prompt: prompt, apiKey: apiKey)
                successfulEvaluations += 1
                failedEvaluations -= 1
                statusMessage = "Retry successful. Continuing..."
                return
            } catch {
                print("Retry \(retryCount + 1) failed: \(error)")
                if retryCount == maxRetries - 1 {
                    statusMessage = "Failed after \(maxRetries) retries. Skipping image."
                    createFailedEvaluation(for: imageEval, error: error)
                }
            }
        }
    }

    // MARK: - Private Methods

    private func evaluateImage(_ imageEval: ImageEvaluation, prompt: String, apiKey: String) async throws {
        // Load processed image
        guard let processedPath = imageEval.processedFilePath,
              let processedImage = NSImage(contentsOfFile: processedPath)
        else {
            throw EvaluationError.processedImageNotFound
        }

        // Run technical analysis first (local, free, fast)
        let technicalAnalysis = try await TechnicalAnalyzer.shared.analyzeImage(processedImage)

        print("🔬 Technical analysis complete in \(String(format: "%.2f", technicalAnalysis.analysisTime))s:")
        print("  Sharpness: \(String(format: "%.1f", technicalAnalysis.metrics.sharpnessScore))/10")
        print("  Blur: \(technicalAnalysis.metrics.blurType.rawValue) (amount: \(String(format: "%.2f", technicalAnalysis.metrics.blurAmount)))")
        print("  Focus: \(technicalAnalysis.metrics.sharpnessMap.distribution) (\(Int(technicalAnalysis.metrics.sharpnessMap.sharpnessPercentage * 100))% sharp)")
        print("  Exposure: \(technicalAnalysis.metrics.exposure.distribution)")
        if technicalAnalysis.intent.isLikelyIntentional {
            print("  🎨 Artistic intent: \(technicalAnalysis.intent.probableTechnique.rawValue) (confidence: \(Int(technicalAnalysis.intent.confidence * 100))%)")
        }

        // Generate saliency analysis (local, Vision Framework)
        let saliencyData = await SaliencyAnalyzer.shared.generateSaliencyDataForStorage(from: processedImage)
        if let pattern = saliencyData?.compositionPattern {
            print("  📍 Composition pattern: \(pattern)")
        }

        // Build enhanced prompt with technical context
        print("🔧 Building enhanced prompt...")
        let enhancedPrompt = buildEnhancedPrompt(
            basePrompt: prompt,
            technicalAnalysis: technicalAnalysis
        )

        // Convert to base64
        print("📸 Converting image to base64...")
        guard let base64 = imageProcessor.imageToBase64(image: processedImage) else {
            print("❌ Failed to convert image to base64")
            throw EvaluationError.imageConversionFailed
        }
        print("✅ Base64 conversion complete (length: \(base64.count) chars)")

        // Call API with enhanced context
        print("🌐 Calling AI API with model: \(currentProvider.model)...")
        let response = try await apiService.evaluateImage(
            imageBase64: base64,
            prompt: enhancedPrompt,
            apiKey: apiKey,
            model: currentProvider.model
        )

        print("📊 [\(timestamp())] AI response received - Score: \(response.overallWeightedScore), Placement: \(response.primaryPlacement)")

        // Store the evaluation with technical metrics and saliency
        print("💾 [\(timestamp())] Starting storeEvaluationResult...")
        try storeEvaluationResult(
            for: imageEval,
            response: response,
            technicalAnalysis: technicalAnalysis,
            saliencyData: saliencyData
        )
        print("💾 [\(timestamp())] storeEvaluationResult complete")
    }

    // MARK: - Cached Formatters

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    private func timestamp() -> String {
        Self.timestampFormatter.string(from: Date())
    }

    // MARK: - Geometry Helpers

    private func rectToDict(_ rect: CGRect) -> [String: Double] {
        ["x": Double(rect.origin.x), "y": Double(rect.origin.y),
         "width": Double(rect.size.width), "height": Double(rect.size.height)]
    }

    private func pointToDict(_ point: CGPoint) -> [String: Double] {
        ["x": Double(point.x), "y": Double(point.y)]
    }

    // MARK: - Evaluation Result Storage

    private func storeEvaluationResult(
        for imageEval: ImageEvaluation,
        response: EvaluationResponse,
        technicalAnalysis: TechnicalAnalysisResult,
        saliencyData: SaliencyStorageData?
    ) throws {
        let previousResult = imageEval.currentEvaluation
        let isReEvaluation = previousResult != nil

        let result = EvaluationResult(context: viewContext)
        result.id = UUID()
        result.evaluationDate = Date()

        populateScores(result, from: response)
        populateCommercialMetadata(result, from: response)
        populateTechnicalMetrics(result, from: technicalAnalysis)
        populateSaliencyData(result, from: saliencyData)
        populateAPIUsage(result, from: response)
        configureProviderMetadata(result, for: imageEval, source: isReEvaluation ? "re-evaluation" : "manual", status: "completed")

        result.estimatedCost = apiService.calculateCost(inputTokens: response.inputTokens, outputTokens: response.outputTokens)

        linkResultToImageEvaluation(result, imageEval: imageEval)
        linkResultToSession(result)

        if isReEvaluation {
            print("Re-evaluated image, previous score: \(previousResult?.overallWeightedScore ?? 0), new score: \(result.overallWeightedScore)")
        }

        updateAPIStats(inputTokens: response.inputTokens, outputTokens: response.outputTokens, cost: result.estimatedCost)
        try viewContext.save()
    }

    private func populateScores(_ result: EvaluationResult, from response: EvaluationResponse) {
        result.compositionScore = response.compositionScore
        result.qualityScore = response.qualityScore
        result.sellabilityScore = response.sellabilityScore
        result.artisticScore = response.artisticScore
        result.overallWeightedScore = response.overallWeightedScore
        result.primaryPlacement = response.primaryPlacement
        result.strengths = response.strengths
        result.improvements = response.improvements
        result.marketComparison = response.marketComparison
        result.technicalInnovations = response.technicalInnovations
        result.printSizeRecommendation = response.printSizeRecommendation
        result.priceTierSuggestion = response.priceTierSuggestion
    }

    private func populateCommercialMetadata(_ result: EvaluationResult, from response: EvaluationResponse) {
        result.title = response.title
        result.descriptionText = response.descriptionText
        result.keywords = response.keywords
        result.altText = response.altText
        result.suggestedCategories = response.suggestedCategories
        result.bestUseCases = response.bestUseCases
        result.suggestedPriceTier = response.suggestedPriceTier
    }

    private func populateTechnicalMetrics(_ result: EvaluationResult, from analysis: TechnicalAnalysisResult) {
        result.technicalSharpness = analysis.metrics.sharpnessScore
        result.technicalBlurType = analysis.metrics.blurType.rawValue
        result.technicalBlurAmount = analysis.metrics.blurAmount
        result.technicalFocusDistribution = analysis.metrics.sharpnessMap.distribution
        result.technicalNoiseLevel = analysis.metrics.noiseLevel
        result.technicalContrast = analysis.metrics.contrastRatio
        result.technicalExposure = analysis.metrics.exposure.distribution
        result.technicalArtisticTechnique = analysis.intent.probableTechnique.rawValue
        result.technicalIntentConfidence = analysis.intent.confidence
    }

    private func populateSaliencyData(_ result: EvaluationResult, from saliencyData: SaliencyStorageData?) {
        guard let saliencyData = saliencyData else { return }

        result.saliencyMapData = saliencyData.mapData
        result.saliencyCompositionPattern = saliencyData.compositionPattern
        result.saliencyAnalysisDate = Date()
        result.saliencyHotspots = saliencyData.hotspots.map { rectToDict($0) }

        if let highestPoint = saliencyData.highestPoint {
            result.saliencyHighestPoint = pointToDict(highestPoint)
        }
        if let centerOfMass = saliencyData.centerOfMass {
            result.saliencyCenterOfMass = pointToDict(centerOfMass)
        }
    }

    private func populateAPIUsage(_ result: EvaluationResult, from response: EvaluationResponse) {
        result.inputTokens = Int32(response.inputTokens)
        result.outputTokens = Int32(response.outputTokens)
        result.rawAIResponse = response.rawResponse
    }

    private func configureProviderMetadata(_ result: EvaluationResult, for imageEval: ImageEvaluation, source: String, status: String) {
        result.provider = currentProvider.identifier
        result.modelIdentifier = currentProvider.model
        result.modelDisplayName = currentProvider.displayName
        result.apiVersion = currentProvider.apiVersion
        result.evaluationSource = source
        result.promptVersion = "v1.0"
        result.imageResolution = Int32(imageResolution)
        result.evaluationStatus = status
        result.evaluationIndex = imageEval.evaluationCount + 1
    }

    private func linkResultToImageEvaluation(_ result: EvaluationResult, imageEval: ImageEvaluation) {
        if let previous = imageEval.currentEvaluation {
            previous.isCurrentEvaluation = false
        }
        result.isCurrentEvaluation = true

        let currentHistory = imageEval.evaluationHistory?.mutableCopy() as? NSMutableSet ?? NSMutableSet()
        currentHistory.add(result)
        imageEval.evaluationHistory = currentHistory.copy() as? NSSet

        result.imageEvaluation = imageEval
        imageEval.currentEvaluation = result
        imageEval.dateLastEvaluated = Date()
        imageEval.evaluationCount += 1

        if imageEval.firstEvaluatedDate == nil {
            imageEval.firstEvaluatedDate = Date()
        }
    }

    private func linkResultToSession(_ result: EvaluationResult) {
        guard let session = currentSession else { return }

        result.session = session
        let currentEvaluations = session.evaluations?.mutableCopy() as? NSMutableSet ?? NSMutableSet()
        currentEvaluations.add(result)
        session.evaluations = currentEvaluations.copy() as? NSSet
    }

    private func updateProgress() {
        currentProgress = Double(currentImageIndex) / Double(totalImages)
    }

    private func buildEnhancedPrompt(basePrompt: String, technicalAnalysis: TechnicalAnalysisResult) -> String {
        var enhancedPrompt = """
        TECHNICAL ANALYSIS PROVIDED:

        Sharpness: \(String(format: "%.1f", technicalAnalysis.metrics.sharpnessScore))/10
        Focus Distribution: \(technicalAnalysis.metrics.sharpnessMap.distribution) (\(Int(technicalAnalysis.metrics.sharpnessMap.sharpnessPercentage * 100))% sharp)
        Blur Type: \(technicalAnalysis.metrics.blurType.rawValue) (intensity: \(String(format: "%.1f", technicalAnalysis.metrics.blurAmount)))
        Depth of Field: \(technicalAnalysis.metrics.depthOfField.estimatedAperture ?? "unknown")
        Subject Isolation: \(String(format: "%.1f", technicalAnalysis.metrics.depthOfField.subjectIsolation))

        Exposure: \(technicalAnalysis.metrics.exposure.distribution)
        - Highlights clipped: \(String(format: "%.1f%%", technicalAnalysis.metrics.exposure.highlightsClipped * 100))
        - Shadows clipped: \(String(format: "%.1f%%", technicalAnalysis.metrics.exposure.shadowsClipped * 100))
        - Dynamic range: \(String(format: "%.1f", technicalAnalysis.metrics.exposure.dynamicRange))

        Contrast: \(String(format: "%.1f", technicalAnalysis.metrics.contrastRatio))
        Saturation: \(String(format: "%.1f", technicalAnalysis.metrics.colorSaturation))
        Monochrome: \(technicalAnalysis.metrics.isMonochrome ? "Yes" : "No")
        Noise Level: \(String(format: "%.1f", technicalAnalysis.metrics.noiseLevel))

        """

        // Add artistic intent if detected
        if technicalAnalysis.intent.isLikelyIntentional {
            enhancedPrompt += """

            ARTISTIC INTENT DETECTED:
            Probable Technique: \(technicalAnalysis.intent.probableTechnique.rawValue.replacingOccurrences(of: "_", with: " "))
            Confidence: \(String(format: "%.0f%%", technicalAnalysis.intent.confidence * 100))
            Evidence:
            \(technicalAnalysis.intent.supportingEvidence.map { "- \($0)" }.joined(separator: "\n"))

            Note: The technical characteristics above appear to be intentional artistic choices. Please evaluate them as creative techniques rather than technical flaws.

            """
        } else if technicalAnalysis.metrics.blurAmount > 0.5 {
            enhancedPrompt += """

            Note: Significant blur detected. Please assess whether this appears to be an intentional artistic choice (motion blur, ICM, soft focus) or an unintended technical issue.

            """
        }

        enhancedPrompt += """

        ---

        \(basePrompt)
        """

        return enhancedPrompt
    }

    @MainActor
    private func completeEvaluation() {
        isProcessing = false
        evaluationQueue.removeAll()

        // Release security-scoped access
        if let folder = activeFolderAccess {
            folder.stopAccessingSecurityScopedResource()
            activeFolderAccess = nil
            print("🔐 Released security-scoped access for folder")
        }

        // Complete the session
        if let session = currentSession {
            session.endDate = Date()
            session.successCount = Int32(successfulEvaluations)
            session.failureCount = Int32(failedEvaluations)

            // Calculate session stats
            if let evaluations = session.evaluations as? Set<EvaluationResult> {
                let totalCost = evaluations.reduce(0.0) { $0 + $1.estimatedCost }
                session.totalCost = totalCost

                let avgTime = evaluations.reduce(0.0) { $0 + $1.processingTimeSeconds } / Double(evaluations.count)
                session.averageProcessingTime = avgTime
            }

            try? viewContext.save()
            currentSession = nil
        }

        if successfulEvaluations > 0 {
            statusMessage = "Evaluation complete: \(successfulEvaluations) successful, \(failedEvaluations) failed"
        } else {
            statusMessage = "Evaluation failed"
        }

        currentProgress = 1.0
    }

    private func getProcessedImageURL(for id: UUID) -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent(Constants.appSupportFolder)
        let processedFolder = appFolder.appendingPathComponent(Constants.processedImagesFolder)
        let imageFolder = processedFolder.appendingPathComponent(id.uuidString)

        // Create directories if needed
        try? FileManager.default.createDirectory(at: imageFolder, withIntermediateDirectories: true)

        return imageFolder.appendingPathComponent("processed.jpg")
    }

    private func createInitialStats() -> APIUsageStats {
        let stats = APIUsageStats(context: viewContext)
        stats.id = UUID()
        stats.lastResetDate = Date()
        stats.totalTokensUsed = 0
        stats.totalCost = 0
        stats.totalImagesEvaluated = 0
        try? viewContext.save()
        return stats
    }

    private func updateAPIStats(inputTokens: Int, outputTokens: Int, cost: Double) {
        guard let stats = getAPIUsageStats() else { return }

        stats.totalTokensUsed += Int64(inputTokens + outputTokens)
        stats.totalCost += cost
        stats.totalImagesEvaluated += 1

        try? viewContext.save()
    }

    // MARK: - Session Management

    private func createEvaluationSession(type: String, imageCount: Int) -> EvaluationSession {
        let session = EvaluationSession(context: viewContext)
        session.id = UUID()
        session.startDate = Date()
        session.sessionType = type
        session.totalImages = Int32(imageCount)
        session.successCount = 0
        session.failureCount = 0
        session.totalCost = 0
        session.providers = [currentProvider.identifier]

        try? viewContext.save()
        return session
    }

    // MARK: - Failed Evaluation Tracking

    private func createFailedEvaluation(
        for imageEval: ImageEvaluation,
        error: Error,
        parentEvaluation: EvaluationResult? = nil
    ) {
        let result = EvaluationResult(context: viewContext)
        result.id = UUID()
        result.evaluationDate = Date()
        result.errorMessage = error.localizedDescription

        if case let APIError.providerSpecificError(message) = error {
            result.errorCode = message
        }

        let source = parentEvaluation != nil ? "retry" : "manual"
        configureProviderMetadata(result, for: imageEval, source: source, status: "failed")

        if let parent = parentEvaluation {
            result.parentEvaluationID = parent.id
            result.retryCount = parent.retryCount + 1
        }

        // Add to history but don't set as current if successful evaluation exists
        let history = imageEval.mutableSetValue(forKey: "evaluationHistory")
        history.add(result)

        if imageEval.currentEvaluation == nil {
            imageEval.currentEvaluation = result
        }

        imageEval.dateLastEvaluated = Date()
        imageEval.evaluationCount += 1

        if imageEval.firstEvaluatedDate == nil {
            imageEval.firstEvaluatedDate = Date()
        }

        linkResultToSession(result)
        try? viewContext.save()
    }
}

// MARK: - Evaluation Error

enum EvaluationError: LocalizedError {
    case missingAPIKey
    case processedImageNotFound
    case imageConversionFailed
    case providerNotImplemented

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API key not found. Please add your API key in Settings."
        case .processedImageNotFound:
            return "Processed image not found"
        case .imageConversionFailed:
            return "Failed to convert image for API"
        case .providerNotImplemented:
            return "This API provider is not yet implemented"
        }
    }
}
