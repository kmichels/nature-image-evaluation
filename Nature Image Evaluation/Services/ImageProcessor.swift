//
//  ImageProcessor.swift
//  Nature Image Evaluation
//
//  Created by Claude Code on 10/27/25.
//

import Foundation
import AppKit
import Accelerate
import UniformTypeIdentifiers

/// High-performance image processing using vImage from Accelerate framework
final class ImageProcessor {

    static let shared = ImageProcessor()

    private init() {}

    // MARK: - Image Resizing

    /// Resize image to maximum dimension while maintaining aspect ratio
    /// - Parameters:
    ///   - image: The original NSImage
    ///   - maxDimension: Maximum dimension in pixels (default from Constants)
    /// - Returns: Resized NSImage or nil if processing fails
    func resizeForEvaluation(image: NSImage, maxDimension: Int = Constants.maxImageDimension) -> NSImage? {
        // Get the original image size
        guard let imageRep = image.bestRepresentation(for: NSRect(origin: .zero, size: image.size),
                                                      context: nil,
                                                      hints: nil) else {
            print("ImageProcessor: Failed to get image representation")
            return nil
        }

        let originalWidth = imageRep.pixelsWide
        let originalHeight = imageRep.pixelsHigh

        // Calculate new dimensions maintaining aspect ratio
        let (newWidth, newHeight) = calculateResizedDimensions(
            originalWidth: originalWidth,
            originalHeight: originalHeight,
            maxDimension: maxDimension
        )

        // If image is already smaller than max dimension, return original
        if originalWidth <= maxDimension && originalHeight <= maxDimension {
            return image
        }

        // Try vImage approach first (faster)
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
           let resizedCGImage = resizeWithVImage(cgImage, targetWidth: newWidth, targetHeight: newHeight) {
            return NSImage(cgImage: resizedCGImage, size: NSSize(width: newWidth, height: newHeight))
        }

        // Fallback: Draw into a new bitmap (works when NSImage is created from Data)
        print("ImageProcessor: Using fallback drawing-based resize")
        return resizeByDrawing(image: image, targetWidth: newWidth, targetHeight: newHeight)
    }

