//
//  SmartFolderEditorView.swift
//  Nature Image Evaluation
//
//  Created by Claude on 11/14/25.
//

import SwiftUI
import CoreData

struct SmartFolderEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var smartFolderManager = SmartFolderManager.shared

    let existingFolder: Collection?
    @State private var folderName: String = ""
    @State private var folderIcon: String = "sparkle.magnifyingglass"
    @State private var criteria = SmartFolderCriteria()
    @State private var matchAll = true
    @State private var showingTemplates = false
    @State private var showingError = false
    @State private var errorMessage = ""

    init(existingFolder: Collection? = nil) {
        self.existingFolder = existingFolder
        if let folder = existingFolder {
            _folderName = State(initialValue: folder.name ?? "")
            _folderIcon = State(initialValue: folder.icon ?? "sparkle.magnifyingglass")
            if let predicateString = folder.smartPredicate,
               let existingCriteria = SmartFolderCriteria.fromJSONString(predicateString) {
                _criteria = State(initialValue: existingCriteria)
                _matchAll = State(initialValue: existingCriteria.matchAll)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(existingFolder == nil ? "New Smart Folder" : "Edit Smart Folder")
                    .font(.title2.bold())

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Content
            Form {
                // Basic Info Section
                Section("Folder Information") {
                    HStack {
                        Text("Name:")
                            .frame(width: 100, alignment: .trailing)
                        TextField("Smart Folder Name", text: $folderName)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack {
                        Text("Icon:")
                            .frame(width: 100, alignment: .trailing)

                        Picker("Icon", selection: $folderIcon) {
                            Label("Sparkle", systemImage: "sparkle.magnifyingglass").tag("sparkle.magnifyingglass")
                            Label("Star", systemImage: "star.fill").tag("star.fill")
                            Label("Heart", systemImage: "heart.fill").tag("heart.fill")
                            Label("Flag", systemImage: "flag.fill").tag("flag.fill")
                            Label("Tag", systemImage: "tag.fill").tag("tag.fill")
                            Label("Clock", systemImage: "clock.fill").tag("clock.fill")
                            Label("Eye", systemImage: "eye.fill").tag("eye.fill")
                            Label("Dollar", systemImage: "dollarsign.circle.fill").tag("dollarsign.circle.fill")
                            Label("Warning", systemImage: "exclamationmark.triangle.fill").tag("exclamationmark.triangle.fill")
                        }
                        .pickerStyle(.menu)
                        .frame(width: 200)

                        Spacer()

                        Button("Use Template") {
                            showingTemplates = true
                        }
                    }
                }

                Divider()

                // Criteria Section
                Section("Criteria") {
                    // Match type
                    Picker("Match", selection: $matchAll) {
                        Text("All of the following criteria").tag(true)
                        Text("Any of the following criteria").tag(false)
                    }
                    .pickerStyle(.radioGroup)
                    .padding(.bottom)

                    // Rules
                    ForEach(criteria.rules.indices, id: \.self) { index in
                        RuleEditor(rule: $criteria.rules[index]) {
                            criteria.rules.remove(at: index)
                        }
                        .padding(.vertical, 4)
                    }

                    // Add rule button
                    Button(action: addRule) {
                        Label("Add Criteria", systemImage: "plus.circle")
                    }
                    .buttonStyle(.link)
                }
            }
            .formStyle(.grouped)
            .padding()

            Divider()

            // Footer
            HStack {
                Text("\(criteria.rules.count) criteria")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Cancel") {
                    dismiss()
                }

                Button(existingFolder == nil ? "Create" : "Save") {
                    saveSmartFolder()
                }
                .buttonStyle(.borderedProminent)
                .disabled(folderName.isEmpty || criteria.rules.isEmpty)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 700, height: 600)
        .sheet(isPresented: $showingTemplates) {
            TemplatePickerView { template in
                applyTemplate(template)
                showingTemplates = false
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Helper Methods

    private func addRule() {
        let newRule = CriteriaRule(
            criteriaType: .overallScore,
            comparison: .greaterThanOrEqual,
            value: .number(7.0)
        )
        criteria.rules.append(newRule)
    }

    private func saveSmartFolder() {
        // Update criteria with match type
        criteria.matchAll = matchAll

        // Validate criteria
        guard smartFolderManager.validateCriteria(criteria) else {
            errorMessage = "Invalid criteria configuration"
            showingError = true
            return
        }

        do {
            if let existingFolder = existingFolder {
                try smartFolderManager.updateSmartFolder(existingFolder, name: folderName, icon: folderIcon, criteria: criteria)
            } else {
                try smartFolderManager.createSmartFolder(name: folderName, icon: folderIcon, criteria: criteria)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func applyTemplate(_ template: SmartFolderCriteria) {
        criteria = template
        matchAll = template.matchAll
    }
}

// MARK: - Rule Editor Component

struct RuleEditor: View {
    @Binding var rule: CriteriaRule
    let onDelete: () -> Void

    var body: some View {
        HStack {
            // Criteria type picker
            Picker("", selection: $rule.criteriaType) {
                ForEach(CriteriaRule.CriteriaType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .frame(width: 150)

            // Comparison operator picker
            Picker("", selection: $rule.comparison) {
                ForEach(rule.criteriaType.availableComparisons, id: \.self) { comparison in
                    Text(comparison.rawValue).tag(comparison)
                }
            }
            .frame(width: 140)

            // Value input
            ValueEditor(criteriaType: rule.criteriaType, value: $rule.value)
                .frame(width: 150)

            // Delete button
            Button(action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Value Editor Component

struct ValueEditor: View {
    let criteriaType: CriteriaRule.CriteriaType
    @Binding var value: CriteriaValue

    @State private var numberValue: Double = 0.0
    @State private var boolValue: Bool = true
    @State private var placementValue: String = "PORTFOLIO"
    @State private var dateValue: Date = Date()
    @State private var daysValue: Int = 7

    var body: some View {
        Group {
            switch criteriaType.valueType {
            case .number:
                HStack {
                    TextField("Value", value: $numberValue, format: .number.precision(.fractionLength(1)))
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: numberValue) { _, newValue in
                            value = .number(newValue)
                        }
                    Stepper("", value: $numberValue, in: 0...10, step: 0.5)
                }
                .onAppear {
                    if case .number(let v) = value {
                        numberValue = v
                    } else {
                        numberValue = 7.0
                        value = .number(7.0)
                    }
                }

            case .placement:
                Picker("", selection: $placementValue) {
                    Text("PORTFOLIO").tag("PORTFOLIO")
                    Text("STORE").tag("STORE")
                    Text("BOTH").tag("BOTH")
                    Text("ARCHIVE").tag("ARCHIVE")
                    Text("PRACTICE").tag("PRACTICE")
                }
                .onChange(of: placementValue) { _, newValue in
                    value = .placement(newValue)
                }
                .onAppear {
                    if case .placement(let v) = value {
                        placementValue = v
                    } else {
                        value = .placement("PORTFOLIO")
                    }
                }

            case .boolean:
                Toggle("", isOn: $boolValue)
                    .onChange(of: boolValue) { _, newValue in
                        value = .boolean(newValue)
                    }
                    .onAppear {
                        if case .boolean(let v) = value {
                            boolValue = v
                        } else {
                            value = .boolean(true)
                        }
                    }

            case .date:
                if criteriaType == .dateAdded || criteriaType == .dateEvaluated {
                    HStack {
                        TextField("Days", value: $daysValue, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                        Text("days")
                    }
                    .onChange(of: daysValue) { _, newValue in
                        var components = DateComponents()
                        components.day = -newValue
                        value = .dateInterval(components)
                    }
                    .onAppear {
                        if case .dateInterval(let components) = value {
                            daysValue = abs(components.day ?? 7)
                        } else {
                            var components = DateComponents()
                            components.day = -7
                            value = .dateInterval(components)
                        }
                    }
                } else {
                    DatePicker("", selection: $dateValue, displayedComponents: [.date])
                        .onChange(of: dateValue) { _, newValue in
                            value = .date(newValue)
                        }
                        .onAppear {
                            if case .date(let v) = value {
                                dateValue = v
                            } else {
                                value = .date(Date())
                            }
                        }
                }
            }
        }
    }
}

// MARK: - Template Picker View

struct TemplatePickerView: View {
    let onSelect: (SmartFolderCriteria) -> Void
    @Environment(\.dismiss) private var dismiss

    var templates: [(String, String, SmartFolderCriteria)] {
        [
            ("Portfolio Quality", "Images scoring 8+ or marked for portfolio", .portfolioQuality),
            ("Needs Review", "Images that haven't been evaluated yet", .needsReview),
            ("Recently Added", "Images added in the last 7 days", .recentlyAdded),
            ("High Commercial Value", "Images with high sellability score", .highCommercialValue),
            ("Needs Improvement", "Low-scoring images for learning", .needsImprovement),
            ("Favorites", "Images marked as favorites", .favorites)
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Choose a Template")
                    .font(.title2.bold())
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            List(templates, id: \.0) { template in
                Button(action: { onSelect(template.2) }) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(template.0)
                            .font(.headline)
                        Text(template.1)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.inset)
        }
        .frame(width: 400, height: 300)
    }
}

#Preview {
    SmartFolderEditorView()
}