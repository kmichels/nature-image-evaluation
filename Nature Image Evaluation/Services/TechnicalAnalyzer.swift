//
//  TechnicalAnalyzer.swift
//  Nature Image Evaluation
//
//  Provides objective technical metrics without quality judgments
//  Uses Core Image and Vision frameworks for local analysis
//

import Foundation
import CoreImage
import Vision
import AppKit
import Metal
import Combine

/// Types of blur detected in images
enum BlurType: String {
    case none = "none"
    case motion = "motion"          // Directional blur from camera/subject movement
    case gaussian = "gaussian"      // Uniform soft focus
    case lens = "lens"              // Bokeh/depth of field
    case mixed = "mixed"            // Multiple blur types present
}

/// Probable artistic techniques detected
enum ArtisticTechnique: String {
    case shallowDOF = "shallow_dof"           // Portrait/macro style
    case motionBlur = "motion_blur"           // Panning, ICM
    case longExposure = "long_exposure"       // Smooth water/clouds
    case softFocus = "soft_focus"             // Dreamy/ethereal
    case multipleExposure = "multiple_exposure" // Artistic overlay
    case tiltShift = "tilt_shift"             // Miniature effect
    case ortonEffect = "orton_effect"         // Glow with maintained contrast
    case none = "none"
}

/// Focus distribution across the image
struct FocusMap {
    let sharpRegions: [CGRect]      // Areas in focus
    let sharpnessPercentage: Float  // Overall percentage of sharp areas
    let centerSharpness: Float      // Sharpness at image center
    let edgeSharpness: Float        // Average sharpness at edges
    let distribution: String         // "center-weighted", "edge-focused", "uniform", "selective"
}

/// Depth of field characteristics
struct DOFCharacteristics {
    let estimatedAperture: String?  // e.g., "f/1.4 - f/2.8" based on blur characteristics
    let bokehQuality: Float         // 0-1, quality of out-of-focus areas
    let subjectIsolation: Float     // 0-1, how well subject stands out
}

/// Exposure analysis results
struct ExposureAnalysis {
    let averageEV: Float            // Exposure value relative to ideal
    let highlightsClipped: Float    // Percentage of blown highlights
    let shadowsClipped: Float       // Percentage of blocked shadows
    let dynamicRange: Float         // Utilized dynamic range (0-1)
    let distribution: String        // "low-key", "high-key", "balanced", "contrasty"
}

/// Objective technical measurements
struct TechnicalMetrics {
    let sharpnessScore: Float       // 0-10 overall sharpness
    let sharpnessMap: FocusMap     // Detailed focus distribution
    let blurType: BlurType          // Type of blur detected
    let blurAmount: Float           // 0-1 blur intensity
    let noiseLevel: Float           // 0-1 noise amount
    let contrastRatio: Float        // Dynamic range utilization
    let exposure: ExposureAnalysis  // Exposure characteristics
    let colorSaturation: Float      // 0-1 saturation level
    let dominantColors: [NSColor]   // Main colors in image
    let isMonochrome: Bool          // B&W or color
    let depthOfField: DOFCharacteristics
}

/// Artistic intent indicators
struct ArtisticIntent {
    let probableTechnique: ArtisticTechnique
    let confidence: Float           // 0-1 confidence in detection
    let isLikelyIntentional: Bool   // Whether "flaws" appear intentional
    let supportingEvidence: [String] // Reasons for the assessment
}

/// Complete technical analysis result
struct TechnicalAnalysisResult {
    let metrics: TechnicalMetrics
    let intent: ArtisticIntent
    let saliencyMap: CIImage?       // Visual attention map
    let histogram: [Int]             // Luminance histogram
    let analysisTime: TimeInterval  // Time taken to analyze
}

/// Analyzes images for technical metrics without making quality judgments
@MainActor
class TechnicalAnalyzer: ObservableObject {
    static let shared = TechnicalAnalyzer()

    // Core Image context for GPU acceleration
    private let ciContext: CIContext

    // Filters
    private lazy var laplacianFilter = CIFilter(name: "CILaplacian")
    private lazy var sobelFilter = CIFilter(name: "CISobelEdgeDetection")
    private lazy var histogramFilter = CIFilter(name: "CIAreaHistogram")
    private lazy var averageFilter = CIFilter(name: "CIAreaAverage")

