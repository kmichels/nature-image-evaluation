//
//  ImageDetailView.swift
//  Nature Image Evaluation
//
//  Created by Claude Code on 10/28/25.
//

import AppKit
import CoreData
import SwiftUI

struct ImageDetailView: View {
    let evaluation: ImageEvaluation
    @Environment(\.dismiss) private var dismiss
    @State private var displayedImage: NSImage?
    @State private var selectedTab: DetailTab = .evaluation
    @State private var hasLoadedImage = false
    @State private var showSaliency = false
    @State private var saliencyType: SaliencyType = .attention
    @State private var saliencyOverlay: NSImage?
    @State private var attentionMap: NSImage?
    @State private var objectnessMap: NSImage?
    @State private var combinedMap: NSImage?
    @State private var isGeneratingSaliency = false

    // MARK: - Cached Formatters

    private static let byteCountFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    enum SaliencyType: String, CaseIterable {
        case attention = "Attention"
        case objectness = "Objects"
        case combined = "Combined"
    }

    enum DetailTab: String, CaseIterable {
        case evaluation = "Evaluation"
        case technical = "Technical"
        case commercial = "Commercial"
        case metadata = "SEO Metadata"
    }

    private var currentSaliencyOverlay: NSImage? {
        switch saliencyType {
        case .attention:
            return attentionMap
        case .objectness:
            return objectnessMap
        case .combined:
            return combinedMap
        }
    }

