//
//  ImageDetailView.swift
//  Nature Image Evaluation
//
//  Created by Claude Code on 10/28/25.
//

import SwiftUI
import CoreData

struct ImageDetailView: View {
    let evaluation: ImageEvaluation
    @Environment(\.dismiss) private var dismiss
    @State private var displayedImage: NSImage?
    @State private var selectedTab: DetailTab = .evaluation
    @State private var hasLoadedImage = false

    init(evaluation: ImageEvaluation) {
        self.evaluation = evaluation
        print("🟢 ImageDetailView.init")
        print("  - Image ID: \(evaluation.id?.uuidString ?? "unknown")")
        print("  - Has processed path: \(evaluation.processedFilePath != nil)")
        print("  - Has original path: \(evaluation.originalFilePath != nil)")
        print("  - Has thumbnail: \(evaluation.thumbnailData != nil)")
    }

    enum DetailTab: String, CaseIterable {
        case evaluation = "Evaluation"
        case technical = "Technical"
        case commercial = "Commercial"
        case raw = "Raw Response"
    }

    var body: some View {
        let _ = print("🟡 ImageDetailView.body called, displayedImage: \(displayedImage != nil), hasLoadedImage: \(hasLoadedImage)")
        return HSplitView {
            // Left side - Image
            VStack {
                if let image = displayedImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ProgressView("Loading image...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .task {
                            print("🟠 ProgressView.task triggered, hasLoadedImage: \(hasLoadedImage)")
                            if !hasLoadedImage {
                                loadImage()
                            }
                        }
                }

                // Image metadata
                HStack(spacing: 20) {
                    if evaluation.originalWidth > 0 && evaluation.originalHeight > 0 {
                        Label("\(evaluation.originalWidth) × \(evaluation.originalHeight)", systemImage: "aspectratio")
                            .font(.caption)
                    }

                    if evaluation.fileSize > 0 {
                        Label(formatFileSize(evaluation.fileSize), systemImage: "doc")
                            .font(.caption)
                    }

                    if let date = evaluation.dateAdded {
                        Label(formatDate(date), systemImage: "calendar")
                            .font(.caption)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(NSColor.controlBackgroundColor))
            }
            .frame(minWidth: 400)

            // Right side - Details
            VStack(spacing: 0) {
                // Header with scores
                VStack(spacing: 16) {
                    HStack {
                        Text(getImageName())
                            .font(.title2.bold())

                        Spacer()

                        if let placement = evaluation.currentEvaluation?.primaryPlacement {
                            PlacementBadge(placement: placement)
                        }

                        Button("Done") {
                            dismiss()
                        }
                        .keyboardShortcut(.escape)
                    }

                    if let result = evaluation.currentEvaluation {
                        // Overall Score
                        VStack(spacing: 8) {
                            Text(String(format: "%.1f", result.overallWeightedScore))
                                .font(.system(size: 48, weight: .bold))
                                .foregroundStyle(scoreColor(result.overallWeightedScore))

                            Text("Overall Score")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        // Individual Scores
                        HStack(spacing: 20) {
                            ScoreItem(label: "Composition", score: result.compositionScore, weight: 30)
                            ScoreItem(label: "Quality", score: result.qualityScore, weight: 25)
                            ScoreItem(label: "Sellability", score: result.sellabilityScore, weight: 25)
                            ScoreItem(label: "Artistic", score: result.artisticScore, weight: 20)
                        }
                    }
                }
                .padding(20)
                .background(Color(NSColor.windowBackgroundColor))

                Divider()

                // Tab View for detailed content
                TabView(selection: $selectedTab) {
                    // Evaluation Tab
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            if let result = evaluation.currentEvaluation {
                                // Strengths
                                if let strengths = result.strengths, !strengths.isEmpty {
                                    DetailSection(title: "Strengths", icon: "checkmark.circle.fill", color: .green) {
                                        ForEach(strengths, id: \.self) { strength in
                                            HStack(alignment: .top) {
                                                Image(systemName: "chevron.right")
                                                    .font(.caption)
                                                    .foregroundStyle(.green)
                                                Text(strength)
                                                    .font(.body)
                                            }
                                        }
                                    }
                                }

                                // Improvements
                                if let improvements = result.improvements, !improvements.isEmpty {
                                    DetailSection(title: "Areas for Improvement", icon: "exclamationmark.triangle.fill", color: .orange) {
                                        ForEach(improvements, id: \.self) { improvement in
                                            HStack(alignment: .top) {
                                                Image(systemName: "chevron.right")
                                                    .font(.caption)
                                                    .foregroundStyle(.orange)
                                                Text(improvement)
                                                    .font(.body)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                    .tabItem {
                        Label("Evaluation", systemImage: "star.fill")
                    }
                    .tag(DetailTab.evaluation)

                    // Technical Tab
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            if let result = evaluation.currentEvaluation {
                                // Technical Innovations
                                if let innovations = result.technicalInnovations, !innovations.isEmpty {
                                    DetailSection(title: "Technical Innovations", icon: "camera.aperture", color: .blue) {
                                        ForEach(innovations, id: \.self) { innovation in
                                            HStack(alignment: .top) {
                                                Image(systemName: "chevron.right")
                                                    .font(.caption)
                                                    .foregroundStyle(.blue)
                                                Text(innovation)
                                                    .font(.body)
                                            }
                                        }
                                    }
                                }

                                // Print Size Recommendation
                                if let printSize = result.printSizeRecommendation {
                                    DetailSection(title: "Print Size Recommendation", icon: "printer.fill", color: .purple) {
                                        Text(printSize)
                                            .font(.body)
                                    }
                                }
                            }

                            // Processing Details
                            DetailSection(title: "Processing Details", icon: "gearshape.2.fill", color: .gray) {
                                VStack(alignment: .leading, spacing: 8) {
                                    if evaluation.processedWidth > 0 && evaluation.processedHeight > 0 {
                                        HStack {
                                            Text("Processed Size:")
                                                .foregroundStyle(.secondary)
                                            Text("\(evaluation.processedWidth) × \(evaluation.processedHeight)")
                                        }
                                    }

                                    if evaluation.aspectRatio > 0 {
                                        HStack {
                                            Text("Aspect Ratio:")
                                                .foregroundStyle(.secondary)
                                            Text(String(format: "%.2f:1", evaluation.aspectRatio))
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                    .tabItem {
                        Label("Technical", systemImage: "gearshape.2")
                    }
                    .tag(DetailTab.technical)

                    // Commercial Tab
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            if let result = evaluation.currentEvaluation {
                                // Market Comparison
                                if let market = result.marketComparison {
                                    DetailSection(title: "Market Analysis", icon: "chart.line.uptrend.xyaxis", color: .green) {
                                        Text(market)
                                            .font(.body)
                                    }
                                }

                                // Price Tier
                                if let priceTier = result.priceTierSuggestion {
                                    DetailSection(title: "Price Tier", icon: "dollarsign.circle.fill", color: .green) {
                                        HStack {
                                            PriceTierIndicator(tier: priceTier)
                                            Spacer()
                                        }
                                    }
                                }

                                // Cost Analysis
                                if result.estimatedCost > 0 {
                                    DetailSection(title: "Evaluation Cost", icon: "creditcard.fill", color: .blue) {
                                        VStack(alignment: .leading, spacing: 8) {
                                            if result.inputTokens > 0 || result.outputTokens > 0 {
                                                HStack {
                                                    Text("Tokens Used:")
                                                        .foregroundStyle(.secondary)
                                                    Text("\(result.inputTokens) in / \(result.outputTokens) out")
                                                }
                                            }
                                            HStack {
                                                Text("API Cost:")
                                                    .foregroundStyle(.secondary)
                                                Text(String(format: "$%.4f", result.estimatedCost))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                    .tabItem {
                        Label("Commercial", systemImage: "dollarsign.circle")
                    }
                    .tag(DetailTab.commercial)

                    // Raw Response Tab
                    ScrollView {
                        if let rawResponse = evaluation.currentEvaluation?.rawAIResponse {
                            Text(rawResponse)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .padding()
                        } else {
                            Text("No raw response available")
                                .foregroundStyle(.secondary)
                                .padding()
                        }
                    }
                    .tabItem {
                        Label("Raw Response", systemImage: "doc.text")
                    }
                    .tag(DetailTab.raw)
                }
            }
            .frame(minWidth: 500)
        }
        .frame(minWidth: 900, minHeight: 600)
        .onAppear {
            print("🔴 onAppear triggered")
            loadImage()
        }
        .task {
            print("🟣 Main view .task triggered")
            // Backup loading mechanism in case onAppear doesn't trigger
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            print("🟣 After 0.1s delay - displayedImage: \(displayedImage != nil), hasLoadedImage: \(hasLoadedImage)")
            if displayedImage == nil && !hasLoadedImage {
                print("🟣 Calling loadImage from backup task")
                loadImage()
            }
        }
    }

    // MARK: - Helper Methods

    private func loadImage() {
        print("⚪ loadImage() called, hasLoadedImage: \(hasLoadedImage)")
        guard !hasLoadedImage else {
            print("⚪ Already loaded, returning")
            return
        }
        hasLoadedImage = true
        print("⚪ Starting image load process...")

        // Try to load processed image first
        if let processedPath = evaluation.processedFilePath {
            print("⚪ Trying processed path: \(processedPath)")
            displayedImage = NSImage(contentsOfFile: processedPath)
            print("⚪ Loaded from processed path: \(displayedImage != nil)")
        }

        // Fallback to loading from bookmark
        if displayedImage == nil,
           let bookmarkString = evaluation.originalFilePath,
           let bookmarkData = Data(base64Encoded: bookmarkString) {
            print("⚪ Trying bookmark...")
            do {
                var isStale = false
                let url = try URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &isStale)
                print("⚪ Bookmark resolved to: \(url.path)")

                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                    displayedImage = NSImage(contentsOf: url)
                    print("⚪ Loaded from bookmark: \(displayedImage != nil)")
                }
            } catch {
                print("⚪ Error resolving bookmark: \(error)")
            }
        }

        // Final fallback to thumbnail
        if displayedImage == nil,
           let thumbnailData = evaluation.thumbnailData {
            print("⚪ Trying thumbnail...")
            displayedImage = NSImage(data: thumbnailData)
            print("⚪ Loaded from thumbnail: \(displayedImage != nil)")
        }

        print("⚪ loadImage() completed, displayedImage: \(displayedImage != nil)")
    }

    private func getImageName() -> String {
        if let bookmarkString = evaluation.originalFilePath,
           let bookmarkData = Data(base64Encoded: bookmarkString) {
            do {
                var isStale = false
                let url = try URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &isStale)
                return url.lastPathComponent
            } catch {
                return "Unknown Image"
            }
        }
        return "Unknown Image"
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 8...: return .green
        case 6..<8: return .blue
        case 4..<6: return .orange
        default: return .red
        }
    }
}

// MARK: - Supporting Views

struct ScoreItem: View {
    let label: String
    let score: Double
    let weight: Int

    var body: some View {
        VStack(spacing: 4) {
            CircularProgressView(value: score / 10) {
                Text(String(format: "%.1f", score))
                    .font(.system(size: 20, weight: .semibold))
            }
            .frame(width: 60, height: 60)

            Text(label)
                .font(.caption)

            Text("\(weight)%")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }
}

struct CircularProgressView<Content: View>: View {
    let value: Double
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 4)
                .opacity(0.2)
                .foregroundStyle(Color.secondary)

            Circle()
                .trim(from: 0.0, to: min(value, 1.0))
                .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                .foregroundStyle(progressColor)
                .rotationEffect(Angle(degrees: 270))
                .animation(.easeInOut, value: value)

            content()
        }
    }

    private var progressColor: Color {
        switch value {
        case 0.8...: return .green
        case 0.6..<0.8: return .blue
        case 0.4..<0.6: return .orange
        default: return .red
        }
    }
}

struct DetailSection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                content()
            }
            .padding(.leading, 24)
        }
    }
}

struct PlacementBadge: View {
    let placement: String

    var body: some View {
        Text(placement)
            .font(.caption.bold())
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(badgeColor.gradient)
            .foregroundStyle(.white)
            .cornerRadius(12)
    }

    private var badgeColor: Color {
        switch placement {
        case "PORTFOLIO": return .purple
        case "STORE": return .green
        case "BOTH": return .blue
        default: return .gray
        }
    }
}

struct PriceTierIndicator: View {
    let tier: String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(index < tierLevel ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 30, height: 8)
            }

            Text(tierDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 8)
        }
    }

    private var tierLevel: Int {
        switch tier {
        case "HIGH": return 3
        case "MID": return 2
        case "LOW": return 1
        default: return 0
        }
    }

    private var tierDescription: String {
        switch tier {
        case "HIGH": return "$500+"
        case "MID": return "$150-500"
        case "LOW": return "$50-150"
        default: return "Not specified"
        }
    }
}

#Preview {
    ImageDetailView(evaluation: ImageEvaluation())
        .frame(width: 1000, height: 700)
}