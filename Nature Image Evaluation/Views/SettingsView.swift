//
//  SettingsView.swift
//  Nature Image Evaluation
//
//  Created by Claude Code on 10/27/25.
//

import SwiftUI
import CoreData

struct SettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var selectedProvider: Constants.APIProvider = .anthropic
    @State private var anthropicAPIKey: String = ""
    @State private var openAIAPIKey: String = ""
    @State private var selectedAnthropicModel: String = Constants.anthropicDefaultModel
    @State private var requestDelay: Double = Constants.defaultRequestDelay
    @State private var maxBatchSize: Double = Double(Constants.maxBatchSize)
    @State private var imageResolution: Int = Constants.maxImageDimension

    @State private var isTestingConnection = false
    @State private var testResult: TestResult?
    @State private var showingTestAlert = false
    @State private var anthropicKeySaved = false
    @State private var openAIKeySaved = false

    // API Usage Stats
    @State private var apiStats: APIUsageStats?

    // Services
    private let keychainManager = KeychainManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "gear")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)

                    Text("Settings")
                        .font(.largeTitle.bold())

                    Text("Configure API access and evaluation parameters")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom)

                // API Configuration Section
                GroupBox {
                    VStack(alignment: .leading, spacing: 20) {
                        Label("API Configuration", systemImage: "key.fill")
                            .font(.headline)

                        Divider()

                        // Provider Selection
                        Picker("API Provider", selection: $selectedProvider) {
                            ForEach(Constants.APIProvider.allCases, id: \.self) { provider in
                                Text(provider.displayName)
                                    .tag(provider)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: selectedProvider) { _, _ in
                            testResult = nil
                        }

                        // API Key Entry
                        VStack(alignment: .leading, spacing: 8) {
                            Label(apiKeyLabel, systemImage: "lock.fill")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            HStack {
                                SecureField(apiKeyPlaceholder, text: apiKeyBinding)
                                    .textFieldStyle(.roundedBorder)
                                    .disabled(isTestingConnection)
                                    .onChange(of: currentAPIKey) { oldValue, newValue in
                                        // If key changes, mark as not saved
                                        if oldValue != newValue && !oldValue.isEmpty {
                                            switch selectedProvider {
                                            case .anthropic:
                                                anthropicKeySaved = false
                                            case .openai:
                                                openAIKeySaved = false
                                            }
                                            testResult = nil
                                        }
                                    }
                                    .onSubmit {
                                        if !currentAPIKey.isEmpty {
                                            testConnection()
                                        }
                                    }

                                if isKeySavedInKeychain() {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .help("API Key is saved in Keychain")
                                } else if !currentAPIKey.isEmpty {
                                    Button(action: saveAPIKey) {
                                        Image(systemName: "arrow.down.circle")
                                            .foregroundStyle(.blue)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Save API Key to Keychain")
                                }
                            }

                            if isKeySavedInKeychain() {
                                Text("API key is saved securely in Keychain")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            } else if !currentAPIKey.isEmpty {
                                Text("Test connection to save API key")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Test Connection Button
                        HStack {
                            Button(action: testConnection) {
                                HStack {
                                    if isTestingConnection {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                    } else {
                                        Image(systemName: "network")
                                    }
                                    Text("Test Connection")
                                }
                                .frame(width: 150)
                            }
                            .disabled(currentAPIKey.isEmpty || isTestingConnection)

                            Spacer()

                            // Test Result
                            if let result = testResult {
                                HStack(spacing: 6) {
                                    Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(result.success ? .green : .red)

                                    Text(result.message)
                                        .font(.caption)
                                        .foregroundStyle(result.success ? Color.primary : Color.red)
                                }
                            }
                        }
                    }
                    .padding()
                }

                // Model Selection (for Anthropic)
                if selectedProvider == .anthropic {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 20) {
                            Label("Model Selection", systemImage: "cpu")
                                .font(.headline)

                            Divider()

                            VStack(alignment: .leading, spacing: 12) {
                                Text("Select Claude Model")
                                    .font(.subheadline)

                                ForEach(Constants.anthropicModels, id: \.id) { model in
                                    HStack {
                                        RadioButton(
                                            isSelected: selectedAnthropicModel == model.id,
                                            action: {
                                                selectedAnthropicModel = model.id
                                                UserDefaults.standard.set(model.id, forKey: "selectedAnthropicModel")
                                            }
                                        )

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(model.name)
                                                .font(.body)
                                            Text(model.description)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Text(model.costDisplay)
                                                .font(.caption)
                                                .foregroundStyle(.tertiary)
                                        }

                                        Spacer()
                                    }
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedAnthropicModel = model.id
                                        UserDefaults.standard.set(model.id, forKey: "selectedAnthropicModel")
                                    }
                                }

                                Divider()

                                // Show current selection
                                if let currentModel = Constants.anthropicModels.first(where: { $0.id == selectedAnthropicModel }) {
                                    HStack {
                                        Image(systemName: "info.circle")
                                            .foregroundStyle(.blue)
                                        Text("Using: \(currentModel.name)")
                                            .font(.caption)
                                            .foregroundStyle(.blue)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }

                // Rate Limiting Configuration
                GroupBox {
                    VStack(alignment: .leading, spacing: 20) {
                        Label("Rate Limiting", systemImage: "timer")
                            .font(.headline)

                        Divider()

                        // Request Delay
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Delay between requests")
                                Spacer()
                                Text("\(requestDelay, specifier: "%.1f") seconds")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.subheadline)

                            Slider(value: $requestDelay,
                                   in: Constants.minimumRequestDelay...Constants.maximumRequestDelay,
                                   step: 0.5)
                                .onChange(of: requestDelay) { _, newValue in
                                    UserDefaults.standard.set(newValue, forKey: "requestDelay")
                                }

                            Text("Longer delays reduce rate limit errors but increase processing time")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        // Batch Size
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Images per batch")
                                Spacer()
                                Text("\(Int(maxBatchSize)) images")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.subheadline)

                            Slider(value: $maxBatchSize,
                                   in: Double(Constants.minBatchSize)...Double(Constants.maximumBatchSize),
                                   step: 5)
                                .onChange(of: maxBatchSize) { _, newValue in
                                    UserDefaults.standard.set(Int(newValue), forKey: "maxBatchSize")
                                }

                            Text("Process images in batches with breaks between")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Divider()

                        // Image Resolution
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Image Resolution")
                                Spacer()
                                Text("\(imageResolution)px")
                                    .foregroundStyle(.secondary)
                            }
                            .font(.subheadline)

                            Picker("", selection: $imageResolution) {
                                Text("1568px - Lower cost").tag(1568)
                                Text("2048px - Balanced").tag(2048)
                                Text("2400px - High detail").tag(2400)
                                Text("3000px - Maximum").tag(3000)
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: imageResolution) { _, newValue in
                                UserDefaults.standard.set(newValue, forKey: "imageResolution")
                            }

                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundStyle(.blue)
                                    .imageScale(.small)
                                Text("Higher resolution improves detail detection but increases API costs (~1.7x per step up)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                }

                // API Usage Statistics
                GroupBox {
                    VStack(alignment: .leading, spacing: 20) {
                        Label("API Usage Statistics", systemImage: "chart.bar.fill")
                            .font(.headline)

                        Divider()

                        if let stats = apiStats {
                            HStack {
                                StatView(label: "Images Evaluated",
                                        value: "\(stats.totalImagesEvaluated)",
                                        icon: "photo.stack")

                                Spacer()

                                StatView(label: "Tokens Used",
                                        value: formatNumber(stats.totalTokensUsed),
                                        icon: "text.word.spacing")

                                Spacer()

                                StatView(label: "Total Cost",
                                        value: String(format: "$%.2f", stats.totalCost),
                                        icon: "dollarsign.circle")
                            }

                            Divider()

                            HStack {
                                Text("Stats since: \(stats.lastResetDate ?? Date(), formatter: dateFormatter)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Spacer()

                                Button("Reset Stats") {
                                    resetStats()
                                }
                                .buttonStyle(.link)
                                .font(.caption)
                            }
                        } else {
                            Text("No usage data available")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                }

                // Footer
                HStack {
                    Text("All API keys are stored securely in macOS Keychain")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("Done") {
                        saveSettings()
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .padding(.top)
            }
            .padding(30)
        }
        .frame(minWidth: 600, idealWidth: 700, minHeight: 600)
        .onAppear {
            loadSettings()
            loadAPIStats()

            // Load saved preferences
            let savedResolution = UserDefaults.standard.integer(forKey: "imageResolution")
            if savedResolution > 0 {
                imageResolution = savedResolution
            }

            let savedDelay = UserDefaults.standard.double(forKey: "requestDelay")
            if savedDelay > 0 {
                requestDelay = savedDelay
            }

            let savedBatchSize = UserDefaults.standard.integer(forKey: "maxBatchSize")
            if savedBatchSize > 0 {
                maxBatchSize = Double(savedBatchSize)
            }
        }
        .alert("Connection Test", isPresented: $showingTestAlert) {
            Button("OK") { }
        } message: {
            Text(testResult?.details ?? "Test completed")
        }
    }

    // MARK: - Computed Properties

    private var apiKeyLabel: String {
        switch selectedProvider {
        case .anthropic:
            return "Anthropic API Key"
        case .openai:
            return "OpenAI API Key"
        }
    }

    private var apiKeyPlaceholder: String {
        switch selectedProvider {
        case .anthropic:
            return "sk-ant-..."
        case .openai:
            return "sk-..."
        }
    }

    private var apiKeyBinding: Binding<String> {
        switch selectedProvider {
        case .anthropic:
            return $anthropicAPIKey
        case .openai:
            return $openAIAPIKey
        }
    }

    private var currentAPIKey: String {
        switch selectedProvider {
        case .anthropic:
            return anthropicAPIKey
        case .openai:
            return openAIAPIKey
        }
    }

    private func isKeySavedInKeychain() -> Bool {
        switch selectedProvider {
        case .anthropic:
            return anthropicKeySaved && !anthropicAPIKey.isEmpty
        case .openai:
            return openAIKeySaved && !openAIAPIKey.isEmpty
        }
    }

    // MARK: - Methods

    private func loadSettings() {
        // Load API keys from Keychain
        if let key = try? keychainManager.getAPIKey(for: .anthropic) {
            anthropicAPIKey = key
            anthropicKeySaved = true
        }
        if let key = try? keychainManager.getAPIKey(for: .openai) {
            openAIAPIKey = key
            openAIKeySaved = true
        }

        // Load other settings from UserDefaults
        let defaults = UserDefaults.standard
        requestDelay = defaults.double(forKey: "requestDelay")
        if requestDelay == 0 { requestDelay = Constants.defaultRequestDelay }

        maxBatchSize = defaults.double(forKey: "maxBatchSize")
        if maxBatchSize == 0 { maxBatchSize = Double(Constants.maxBatchSize) }

        // Load selected model
        if let savedModel = defaults.string(forKey: "selectedAnthropicModel") {
            selectedAnthropicModel = savedModel
        }
    }

    private func saveSettings() {
        // Save to UserDefaults
        let defaults = UserDefaults.standard
        defaults.set(requestDelay, forKey: "requestDelay")
        defaults.set(maxBatchSize, forKey: "maxBatchSize")
    }

    private func saveAPIKey() {
        do {
            try keychainManager.saveAPIKey(currentAPIKey, for: selectedProvider)

            // Update saved state
            switch selectedProvider {
            case .anthropic:
                anthropicKeySaved = true
            case .openai:
                openAIKeySaved = true
            }

            testResult = TestResult(
                success: true,
                message: "API key saved",
                details: "API key has been securely stored in Keychain"
            )
        } catch {
            testResult = TestResult(
                success: false,
                message: "Failed to save",
                details: error.localizedDescription
            )
        }
    }

    private func testConnection() {
        guard !currentAPIKey.isEmpty else { return }

        isTestingConnection = true
        testResult = nil

        Task {
            await performConnectionTest()
        }
    }

    @MainActor
    private func performConnectionTest() async {
        do {
            // Create appropriate API service
            switch selectedProvider {
            case .anthropic:
                // Test the Anthropic connection directly
                let testResult = await testAnthropicConnection(apiKey: currentAPIKey)

                await MainActor.run {
                    if testResult.success {
                        // Auto-save the key on successful connection
                        do {
                            try keychainManager.saveAPIKey(currentAPIKey, for: selectedProvider)
                            anthropicKeySaved = true

                            self.testResult = TestResult(
                                success: true,
                                message: "Connected & Saved!",
                                details: "Successfully connected to \(selectedProvider.displayName) and API key has been saved to Keychain."
                            )
                        } catch {
                            self.testResult = TestResult(
                                success: true,
                                message: "Connected!",
                                details: "Connection successful but failed to save key: \(error.localizedDescription)"
                            )
                        }
                    } else {
                        self.testResult = testResult
                    }
                    isTestingConnection = false
                    showingTestAlert = true
                }

            case .openai:
                throw APIError.providerSpecificError("OpenAI provider not yet implemented")
            }

        } catch let error as APIError {
            await MainActor.run {
                let details: String
                switch error {
                case .authenticationFailed:
                    details = "Invalid API key. Please check your key and try again."
                case .rateLimitExceeded:
                    details = "Rate limit exceeded. Your API key is valid but you've hit the rate limit."
                case .networkError(let err):
                    details = "Network error: \(err.localizedDescription)"
                default:
                    details = error.localizedDescription
                }

                testResult = TestResult(
                    success: false,
                    message: "Connection failed",
                    details: details
                )
                isTestingConnection = false
                showingTestAlert = true
            }
        } catch {
            await MainActor.run {
                testResult = TestResult(
                    success: false,
                    message: "Connection failed",
                    details: error.localizedDescription
                )
                isTestingConnection = false
                showingTestAlert = true
            }
        }
    }

    private func loadAPIStats() {
        let request: NSFetchRequest<APIUsageStats> = APIUsageStats.fetchRequest()
        request.fetchLimit = 1

        do {
            apiStats = try viewContext.fetch(request).first
        } catch {
            print("Error loading API stats: \(error)")
        }
    }

    private func resetStats() {
        if let stats = apiStats {
            stats.totalTokensUsed = 0
            stats.totalCost = 0
            stats.totalImagesEvaluated = 0
            stats.lastResetDate = Date()

            try? viewContext.save()
            loadAPIStats()
        }
    }

    private func formatNumber(_ number: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }

    private func testAnthropicConnection(apiKey: String) async -> TestResult {
        do {
            guard let url = URL(string: Constants.anthropicAPIURL) else {
                return TestResult(
                    success: false,
                    message: "Invalid URL",
                    details: "Could not create URL for API endpoint"
                )
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

            // Simple test request
            let requestBody = [
                "model": selectedAnthropicModel,
                "max_tokens": 10,
                "messages": [[
                    "role": "user",
                    "content": "Reply with 'OK'"
                ]]
            ] as [String : Any]

            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 30
            let session = URLSession(configuration: configuration)

            let (_, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                return TestResult(
                    success: false,
                    message: "Connection failed",
                    details: "Invalid response from server"
                )
            }

            switch httpResponse.statusCode {
            case 200:
                return TestResult(
                    success: true,
                    message: "Connected!",
                    details: "Successfully connected to Anthropic Claude. Your API key is valid and working."
                )
            case 401:
                return TestResult(
                    success: false,
                    message: "Authentication failed",
                    details: "Invalid API key. Please check your key and try again."
                )
            case 429:
                return TestResult(
                    success: false,
                    message: "Rate limit",
                    details: "Rate limit exceeded. Your API key is valid but you've hit the rate limit."
                )
            default:
                return TestResult(
                    success: false,
                    message: "Connection failed",
                    details: "Server returned status code: \(httpResponse.statusCode)"
                )
            }
        } catch {
            return TestResult(
                success: false,
                message: "Network error",
                details: error.localizedDescription
            )
        }
    }
}

// MARK: - Supporting Views

struct StatView: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title3.bold())

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - RadioButton Component

struct RadioButton: View {
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .stroke(isSelected ? Color.accentColor : Color.secondary, lineWidth: 2)
                    .frame(width: 16, height: 16)

                if isSelected {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 8, height: 8)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Test Result Model

struct TestResult {
    let success: Bool
    let message: String
    let details: String
}

#Preview {
    SettingsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .frame(width: 700, height: 700)
}