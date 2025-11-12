//
//  ContentView.swift
//  Nature Image Evaluation
//
//  Created by Konrad Michels on 10/27/25.
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ImageEvaluation.dateAdded, ascending: false)],
        animation: .default)
    private var imageEvaluations: FetchedResults<ImageEvaluation>

    @State private var showingSettings = false
    @State private var selectedSidebarItem: SidebarItem?
    @State private var folderManager = FolderManager.shared
    @State private var showingFolderPicker = false

    enum SidebarItem: Hashable {
        case quickAnalysis
        case folder(MonitoredFolder)
        case settings

        // Helper for saving/loading selection
        var storageKey: String {
            switch self {
            case .quickAnalysis:
                return "quickAnalysis"
            case .folder(let folder):
                return "folder:\(folder.id.uuidString)"
            case .settings:
                return "settings"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSidebarItem) {
                // Quick Analysis Section
                Section {
                    NavigationLink(value: SidebarItem.quickAnalysis) {
                        Label("Quick Analysis", systemImage: "sparkles")
                    }
                }

                // Folders Section
                Section("Folders") {
                    ForEach(folderManager.folders) { folder in
                        NavigationLink(value: SidebarItem.folder(folder)) {
                            Label(folder.name, systemImage: "folder")
                        }
                        .contextMenu {
                            Button(role: .destructive) {
                                // If we're removing the currently selected folder, clear selection
                                if case .folder(let selectedFolder) = selectedSidebarItem,
                                   selectedFolder.id == folder.id {
                                    selectedSidebarItem = .quickAnalysis
                                }
                                folderManager.removeFolder(folder)
                            } label: {
                                Label("Remove Folder", systemImage: "trash")
                            }
                        }
                    }

                    Button(action: { showingFolderPicker = true }) {
                        Label("Add Folder...", systemImage: "plus.circle")
                    }
                    .buttonStyle(.plain)
                }

                // Settings Section
                Section {
                    NavigationLink(value: SidebarItem.settings) {
                        Label("Settings", systemImage: "gear")
                    }
                }
            }
            .navigationTitle("Nature Image Evaluation")
            .listStyle(SidebarListStyle())
        } detail: {
            Group {
                switch selectedSidebarItem {
                case .quickAnalysis, nil:
                    GalleryView()
                        .environment(\.managedObjectContext, viewContext)
                        .navigationTitle("Quick Analysis")

                case .folder(let folder):
                    FolderGalleryView(folder: folder)
                        .environment(\.managedObjectContext, viewContext)
                        .navigationTitle(folder.name)

                case .settings:
                    SettingsView()
                        .environment(\.managedObjectContext, viewContext)
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environment(\.managedObjectContext, viewContext)
        }
        .fileImporter(
            isPresented: $showingFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }

                // Start accessing the security-scoped resource
                guard url.startAccessingSecurityScopedResource() else {
                    print("Failed to access folder: \(url)")
                    return
                }

                do {
                    try folderManager.addFolder(at: url)
                } catch {
                    print("Error adding folder: \(error)")
                }

                // Stop accessing the security-scoped resource
                url.stopAccessingSecurityScopedResource()

            case .failure(let error):
                print("Error selecting folder: \(error)")
            }
        }
        .onAppear {
            loadSelectedSidebarItem()
        }
        .onChange(of: selectedSidebarItem) { oldValue, newValue in
            saveSelectedSidebarItem()
        }
    }

    // MARK: - Persistence Methods

    private func saveSelectedSidebarItem() {
        if let item = selectedSidebarItem {
            UserDefaults.standard.set(item.storageKey, forKey: "selectedSidebarItem")
        } else {
            UserDefaults.standard.removeObject(forKey: "selectedSidebarItem")
        }
    }

    private func loadSelectedSidebarItem() {
        guard let savedKey = UserDefaults.standard.string(forKey: "selectedSidebarItem") else {
            // Default to Quick Analysis if nothing saved
            selectedSidebarItem = .quickAnalysis
            return
        }

        // Parse the saved key
        if savedKey == "quickAnalysis" {
            selectedSidebarItem = .quickAnalysis
        } else if savedKey == "settings" {
            selectedSidebarItem = .settings
        } else if savedKey.hasPrefix("folder:") {
            // Extract the folder ID
            let folderIDString = String(savedKey.dropFirst(7))
            if let folderID = UUID(uuidString: folderIDString),
               let folder = folderManager.folders.first(where: { $0.id == folderID }) {
                selectedSidebarItem = .folder(folder)
            } else {
                // Folder no longer exists, default to Quick Analysis
                selectedSidebarItem = .quickAnalysis
            }
        } else {
            // Unknown saved value, default to Quick Analysis
            selectedSidebarItem = .quickAnalysis
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
