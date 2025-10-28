//
//  ContentView.swift
//  Nature Image Evaluation
//
//  Created by Konrad Michels on 10/27/25.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ImageEvaluation.dateAdded, ascending: false)],
        animation: .default)
    private var imageEvaluations: FetchedResults<ImageEvaluation>

    @State private var showingSettings = false
    @State private var selectedSidebarItem: SidebarItem? = .gallery

    enum SidebarItem: Hashable {
        case gallery
        case settings
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSidebarItem) {
                NavigationLink(value: SidebarItem.gallery) {
                    Label("Gallery", systemImage: "photo.on.rectangle")
                }

                NavigationLink(value: SidebarItem.settings) {
                    Label("Settings", systemImage: "gear")
                }
            }
            .navigationTitle("Nature Image Evaluation")
        } detail: {
            Group {
                switch selectedSidebarItem {
                case .gallery, nil:
                    GalleryView()
                        .environment(\.managedObjectContext, viewContext)

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
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