    /// Fallback resize method using NSGraphicsContext drawing
    private func resizeByDrawing(image: NSImage, targetWidth: Int, targetHeight: Int) -> NSImage? {
        let targetSize = NSSize(width: targetWidth, height: targetHeight)
        let newImage = NSImage(size: targetSize)

        newImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: targetSize),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .copy,
                   fraction: 1.0)
        newImage.unlockFocus()

        // Verify the image has content
        guard newImage.isValid else {
            print("ImageProcessor: Fallback resize produced invalid image")
            return nil
        }

        return newImage
    }

    /// Generate thumbnail for gallery display
    /// - Parameters:
    ///   - image: The original NSImage
    ///   - size: Target thumbnail size (default 100x100)
    /// - Returns: Thumbnail NSImage or nil if processing fails
    func generateThumbnail(image: NSImage, size: CGSize = Constants.thumbnailSize) -> NSImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        guard let thumbnailCGImage = resizeWithVImage(
            cgImage,
            targetWidth: Int(size.width),
            targetHeight: Int(size.height),
            maintainAspectRatio: true
        ) else {
            return nil
        }

        return NSImage(cgImage: thumbnailCGImage, size: size)
    }

    // MARK: - Image Conversion

    /// Convert image to base64 string for API transmission
    /// - Parameters:
    ///   - image: The NSImage to convert
    ///   - format: Image format (default JPEG)
    ///   - compressionQuality: JPEG compression quality (0.0-1.0)
    /// - Returns: Base64 encoded string or nil if conversion fails
    func imageToBase64(
        image: NSImage,
        format: NSBitmapImageRep.FileType = .jpeg,
        compressionQuality: CGFloat = Constants.jpegCompressionQuality
    ) -> String? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)

        let properties: [NSBitmapImageRep.PropertyKey: Any] = [
            .compressionFactor: compressionQuality
        ]

        guard let imageData = bitmapRep.representation(using: format, properties: properties) else {
            return nil
        }

        return imageData.base64EncodedString()
    }

    /// Convert thumbnail to data for Core Data storage
    /// - Parameter thumbnail: The thumbnail image
    /// - Returns: Compressed JPEG data
    func thumbnailToData(_ thumbnail: NSImage) -> Data? {
        guard let cgImage = thumbnail.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
    }

    // MARK: - Utility Methods

    /// Calculate aspect ratio
    /// - Parameters:
    ///   - width: Image width
    ///   - height: Image height
    /// - Returns: Aspect ratio as width/height
    func calculateAspectRatio(width: CGFloat, height: CGFloat) -> Double {
        guard height > 0 else { return 1.0 }
        return Double(width / height)
    }

    /// Save processed image to disk
    /// - Parameters:
    ///   - image: The image to save
    ///   - url: Destination URL
    /// - Returns: File size in bytes
    func saveProcessedImage(_ image: NSImage, to url: URL) throws -> Int64 {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw ProcessingError.conversionFailed
        }

        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        guard let imageData = bitmapRep.representation(
            using: .jpeg,
            properties: [.compressionFactor: Constants.jpegCompressionQuality]
        ) else {
            throw ProcessingError.conversionFailed
        }

        try imageData.write(to: url)
        return Int64(imageData.count)
    }

    // MARK: - Private Methods

    private func calculateResizedDimensions(
        originalWidth: Int,
        originalHeight: Int,
        maxDimension: Int
    ) -> (width: Int, height: Int) {
        let aspectRatio = Double(originalWidth) / Double(originalHeight)

        if originalWidth > originalHeight {
            // Landscape
            let newWidth = min(originalWidth, maxDimension)
            let newHeight = Int(Double(newWidth) / aspectRatio)
            return (newWidth, newHeight)
        } else {
            // Portrait or square
            let newHeight = min(originalHeight, maxDimension)
            let newWidth = Int(Double(newHeight) * aspectRatio)
            return (newWidth, newHeight)
        }
    }

    private func resizeWithVImage(
        _ cgImage: CGImage,
        targetWidth: Int,
        targetHeight: Int,
        maintainAspectRatio: Bool = false
    ) -> CGImage? {
        // Create vImage buffers
        var format = vImage_CGImageFormat(
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            colorSpace: nil,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
            version: 0,
            decode: nil,
            renderingIntent: .defaultIntent
        )

        var sourceBuffer = vImage_Buffer()
        var error = vImageBuffer_InitWithCGImage(&sourceBuffer, &format, nil, cgImage, vImage_Flags(kvImageNoFlags))
        guard error == kvImageNoError else { return nil }
        defer { free(sourceBuffer.data) }

        // Calculate final dimensions
        let finalWidth = maintainAspectRatio
            ? min(targetWidth, Int(Double(targetHeight) * (Double(cgImage.width) / Double(cgImage.height))))
            : targetWidth
        let finalHeight = maintainAspectRatio
            ? min(targetHeight, Int(Double(targetWidth) / (Double(cgImage.width) / Double(cgImage.height))))
            : targetHeight

        // Create destination buffer
        var destinationBuffer = vImage_Buffer()
        destinationBuffer.width = vImagePixelCount(finalWidth)
        destinationBuffer.height = vImagePixelCount(finalHeight)
        destinationBuffer.rowBytes = finalWidth * 4
        destinationBuffer.data = UnsafeMutableRawPointer.allocate(
            byteCount: finalHeight * destinationBuffer.rowBytes,
            alignment: 64
        )
        defer { free(destinationBuffer.data) }

        // Perform scaling with high-quality Lanczos resampling
        error = vImageScale_ARGB8888(
            &sourceBuffer,
            &destinationBuffer,
            nil,
            vImage_Flags(kvImageHighQualityResampling)
        )

        guard error == kvImageNoError else { return nil }

        // Create CGImage from vImage buffer
        return vImageCreateCGImageFromBuffer(
            &destinationBuffer,
            &format,
            nil,
            nil,
            vImage_Flags(kvImageNoFlags),
            &error
        )?.takeRetainedValue()
    }
}

// MARK: - Processing Error

enum ProcessingError: LocalizedError {
    case conversionFailed
    case invalidImageData
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .conversionFailed:
            return "Failed to convert image"
        case .invalidImageData:
            return "Invalid image data"
        case .saveFailed:
            return "Failed to save processed image"
        }
    }
}