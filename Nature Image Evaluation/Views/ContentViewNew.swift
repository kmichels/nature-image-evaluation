//
//  ContentViewNew.swift
//  Nature Image Evaluation
//
//  Simplified main UI using the new browser
//

import SwiftUI
import CoreData

struct ContentViewNew: View {
    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        // Main browser is now the entire UI
        ImageBrowserView2()
            .environment(\.managedObjectContext, viewContext)
    }
}

#Preview {
    ContentViewNew()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .frame(width: 1200, height: 800)
}