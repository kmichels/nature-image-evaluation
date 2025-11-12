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
    @State private var selectedSidebarItem: SidebarItem? = .quickAnalysis
    @State private var folderManager = FolderManager.shared
    @State private var showingFolderPicker = false

    enum SidebarItem: Hashable {
        case quickAnalysis
        case folder(MonitoredFolder)
        case settings
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
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
