//
//  SaliencyAnalyzer.swift
//  Nature Image Evaluation
//
//  Created by Claude on 11/13/25.
//

import Foundation
import Vision
import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Combine

/// Analyzes images to generate saliency maps showing areas of visual attention
@MainActor
class SaliencyAnalyzer: ObservableObject {
    static let shared = SaliencyAnalyzer()

    @Published var isProcessing = false
    @Published var lastError: Error?

    private let context = CIContext()

    enum SaliencyError: LocalizedError {
        case imageConversionFailed
        case requestFailed
        case noSaliencyData

        var errorDescription: String? {
            switch self {
            case .imageConversionFailed:
                return "Failed to convert image for analysis"
            case .requestFailed:
                return "Saliency detection request failed"
            case .noSaliencyData:
                return "No saliency data was generated"
            }
        }
    }

    /// Generate an attention-based saliency heatmap for the given image
    func generateSaliencyMap(for image: NSImage) async -> NSImage? {
        isProcessing = true
        defer { isProcessing = false }

        // Convert NSImage to CGImage for Vision Framework
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            lastError = SaliencyError.imageConversionFailed
            return nil
        }

        // Create Vision request for attention-based saliency
        let request = VNGenerateAttentionBasedSaliencyImageRequest()

        // Process the image
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try requestHandler.perform([request])

            // Get the saliency observation
            guard let observation = request.results?.first as? VNSaliencyImageObservation else {
                lastError = SaliencyError.noSaliencyData
                return nil
            }

            // Convert saliency map to heatmap overlay
            return createHeatmapOverlay(from: observation, originalImage: cgImage)

        } catch {
            lastError = error
            print("Saliency detection error: \(error)")
            return nil
        }
    }

    /// Generate both attention and objectness saliency maps
    func generateDualSaliencyMaps(for image: NSImage) async -> (attention: NSImage?, objectness: NSImage?) {
        isProcessing = true
        defer { isProcessing = false }

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            lastError = SaliencyError.imageConversionFailed
            return (nil, nil)
        }

        // Create both types of saliency requests
        let attentionRequest = VNGenerateAttentionBasedSaliencyImageRequest()
        let objectnessRequest = VNGenerateObjectnessBasedSaliencyImageRequest()

        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        var attentionMap: NSImage?
        var objectnessMap: NSImage?

        // Process attention saliency
        do {
            try requestHandler.perform([attentionRequest])
            if let observation = attentionRequest.results?.first as? VNSaliencyImageObservation {
                attentionMap = createHeatmapOverlay(from: observation, originalImage: cgImage)
            }
        } catch {
            print("Attention saliency error: \(error)")
        }

        // Process objectness saliency
        do {
            try requestHandler.perform([objectnessRequest])
            if let observation = objectnessRequest.results?.first as? VNSaliencyImageObservation {
                objectnessMap = createHeatmapOverlay(from: observation, originalImage: cgImage, useBlueColormap: true)
            }
        } catch {
            print("Objectness saliency error: \(error)")
        }

        return (attentionMap, objectnessMap)
    }

    /// Create a heatmap overlay from saliency observation
    private func createHeatmapOverlay(from observation: VNSaliencyImageObservation,
                                     originalImage: CGImage,
                                     useBlueColormap: Bool = false) -> NSImage? {

        // Get the saliency map as a pixelbuffer (non-optional property)
        let pixelBuffer = observation.pixelBuffer

        // Convert pixelbuffer to CIImage
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        // Scale the saliency map to match original image size
        let scaleX = CGFloat(originalImage.width) / ciImage.extent.width
        let scaleY = CGFloat(originalImage.height) / ciImage.extent.height
        let scaledSaliency = ciImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        // Apply color map to create heatmap
        let heatmapImage = applyHeatmapColors(to: scaledSaliency, useBlueColormap: useBlueColormap)

        // Blend with original image
        guard let heatmapCGImage = context.createCGImage(heatmapImage, from: heatmapImage.extent) else {
            return nil
        }

        // Create NSImage from the heatmap
        let finalImage = NSImage(cgImage: heatmapCGImage, size: NSSize(width: originalImage.width, height: originalImage.height))
        return finalImage
    }

    /// Apply heatmap colors to grayscale saliency map
    private func applyHeatmapColors(to saliencyImage: CIImage, useBlueColormap: Bool) -> CIImage {
        // Create a false color filter to convert grayscale to heatmap
        let filter = CIFilter.falseColor()
        filter.inputImage = saliencyImage

        if useBlueColormap {
            // Blue colormap for objectness
            filter.color0 = CIColor(red: 0, green: 0, blue: 0, alpha: 0) // Transparent for low values
            filter.color1 = CIColor(red: 0, green: 0.5, blue: 1, alpha: 0.8) // Blue for high values
        } else {
            // Red/Yellow heatmap for attention
            filter.color0 = CIColor(red: 0, green: 0, blue: 0.5, alpha: 0.3) // Dark blue for low values
            filter.color1 = CIColor(red: 1, green: 0, blue: 0, alpha: 0.8) // Red for high values
        }

        guard let outputImage = filter.outputImage else {
            return saliencyImage
        }

        // Apply some smoothing for better visual appeal
        let gaussianBlur = CIFilter.gaussianBlur()
        gaussianBlur.inputImage = outputImage
        gaussianBlur.radius = 5.0

        return gaussianBlur.outputImage ?? outputImage
    }

    /// Generate a combined overlay with both attention and objectness
    func generateCombinedSaliencyOverlay(for image: NSImage) async -> NSImage? {
        let maps = await generateDualSaliencyMaps(for: image)

        guard let attentionMap = maps.attention,
              let objectnessMap = maps.objectness else {
            return maps.attention ?? maps.objectness
        }

        // Combine both maps into a single overlay
        return combineImages(attention: attentionMap, objectness: objectnessMap)
    }

    /// Combine attention and objectness maps
    private func combineImages(attention: NSImage, objectness: NSImage) -> NSImage? {
        let size = attention.size
        let combinedImage = NSImage(size: size)

        combinedImage.lockFocus()

        // Draw attention map first
        attention.draw(in: NSRect(origin: .zero, size: size),
                      from: NSRect(origin: .zero, size: attention.size),
                      operation: .sourceOver,
                      fraction: 0.6)

        // Overlay objectness map with lower opacity
        objectness.draw(in: NSRect(origin: .zero, size: size),
                       from: NSRect(origin: .zero, size: objectness.size),
                       operation: .sourceOver,
                       fraction: 0.4)

        combinedImage.unlockFocus()

        return combinedImage
    }

    /// Get the most salient regions as normalized rectangles
    func getSalientRegions(from observation: VNSaliencyImageObservation, threshold: Float = 0.5) -> [CGRect] {
        guard let salientObjects = observation.salientObjects else {
            return []
        }

        // Filter by confidence and convert to CGRect
        return salientObjects
            .filter { $0.confidence > threshold }
            .map { $0.boundingBox }
    }
}