    var body: some View {
        HSplitView {
            // Left side - Image
            VStack {
                // Image display with optional saliency overlay
                ZStack {
                    if let image = displayedImage {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        // Saliency overlay
                        if showSaliency, let overlay = currentSaliencyOverlay {
                            Image(nsImage: overlay)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .blendMode(.normal)
                        }
                    } else {
                        ProgressView("Loading image...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .task {
                                if !hasLoadedImage {
                                    loadImage()
                                }
                            }
                    }
                }

                // Saliency controls
                HStack(spacing: 12) {
                    Toggle(isOn: $showSaliency) {
                        Label("Saliency Map", systemImage: "eye.fill")
                    }
                    .toggleStyle(.button)
                    .disabled(displayedImage == nil || isGeneratingSaliency)

                    if showSaliency {
                        Picker("Type", selection: $saliencyType) {
                            ForEach(SaliencyType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 250)
                        .disabled(isGeneratingSaliency)
                    }

                    if isGeneratingSaliency {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

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
                    evaluationTabContent
                        .tabItem { Label("Evaluation", systemImage: "star.fill") }
                        .tag(DetailTab.evaluation)

                    technicalTabContent
                        .tabItem { Label("Technical", systemImage: "gearshape.2") }
                        .tag(DetailTab.technical)

                    commercialTabContent
                        .tabItem { Label("Commercial", systemImage: "dollarsign.circle") }
                        .tag(DetailTab.commercial)

                    metadataTabContent
                        .tabItem { Label("SEO Metadata", systemImage: "tag.fill") }
                        .tag(DetailTab.metadata)
                }
            }
            .frame(minWidth: 500)
        }
        .frame(minWidth: 900, minHeight: 600)
        .onAppear {
            loadImage()
        }
        .onDisappear {
            // Clean up resources to prevent memory leaks
            displayedImage = nil
            attentionMap = nil
            objectnessMap = nil
            combinedMap = nil
            saliencyOverlay = nil
            hasLoadedImage = false
        }
        .task {
            // Backup loading mechanism in case onAppear doesn't trigger
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            if displayedImage == nil && !hasLoadedImage {
                loadImage()
            }
        }
        .onChange(of: showSaliency) { _, newValue in
            if newValue && attentionMap == nil {
                Task {
                    await generateSaliencyMaps()
                }
            }
        }
        .onChange(of: displayedImage) { _, newImage in
            if newImage != nil && showSaliency && attentionMap == nil {
                Task {
                    await generateSaliencyMaps()
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func loadImage() {
        guard !hasLoadedImage else { return }
        hasLoadedImage = true

        // Try to load processed image first
        if let processedPath = evaluation.processedFilePath {
            displayedImage = NSImage(contentsOfFile: processedPath)
        }

        // Fallback to loading from bookmark
        if displayedImage == nil,
           let bookmarkData = evaluation.originalFilePath
        {
            do {
                var isStale = false
                let url = try URL(resolvingBookmarkData: bookmarkData, bookmarkDataIsStale: &isStale)
                if url.startAccessingSecurityScopedResource() {
                    defer { url.stopAccessingSecurityScopedResource() }
                    displayedImage = NSImage(contentsOf: url)
                }
            } catch {
                // Bookmark resolution failed, try thumbnail fallback
            }
        }

        // Final fallback to thumbnail
        if displayedImage == nil,
           let thumbnailData = evaluation.thumbnailData
        {
            displayedImage = NSImage(data: thumbnailData)
        }
    }

    private func generateSaliencyMaps() async {
        guard let image = displayedImage else { return }

        await MainActor.run {
            isGeneratingSaliency = true
        }

        let analyzer = SaliencyAnalyzer.shared

        // Generate all maps
        let maps = await analyzer.generateDualSaliencyMaps(for: image)

        // Also generate combined map
        let combinedOverlay = await analyzer.generateCombinedSaliencyOverlay(for: image)

        await MainActor.run {
            self.attentionMap = maps.attention
            self.objectnessMap = maps.objectness
            self.combinedMap = combinedOverlay
            self.isGeneratingSaliency = false
        }
    }

    private func getImageName() -> String {
        if let bookmarkData = evaluation.originalFilePath {
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
        Self.byteCountFormatter.string(fromByteCount: bytes)
    }

    private func formatDate(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }

    // Note: Uses global scoreColor() from ImageGridView2.swift

    private func placementIcon(for placement: String) -> String {
        switch placement {
        case "STORE": return "cart.fill"
        case "PORTFOLIO": return "photo.artframe"
        case "BOTH": return "star.fill"
        case "ARCHIVE": return "archivebox.fill"
        default: return "questionmark.circle"
        }
    }

    private func placementColor(for placement: String) -> Color {
        switch placement {
        case "STORE": return .green
        case "PORTFOLIO": return .purple
        case "BOTH": return .blue
        case "ARCHIVE": return .gray
        default: return .secondary
        }
    }

    private func sharpnessColor(_ sharpness: Float) -> Color {
        switch sharpness {
        case 7...: return .green
        case 5 ..< 7: return .blue
        case 3 ..< 5: return .orange
        default: return .red
        }
    }

    private func noiseColor(_ noise: Float) -> Color {
        switch noise {
        case 0 ..< 0.2: return .green
        case 0.2 ..< 0.4: return .blue
        case 0.4 ..< 0.6: return .orange
        default: return .red
        }
    }

    private func noiseDescription(_ noise: Float) -> String {
        switch noise {
        case 0 ..< 0.1: return "Very Low"
        case 0.1 ..< 0.3: return "Low"
        case 0.3 ..< 0.5: return "Moderate"
        case 0.5 ..< 0.7: return "High"
        default: return "Very High"
        }
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    // MARK: - Tab Content Views

    @ViewBuilder
    private var evaluationTabContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let result = evaluation.currentEvaluation {
                    // Strengths
                    if let strengths = result.strengths, !strengths.isEmpty {
                        DetailSection(title: "Strengths", icon: "checkmark.circle.fill", color: .green) {
                            ForEach(strengths, id: \.self) { strength in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "star.fill")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                    Text(strength)
                                }
                            }
                        }
                    }

                    // Improvements
                    if let improvements = result.improvements, !improvements.isEmpty {
                        DetailSection(title: "Areas for Improvement", icon: "arrow.up.circle.fill", color: .orange) {
                            ForEach(improvements, id: \.self) { improvement in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "lightbulb.fill")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                    Text(improvement)
                                }
                            }
                        }
                    }

                    // Market Comparison
                    if let marketComparison = result.marketComparison, !marketComparison.isEmpty {
                        DetailSection(title: "Market Comparison", icon: "chart.bar.fill", color: .blue) {
                            Text(marketComparison)
                                .font(.body)
                        }
                    }

                    // Technical Innovations
                    if let innovations = result.technicalInnovations, !innovations.isEmpty {
                        DetailSection(title: "Technical Innovations", icon: "sparkles", color: .purple) {
                            ForEach(innovations, id: \.self) { innovation in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "star.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.purple)
                                    Text(innovation)
                                }
                            }
                        }
                    }
                } else {
                    noEvaluationView
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private var technicalTabContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let result = evaluation.currentEvaluation {
                    // Sharpness Analysis
                    DetailSection(title: "Sharpness", icon: "scope", color: .blue) {
                        HStack {
                            Text(String(format: "%.1f", result.technicalSharpness))
                                .font(.title2.bold())
                                .foregroundStyle(sharpnessColor(Float(result.technicalSharpness)))
                            Text("/ 10")
                                .foregroundStyle(.secondary)
                            Spacer()
                            if let blurType = result.technicalBlurType {
                                Text(blurType.capitalized)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.secondary.opacity(0.2))
                                    .cornerRadius(4)
                            }
                        }
                    }

                    // Noise Level
                    DetailSection(title: "Noise Level", icon: "waveform", color: .orange) {
                        HStack {
                            Text(noiseDescription(Float(result.technicalNoiseLevel)))
                                .font(.headline)
                                .foregroundStyle(noiseColor(Float(result.technicalNoiseLevel)))
                            Spacer()
                            Text(String(format: "%.2f", result.technicalNoiseLevel))
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Focus & Exposure
                    HStack(spacing: 20) {
                        if let focus = result.technicalFocusDistribution {
                            VStack(alignment: .leading) {
                                Text("Focus")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(focus)
                                    .font(.headline)
                            }
                        }

                        if let exposure = result.technicalExposure {
                            VStack(alignment: .leading) {
                                Text("Exposure")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(exposure.capitalized)
                                    .font(.headline)
                            }
                        }

                        VStack(alignment: .leading) {
                            Text("Contrast")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.1f", result.technicalContrast))
                                .font(.headline)
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)

                    // Artistic Technique
                    if let technique = result.technicalArtisticTechnique, technique != "standard" {
                        DetailSection(title: "Artistic Technique", icon: "paintbrush.fill", color: .purple) {
                            HStack {
                                Text(technique.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(.headline)
                                Spacer()
                                Text("\(Int(result.technicalIntentConfidence * 100))% confidence")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // API Usage
                    DetailSection(title: "API Usage", icon: "cpu", color: .gray) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Input Tokens:")
                                Spacer()
                                Text("\(result.inputTokens)")
                            }
                            HStack {
                                Text("Output Tokens:")
                                Spacer()
                                Text("\(result.outputTokens)")
                            }
                            Divider()
                            HStack {
                                Text("Estimated Cost:")
                                Spacer()
                                Text(String(format: "$%.4f", result.estimatedCost))
                                    .fontWeight(.semibold)
                            }
                        }
                        .font(.callout)
                    }
                } else {
                    noEvaluationView
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private var commercialTabContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let result = evaluation.currentEvaluation {
                    // Print Size Recommendation
                    if let printSize = result.printSizeRecommendation {
                        DetailSection(title: "Print Size", icon: "doc.fill", color: .blue) {
                            Text(printSize)
                                .font(.title3.bold())
                        }
                    }

                    // Price Tier
                    if let priceTier = result.priceTierSuggestion ?? result.suggestedPriceTier {
                        DetailSection(title: "Price Tier", icon: "dollarsign.circle.fill", color: .green) {
                            PriceTierIndicator(tier: priceTier)
                        }
                    }

                    // Best Use Cases
                    if let useCases = result.bestUseCases, !useCases.isEmpty {
                        DetailSection(title: "Best Use Cases", icon: "lightbulb.fill", color: .yellow) {
                            ForEach(useCases, id: \.self) { useCase in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                    Text(useCase)
                                }
                            }
                        }
                    }

                    // Sellability breakdown
                    DetailSection(title: "Commercial Potential", icon: "chart.line.uptrend.xyaxis", color: .teal) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Sellability Score:")
                                Spacer()
                                Text(String(format: "%.1f / 10", result.sellabilityScore))
                                    .fontWeight(.bold)
                                    .foregroundStyle(scoreColor(result.sellabilityScore))
                            }
                            Text("Based on market trends, subject matter appeal, and commercial viability.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    noEvaluationView
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private var metadataTabContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let result = evaluation.currentEvaluation,
                   result.title != nil || result.descriptionText != nil
                {
                    // Show placement recommendation banner
                    if let placement = result.primaryPlacement {
                        HStack {
                            Image(systemName: placementIcon(for: placement))
                                .foregroundStyle(placementColor(for: placement))
                            Text("Recommended for: \(placement)")
                                .font(.headline)
                            Spacer()
                        }
                        .padding()
                        .background(placementColor(for: placement).opacity(0.1))
                        .cornerRadius(8)
                    }

                    // Title & Description
                    if let title = result.title {
                        DetailSection(title: "Title", icon: "text.badge.star", color: .blue) {
                            HStack {
                                Text(title)
                                    .font(.title3.bold())
                                    .textSelection(.enabled)
                                Spacer()
                                copyButton(title)
                            }
                        }
                    }

                    if let description = result.descriptionText {
                        DetailSection(title: "Description", icon: "text.alignleft", color: .green) {
                            HStack(alignment: .top) {
                                Text(description)
                                    .font(.body)
                                    .textSelection(.enabled)
                                Spacer()
                                copyButton(description)
                            }
                        }
                    }

                    // Keywords
                    if let keywords = result.keywords, !keywords.isEmpty {
                        DetailSection(title: "Keywords (\(keywords.count))", icon: "tag.fill", color: .purple) {
                            VStack(alignment: .leading, spacing: 8) {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(keywords, id: \.self) { keyword in
                                            Text(keyword)
                                                .font(.caption)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.purple.opacity(0.1))
                                                .cornerRadius(4)
                                        }
                                    }
                                }

                                HStack(alignment: .top) {
                                    Text(keywords.joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                    Spacer()
                                    copyButton(keywords.joined(separator: ", "))
                                }
                            }
                        }
                    }

                    // Alt Text
                    if let altText = result.altText {
                        DetailSection(title: "Alt Text", icon: "accessibility", color: .orange) {
                            HStack(alignment: .top) {
                                Text(altText)
                                    .font(.body)
                                    .textSelection(.enabled)
                                Spacer()
                                copyButton(altText)
                            }
                        }
                    }

                    // Suggested Categories
                    if let categories = result.suggestedCategories, !categories.isEmpty {
                        DetailSection(title: "Categories", icon: "folder.fill", color: .indigo) {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(categories, id: \.self) { category in
                                    HStack {
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.indigo)
                                        Text(category)
                                            .font(.body)
                                    }
                                }
                            }
                        }
                    }

                    // Best Use Cases
                    if let useCases = result.bestUseCases, !useCases.isEmpty {
                        DetailSection(title: "Best Use Cases", icon: "lightbulb.fill", color: .yellow) {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(useCases, id: \.self) { useCase in
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.caption)
                                            .foregroundStyle(.green)
                                        Text(useCase)
                                            .font(.body)
                                    }
                                }
                            }
                        }
                    }

                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "tag.slash")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No commercial metadata available")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Text("Metadata is generated for images with STORE or BOTH placement")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private var noEvaluationView: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Not Evaluated")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("This image has not been evaluated yet")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    @ViewBuilder
    private func copyButton(_ text: String) -> some View {
        Button(action: {
            copyToClipboard(text)
        }) {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Copy to clipboard")
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
        case 0.6 ..< 0.8: return .blue
        case 0.4 ..< 0.6: return .orange
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
            ForEach(0 ..< 3) { index in
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