    private init() {
        // Use Metal for GPU acceleration if available
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            ciContext = CIContext(mtlDevice: metalDevice)
            print("Technical analyzer using Metal GPU acceleration")
        } else {
            ciContext = CIContext(options: [.useSoftwareRenderer: false])
            print("Technical analyzer using CPU rendering")
        }
    }

    // MARK: - Public Methods

    /// Analyze an image for technical metrics
    func analyzeImage(_ nsImage: NSImage) async throws -> TechnicalAnalysisResult {
        let startTime = Date()

        guard let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw TechnicalAnalysisError.imageConversionFailed
        }

        let ciImage = CIImage(cgImage: cgImage)

        // Run analyses in parallel
        async let metrics = extractMetrics(from: ciImage)
        async let saliency = generateSaliencyMap(from: cgImage)
        async let histogram = extractHistogram(from: ciImage)

        // Get results
        let technicalMetrics = try await metrics
        let saliencyMap = try? await saliency
        let histogramData = try await histogram

        // Analyze artistic intent based on metrics
        let intent = detectArtisticIntent(from: technicalMetrics)

        let analysisTime = Date().timeIntervalSince(startTime)

        return TechnicalAnalysisResult(
            metrics: technicalMetrics,
            intent: intent,
            saliencyMap: saliencyMap,
            histogram: histogramData,
            analysisTime: analysisTime
        )
    }

    // MARK: - Metrics Extraction

    private func extractMetrics(from image: CIImage) async throws -> TechnicalMetrics {
        // Calculate sharpness using Laplacian variance
        let sharpnessScore = calculateSharpness(from: image)

        // Analyze focus distribution
        let focusMap = analyzeFocusDistribution(from: image)

        // Detect blur type and amount
        let (blurType, blurAmount) = detectBlurCharacteristics(from: image)

        // Estimate noise level
        let noiseLevel = estimateNoise(from: image)

        // Calculate contrast
        let contrastRatio = calculateContrast(from: image)

        // Analyze exposure
        let exposure = analyzeExposure(from: image)

        // Extract color information
        let (saturation, colors, isMonochrome) = analyzeColors(from: image)

        // Estimate depth of field
        let dof = estimateDepthOfField(from: image, focusMap: focusMap)

        return TechnicalMetrics(
            sharpnessScore: sharpnessScore,
            sharpnessMap: focusMap,
            blurType: blurType,
            blurAmount: blurAmount,
            noiseLevel: noiseLevel,
            contrastRatio: contrastRatio,
            exposure: exposure,
            colorSaturation: saturation,
            dominantColors: colors,
            isMonochrome: isMonochrome,
            depthOfField: dof
        )
    }

    // MARK: - Sharpness Analysis

    private func calculateSharpness(from image: CIImage) -> Float {
        // Downsample image if it's too large for histogram analysis (max 32768 pixels)
        let maxDimension: CGFloat = 2048  // Safe size that won't exceed histogram limits
        var workingImage = image

        if image.extent.width > maxDimension || image.extent.height > maxDimension {
            let scale = min(maxDimension / image.extent.width, maxDimension / image.extent.height)
            workingImage = image.applyingFilter("CILanczosScaleTransform", parameters: [
                "inputScale": scale,
                "inputAspectRatio": 1.0
            ])
        }

        // Convert to grayscale first for better edge detection
        let grayscale = workingImage.applyingFilter("CIColorControls", parameters: [
            "inputSaturation": 0
        ])

        // Apply Sobel edge detection which is more reliable than CIEdges
        let convolution = grayscale.applyingFilter("CIConvolution3X3", parameters: [
            "inputWeights": CIVector(values: [-1, 0, 1, -2, 0, 2, -1, 0, 1], count: 9),
            "inputBias": 0.5
        ])

        // IMPORTANT: Convolution filters can create infinite extents, we must crop to original bounds
        let edges = convolution.cropped(to: workingImage.extent)

        // Use area histogram to analyze edge distribution instead of average
        let histogram = CIFilter(name: "CIAreaHistogram")!
        histogram.setValue(edges, forKey: kCIInputImageKey)
        histogram.setValue(CIVector(cgRect: edges.extent), forKey: "inputExtent")
        histogram.setValue(64, forKey: "inputCount")
        histogram.setValue(1.0, forKey: "inputScale")

        guard let histogramOutput = histogram.outputImage else {
            print("⚠️ Failed to generate histogram - extent: \(edges.extent)")
            return 5.0
        }

        // Sample histogram to get edge strength distribution
        var histData = [Float](repeating: 0, count: 64 * 4) // 64 pixels * 4 channels
        ciContext.render(histogramOutput,
                        toBitmap: &histData,
                        rowBytes: 64 * 16, // 64 pixels * 16 bytes per pixel (4 floats * 4 bytes)
                        bounds: CGRect(x: 0, y: 0, width: 64, height: 1),
                        format: .RGBAf,
                        colorSpace: nil)

        // Calculate weighted edge strength
        // Higher bins = stronger edges = sharper image
        var totalWeight: Float = 0
        var weightedSum: Float = 0

        for i in 0..<64 {
            // Read the red channel value (every 4th value starting at index i*4)
            let binValue = histData[i * 4]
            let binPosition = Float(i) / 64.0
            weightedSum += binValue * binPosition
            totalWeight += binValue
        }

        if totalWeight > 0 {
            let avgPosition = weightedSum / totalWeight
            // Map average position to sharpness score
            // Images with edges in higher bins are sharper
            let sharpness = min(10, avgPosition * 20)
            print("📊 Sharpness: weighted avg position = \(avgPosition), score = \(sharpness)")
            return sharpness
        }

        return 5.0 // Default middle value
    }

    // MARK: - Focus Distribution Analysis

    private func analyzeFocusDistribution(from image: CIImage) -> FocusMap {
        // Divide image into grid and analyze sharpness in each region
        let gridSize = 10
        let extent = image.extent
        let cellWidth = extent.width / CGFloat(gridSize)
        let cellHeight = extent.height / CGFloat(gridSize)

        var sharpRegions: [CGRect] = []
        var sharpCells = 0
        var centerSharpness: Float = 0
        var edgeSharpness: Float = 0
        var edgeCount = 0

        for row in 0..<gridSize {
            for col in 0..<gridSize {
                let x = extent.minX + CGFloat(col) * cellWidth
                let y = extent.minY + CGFloat(row) * cellHeight
                let cellRect = CGRect(x: x, y: y, width: cellWidth, height: cellHeight)

                // Crop and analyze cell
                let croppedImage = image.cropped(to: cellRect)
                let cellSharpness = calculateSharpness(from: croppedImage)

                // Mark as sharp if above threshold
                if cellSharpness > 5.0 {
                    sharpRegions.append(cellRect)
                    sharpCells += 1
                }

                // Track center vs edge sharpness
                let isCenter = (row >= 3 && row <= 6 && col >= 3 && col <= 6)
                let isEdge = (row == 0 || row == gridSize-1 || col == 0 || col == gridSize-1)

                if isCenter {
                    centerSharpness = max(centerSharpness, cellSharpness)
                } else if isEdge {
                    edgeSharpness += cellSharpness
                    edgeCount += 1
                }
            }
        }

        if edgeCount > 0 {
            edgeSharpness /= Float(edgeCount)
        }

        let sharpnessPercentage = Float(sharpCells) / Float(gridSize * gridSize)

        // Determine distribution pattern
        let distribution: String
        if centerSharpness > edgeSharpness * 1.5 {
            distribution = "center-weighted"
        } else if edgeSharpness > centerSharpness * 1.5 {
            distribution = "edge-focused"
        } else if sharpnessPercentage > 0.7 {
            distribution = "uniform"
        } else {
            distribution = "selective"
        }

        return FocusMap(
            sharpRegions: sharpRegions,
            sharpnessPercentage: sharpnessPercentage,
            centerSharpness: centerSharpness,
            edgeSharpness: edgeSharpness,
            distribution: distribution
        )
    }

    // MARK: - Blur Detection

    private func detectBlurCharacteristics(from image: CIImage) -> (BlurType, Float) {
        // Calculate overall sharpness
        let overallSharpness = calculateSharpness(from: image)

        // Blur amount is inverse of sharpness
        let blurAmount = max(0, min(1, 1.0 - (overallSharpness / 10.0)))

        // Determine blur type based on amount and distribution
        let blurType: BlurType
        if blurAmount < 0.2 {
            blurType = .none
        } else if blurAmount > 0.7 {
            // High blur - check if uniform or directional
            // For now, assume gaussian (uniform soft focus)
            blurType = .gaussian
        } else {
            // Moderate blur - likely depth of field
            blurType = .lens
        }

        return (blurType, blurAmount)
    }

    // MARK: - Other Metrics

    private func estimateNoise(from image: CIImage) -> Float {
        // Downsample for performance if image is large
        let maxDimension: CGFloat = 1024
        var workingImage = image

        if image.extent.width > maxDimension || image.extent.height > maxDimension {
            let scale = min(maxDimension / image.extent.width, maxDimension / image.extent.height)
            workingImage = image.applyingFilter("CILanczosScaleTransform", parameters: [
                "inputScale": scale,
                "inputAspectRatio": 1.0
            ])
        }

        // Use a high-pass filter to isolate noise
        let noiseReduction = workingImage.applyingFilter("CINoiseReduction", parameters: [
            "inputNoiseLevel": 0.02,
            "inputSharpness": 0.4
        ])

        // Calculate difference between original and denoised to estimate noise
        let difference = CIFilter(name: "CIDifferenceBlendMode")!
        difference.setValue(workingImage, forKey: kCIInputImageKey)
        difference.setValue(noiseReduction, forKey: kCIInputBackgroundImageKey)

        guard let diffImage = difference.outputImage else { return 0.1 }

        // Sample the difference image
        let sampleCount = 100
        var noiseSum: Float = 0
        let extent = diffImage.extent

        for _ in 0..<sampleCount {
            let x = CGFloat.random(in: 0..<extent.width)
            let y = CGFloat.random(in: 0..<extent.height)

            var pixel = [UInt8](repeating: 0, count: 4)
            ciContext.render(diffImage,
                           toBitmap: &pixel,
                           rowBytes: 4,
                           bounds: CGRect(x: x, y: y, width: 1, height: 1),
                           format: .RGBA8,
                           colorSpace: CGColorSpaceCreateDeviceRGB())

            // Calculate luminance difference
            let luminance = (Float(pixel[0]) + Float(pixel[1]) + Float(pixel[2])) / (3.0 * 255.0)
            noiseSum += luminance
        }

        let noiseLevel = noiseSum / Float(sampleCount)

        // Map to 0-1 scale where 0 is no noise, 1 is extreme noise
        return min(1.0, noiseLevel * 10)
    }

    private func calculateContrast(from image: CIImage) -> Float {
        // Calculate histogram statistics for contrast estimation
        let extent = image.extent
        guard extent.width > 0 && extent.height > 0 else { return 1.0 }

        // Sample luminance values
        let sampleCount = 200
        var luminanceValues: [Float] = []

        for _ in 0..<sampleCount {
            let x = CGFloat.random(in: 0..<extent.width)
            let y = CGFloat.random(in: 0..<extent.height)

            var pixel = [UInt8](repeating: 0, count: 4)
            ciContext.render(image,
                           toBitmap: &pixel,
                           rowBytes: 4,
                           bounds: CGRect(x: x, y: y, width: 1, height: 1),
                           format: .RGBA8,
                           colorSpace: CGColorSpaceCreateDeviceRGB())

            // Calculate luminance
            let r = Float(pixel[0]) / 255.0
            let g = Float(pixel[1]) / 255.0
            let b = Float(pixel[2]) / 255.0
            let luminance = r * 0.299 + g * 0.587 + b * 0.114
            luminanceValues.append(luminance)
        }

        // Calculate standard deviation as measure of contrast
        let mean = luminanceValues.reduce(0, +) / Float(luminanceValues.count)
        let variance = luminanceValues.map { pow($0 - mean, 2) }.reduce(0, +) / Float(luminanceValues.count)
        let stdDev = sqrt(variance)

        // Weber contrast ratio approximation
        // Higher std dev = higher contrast
        let contrastRatio = stdDev * 10

        return max(1.0, contrastRatio)
    }

    private func analyzeExposure(from image: CIImage) -> ExposureAnalysis {
        // Sample image to analyze brightness distribution
        let sampleCount = 200
        var luminanceValues: [Float] = []

        for _ in 0..<sampleCount {
            let x = CGFloat.random(in: 0..<image.extent.width)
            let y = CGFloat.random(in: 0..<image.extent.height)

            var pixel = [UInt8](repeating: 0, count: 4)
            ciContext.render(image,
                           toBitmap: &pixel,
                           rowBytes: 4,
                           bounds: CGRect(x: x, y: y, width: 1, height: 1),
                           format: .RGBA8,
                           colorSpace: CGColorSpaceCreateDeviceRGB())

            let luminance = (Float(pixel[0]) * 0.299 + Float(pixel[1]) * 0.587 + Float(pixel[2]) * 0.114) / 255.0
            luminanceValues.append(luminance)
        }

        // Calculate statistics
        let mean = luminanceValues.reduce(0, +) / Float(luminanceValues.count)
        let highlightsClipped = Float(luminanceValues.filter { $0 > 0.95 }.count) / Float(luminanceValues.count)
        let shadowsClipped = Float(luminanceValues.filter { $0 < 0.05 }.count) / Float(luminanceValues.count)

        // Determine exposure distribution
        let distribution: String
        if mean < 0.3 {
            distribution = "underexposed"
        } else if mean > 0.7 {
            distribution = "overexposed"
        } else if highlightsClipped > 0.1 && shadowsClipped > 0.1 {
            distribution = "high-contrast"
        } else {
            distribution = "balanced"
        }

        // Calculate dynamic range (simplified)
        let sortedValues = luminanceValues.sorted()
        let percentile5 = sortedValues[Int(Float(sortedValues.count) * 0.05)]
        let percentile95 = sortedValues[Int(Float(sortedValues.count) * 0.95)]
        let dynamicRange = percentile95 - percentile5

        return ExposureAnalysis(
            averageEV: (mean - 0.5) * 4, // Map to approximate EV scale
            highlightsClipped: highlightsClipped,
            shadowsClipped: shadowsClipped,
            dynamicRange: dynamicRange,
            distribution: distribution
        )
    }

    private func analyzeColors(from image: CIImage) -> (Float, [NSColor], Bool) {
        // Sample colors from the image
        var colors: [NSColor] = []
        var saturationSum: Float = 0
        let sampleCount = 50

        for _ in 0..<sampleCount {
            let x = CGFloat.random(in: 0..<image.extent.width)
            let y = CGFloat.random(in: 0..<image.extent.height)

            var pixel = [UInt8](repeating: 0, count: 4)
            ciContext.render(image,
                           toBitmap: &pixel,
                           rowBytes: 4,
                           bounds: CGRect(x: x, y: y, width: 1, height: 1),
                           format: .RGBA8,
                           colorSpace: CGColorSpaceCreateDeviceRGB())

            let color = NSColor(red: CGFloat(pixel[0])/255.0,
                               green: CGFloat(pixel[1])/255.0,
                               blue: CGFloat(pixel[2])/255.0,
                               alpha: 1.0)

            // Calculate saturation
            var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0
            color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)
            saturationSum += Float(saturation)

            colors.append(color)
        }

        let avgSaturation = saturationSum / Float(sampleCount)
        let isMonochrome = avgSaturation < 0.1

        // Get dominant colors by clustering (simplified - just take most distinct)
        var dominantColors: [NSColor] = []
        if !colors.isEmpty {
            dominantColors.append(colors[0])
            for color in colors {
                var isDifferent = true
                for dominant in dominantColors {
                    if colorDistance(color, dominant) < 0.3 {
                        isDifferent = false
                        break
                    }
                }
                if isDifferent && dominantColors.count < 5 {
                    dominantColors.append(color)
                }
            }
        }

        return (avgSaturation, dominantColors, isMonochrome)
    }

    private func colorDistance(_ c1: NSColor, _ c2: NSColor) -> CGFloat {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0

        c1.getRed(&r1, green: &g1, blue: &b1, alpha: nil)
        c2.getRed(&r2, green: &g2, blue: &b2, alpha: nil)

        let dr = r1 - r2
        let dg = g1 - g2
        let db = b1 - b2

        return sqrt(dr*dr + dg*dg + db*db)
    }

    private func estimateDepthOfField(from image: CIImage, focusMap: FocusMap) -> DOFCharacteristics {
        // Estimate DOF based on blur patterns
        let isolation = focusMap.distribution == "center-weighted" ? 0.8 : 0.3

        return DOFCharacteristics(
            estimatedAperture: focusMap.sharpnessPercentage < 0.3 ? "f/1.4 - f/2.8" : "f/5.6 - f/8",
            bokehQuality: 0.7,
            subjectIsolation: Float(isolation)
        )
    }

    // MARK: - Histogram Extraction

    private func extractHistogram(from image: CIImage) async throws -> [Int] {
        guard let histogram = histogramFilter else { return [] }

        histogram.setValue(image, forKey: kCIInputImageKey)
        histogram.setValue(CIVector(cgRect: image.extent), forKey: "inputExtent")
        histogram.setValue(256, forKey: "inputCount")

        guard let outputImage = histogram.outputImage else { return [] }

        // Extract histogram data
        var histogramData = [Float](repeating: 0, count: 256 * 4) // 256 pixels * 4 channels
        ciContext.render(outputImage,
                       toBitmap: &histogramData,
                       rowBytes: 256 * 16, // 256 pixels * 16 bytes per pixel (4 floats * 4 bytes)
                       bounds: CGRect(x: 0, y: 0, width: 256, height: 1),
                       format: .RGBAf,
                       colorSpace: nil)

        // Extract just the red channel values (every 4th value)
        var result: [Int] = []
        for i in 0..<256 {
            result.append(Int(histogramData[i * 4] * 1000))
        }
        return result
    }

    // MARK: - Saliency Detection

    private func generateSaliencyMap(from cgImage: CGImage) async throws -> CIImage? {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNGenerateAttentionBasedSaliencyImageRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observation = request.results?.first as? VNSaliencyImageObservation else {
                    continuation.resume(returning: nil)
                    return
                }

                let pixelBuffer = observation.pixelBuffer

                let saliencyImage = CIImage(cvPixelBuffer: pixelBuffer)
                continuation.resume(returning: saliencyImage)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Artistic Intent Detection

    private func detectArtisticIntent(from metrics: TechnicalMetrics) -> ArtisticIntent {
        var technique: ArtisticTechnique = .none
        var confidence: Float = 0
        var evidence: [String] = []

        // Shallow DOF detection
        if metrics.sharpnessMap.distribution == "center-weighted" &&
           metrics.sharpnessMap.sharpnessPercentage < 0.4 &&
           metrics.depthOfField.subjectIsolation > 0.6 {
            technique = .shallowDOF
            confidence = 0.8
            evidence.append("Strong center focus with blurred edges")
            evidence.append("High subject isolation")
        }

        // Motion blur detection
        else if metrics.blurType == .motion && metrics.blurAmount > 0.5 {
            technique = .motionBlur
            confidence = 0.7
            evidence.append("Directional blur pattern detected")

            if metrics.sharpnessMap.sharpnessPercentage < 0.1 {
                evidence.append("Consistent blur suggests intentional camera movement")
            }
        }

        // Soft focus / Orton effect
        else if metrics.blurType == .gaussian &&
                metrics.blurAmount > 0.3 &&
                metrics.contrastRatio > 0.5 {
            technique = .ortonEffect
            confidence = 0.6
            evidence.append("Uniform softness with maintained contrast")
            evidence.append("Characteristic glow in highlights")
        }

        // Long exposure
        else if metrics.blurType == .motion &&
                metrics.exposure.distribution == "balanced" &&
                metrics.sharpnessMap.sharpnessPercentage > 0.5 {
            technique = .longExposure
            confidence = 0.7
            evidence.append("Motion blur in specific regions only")
            evidence.append("Static elements remain sharp")
        }

        let isLikelyIntentional = confidence > 0.5

        return ArtisticIntent(
            probableTechnique: technique,
            confidence: confidence,
            isLikelyIntentional: isLikelyIntentional,
            supportingEvidence: evidence
        )
    }
}

// MARK: - Error Types

enum TechnicalAnalysisError: LocalizedError {
    case imageConversionFailed
    case analysisTimeout
    case insufficientImageData

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Failed to convert image for analysis"
        case .analysisTimeout:
            return "Technical analysis timed out"
        case .insufficientImageData:
            return "Image contains insufficient data for analysis"
        }
    }
}