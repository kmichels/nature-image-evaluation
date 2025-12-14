//
//  Nature_Image_EvaluationApp.swift
//  Nature Image Evaluation
//
//  Created by Konrad Michels on 10/27/25.
//

import SwiftUI
import CoreData

@main
struct Nature_Image_EvaluationApp: App {
    let persistenceController = PersistenceController.shared
    @State private var evaluationManager: EvaluationManager
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // Initialize evaluation manager
        _evaluationManager = State(initialValue: EvaluationManager(persistenceController: PersistenceController.shared))
    }

    var body: some Scene {
        WindowGroup {
            ContentViewNew()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environment(evaluationManager)
                .frame(minWidth: 900, minHeight: 600)
                .onAppear {
                    configureMainWindow()
                }
        }
    }

    private func configureMainWindow() {
        // Configure the main window for transparent titlebar with traffic lights
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first {
                // Make titlebar transparent but keep traffic lights
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden

                // Extend content under titlebar
                window.styleMask.insert(.fullSizeContentView)

                // Optional: make window background match our content
                window.backgroundColor = NSColor.windowBackgroundColor
            }
        }
    }
}

// MARK: - App Delegate for window configuration

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure windows after launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            for window in NSApplication.shared.windows {
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.styleMask.insert(.fullSizeContentView)
            }
        }
    }
}
