//
//  claude_test_appApp.swift
//  claude test app
//
//  Screenshot zu PDF App für macOS
//

import SwiftUI

@main
struct claude_test_appApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.automatic)
        .defaultSize(width: 700, height: 600)
        .commands {
            // Tastenkürzel für Screenshot
            CommandGroup(after: .newItem) {
                Button("Screenshot aufnehmen") {
                    NotificationCenter.default.post(name: .captureScreenshot, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }
        }
    }
}

// Notification für Tastenkürzel
extension Notification.Name {
    static let captureScreenshot = Notification.Name("captureScreenshot")
}
