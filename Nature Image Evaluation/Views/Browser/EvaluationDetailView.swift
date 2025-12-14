//
//  EvaluationDetailView.swift
//  Nature Image Evaluation
//
//  Shows detailed evaluation results for an image
//

import SwiftUI

struct EvaluationDetailView: View {
    let url: URL
    let evaluation: ImageEvaluation?
    @Environment(\.dismiss) private var dismiss

    @State private var image: NSImage?

    private var result: EvaluationResult? {
        evaluation?.currentEvaluation
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text(url.lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Button("Open in Preview") {
                    NSWorkspace.shared.open(url)
                }
                .buttonStyle(.link)
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(.regularMaterial)

            Divider()

            // Content
            HStack(spacing: 0) {
                // Left side - Image
                imagePanel
                    .frame(width: 400)

                Divider()

                // Right side - Details
                if let result = result {
                    detailsPanel(result)
                } else {
                    noEvaluationPanel
                }
            }
        }
        .frame(width: 900, height: 650)
        .task {
            await loadImage()
        }
    }

    // MARK: - Image Panel

    @ViewBuilder
    private var imagePanel: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor)

            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(16)
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading image...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - No Evaluation Panel

    @ViewBuilder
    private var noEvaluationPanel: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("Not Evaluated")
                .font(.title2)
            Text("This image has not been evaluated yet.\nSelect it and click 'Evaluate' in the toolbar.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Details Panel

    @ViewBuilder
    private func detailsPanel(_ result: EvaluationResult) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with overall score
                scoreHeader(result)

                Divider()

                // Individual scores
                scoresSection(result)

                Divider()

                // Strengths & Improvements
                feedbackSection(result)

                // Commercial metadata (if available)
                if result.title != nil || result.keywords != nil {
                    Divider()
                    commercialSection(result)
                }

                Divider()

                // Technical details
                technicalSection(result)
            }
            .padding(20)
        }
    }

    // MARK: - Score Header

    @ViewBuilder
    private func scoreHeader(_ result: EvaluationResult) -> some View {
        HStack(spacing: 16) {
            // Large score display
            VStack(spacing: 4) {
                Text(String(format: "%.1f", result.overallWeightedScore))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(scoreColor(result.overallWeightedScore))
                Text("Overall Score")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 100)

            Divider()
                .frame(height: 60)

            // Placement
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: placementIcon(result.primaryPlacement))
                        .font(.title2)
                        .foregroundColor(placementColor(result.primaryPlacement))
                    Text(result.primaryPlacement ?? "Unknown")
                        .font(.title3.weight(.semibold))
                }

                if let priceTier = result.priceTierSuggestion {
                    Text("Price Tier: \(priceTier)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let printSize = result.printSizeRecommendation {
                    Text("Print: \(printSize)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
    }

    // MARK: - Scores Section

    @ViewBuilder
    private func scoresSection(_ result: EvaluationResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scores")
                .font(.headline)

            ScoreBar(label: "Composition", score: result.compositionScore, weight: "30%")
            ScoreBar(label: "Quality", score: result.qualityScore, weight: "25%")
            ScoreBar(label: "Sellability", score: result.sellabilityScore, weight: "25%")
            ScoreBar(label: "Artistic", score: result.artisticScore, weight: "20%")
        }
    }

    // MARK: - Feedback Section

    @ViewBuilder
    private func feedbackSection(_ result: EvaluationResult) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Strengths
            if let strengths = result.strengths, !strengths.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Strengths", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundColor(.green)

                    ForEach(strengths, id: \.self) { strength in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundColor(.green)
                            Text(strength)
                                .font(.callout)
                        }
                    }
                }
            }

            // Improvements
            if let improvements = result.improvements, !improvements.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Areas for Improvement", systemImage: "arrow.up.circle.fill")
                        .font(.headline)
                        .foregroundColor(.orange)

                    ForEach(improvements, id: \.self) { improvement in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundColor(.orange)
                            Text(improvement)
                                .font(.callout)
                        }
                    }
                }
            }

            // Market comparison
            if let marketComparison = result.marketComparison, !marketComparison.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Market Comparison", systemImage: "chart.bar.fill")
                        .font(.headline)
                        .foregroundColor(.blue)

                    Text(marketComparison)
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Commercial Section

    @ViewBuilder
    private func commercialSection(_ result: EvaluationResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Commercial Metadata")
                .font(.headline)

            if let title = result.title, !title.isEmpty {
                LabeledContent("Title", value: title)
            }

            if let description = result.descriptionText, !description.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Description")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(description)
                        .font(.callout)
                }
            }

            if let keywords = result.keywords, !keywords.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Keywords")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    FlowLayout(spacing: 4) {
                        ForEach(keywords, id: \.self) { keyword in
                            Text(keyword)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.accentColor.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }
            }

            if let categories = result.suggestedCategories, !categories.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Categories")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(categories.joined(separator: ", "))
                        .font(.callout)
                }
            }
        }
    }

    // MARK: - Technical Section

    @ViewBuilder
    private func technicalSection(_ result: EvaluationResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Technical Analysis")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                TechnicalMetric(label: "Sharpness", value: String(format: "%.1f", result.technicalSharpness))
                TechnicalMetric(label: "Blur Type", value: result.technicalBlurType ?? "None")
                TechnicalMetric(label: "Focus", value: result.technicalFocusDistribution ?? "N/A")
                TechnicalMetric(label: "Exposure", value: result.technicalExposure ?? "N/A")
                TechnicalMetric(label: "Noise Level", value: String(format: "%.1f", result.technicalNoiseLevel))
                TechnicalMetric(label: "Contrast", value: String(format: "%.1f", result.technicalContrast))
            }

            if let technique = result.technicalArtisticTechnique, technique != "standard" {
                HStack {
                    Text("Artistic Technique:")
                        .foregroundColor(.secondary)
                    Text(technique.replacingOccurrences(of: "_", with: " ").capitalized)
                        .fontWeight(.medium)
                    Text("(\(Int(result.technicalIntentConfidence * 100))% confidence)")
                        .foregroundColor(.secondary)
                }
                .font(.caption)
            }

            // API usage info
            HStack {
                Text("Tokens: \(result.inputTokens + result.outputTokens)")
                Text("•")
                Text("Cost: $\(String(format: "%.4f", result.estimatedCost))")
                Text("•")
                Text(result.evaluationDate ?? Date(), style: .date)
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }

    // MARK: - Helpers

    private func loadImage() async {
        await Task.detached(priority: .userInitiated) {
            let loadedImage = NSImage(contentsOf: url)
            await MainActor.run {
                self.image = loadedImage
            }
        }.value
    }

    private func scoreColor(_ score: Double) -> Color {
        switch score {
        case 8.0...: return .green
        case 6.0..<8.0: return .blue
        case 4.0..<6.0: return .orange
        default: return .red
        }
    }

    private func placementIcon(_ placement: String?) -> String {
        switch placement {
        case "PORTFOLIO": return "star.fill"
        case "STORE": return "cart.fill"
        case "BOTH": return "star.circle.fill"
        case "ARCHIVE": return "archivebox.fill"
        default: return "questionmark.circle"
        }
    }

    private func placementColor(_ placement: String?) -> Color {
        switch placement {
        case "PORTFOLIO": return .yellow
        case "STORE": return .green
        case "BOTH": return .blue
        case "ARCHIVE": return .gray
        default: return .secondary
        }
    }
}

// MARK: - Supporting Views

struct ScoreBar: View {
    let label: String
    let score: Double
    let weight: String

    private var color: Color {
        switch score {
        case 8.0...: return .green
        case 6.0..<8.0: return .blue
        case 4.0..<6.0: return .orange
        default: return .red
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .frame(width: 80, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * (score / 10.0))
                }
            }
            .frame(height: 8)

            Text(String(format: "%.1f", score))
                .font(.system(.body, design: .rounded, weight: .medium))
                .frame(width: 35, alignment: .trailing)

            Text(weight)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 30)
        }
    }
}

struct TechnicalMetric: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(4)
    }
}

// Simple flow layout for keywords
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > width && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing

                self.size.width = max(self.size.width, x)
            }

            self.size.height = y + rowHeight
        }
    }
}
