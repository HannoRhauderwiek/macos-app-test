//
//  ScreenshotManager.swift
//  claude test app
//
//  Screenshot-Manager für macOS Bildschirmaufnahmen
//

import Foundation
import AppKit
import ScreenCaptureKit

@MainActor
class ScreenshotManager: ObservableObject {
    @Published var capturedImage: NSImage?
    @Published var isCapturing = false
    @Published var errorMessage: String?

    /// Nimmt einen Screenshot des gesamten Bildschirms auf
    func captureScreen() async {
        isCapturing = true
        errorMessage = nil

        do {
            // Hole verfügbare Bildschirme
            let content = try await SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true)

            guard let display = content.displays.first else {
                errorMessage = "Kein Bildschirm gefunden"
                isCapturing = false
                return
            }

            // Konfiguriere die Screenshot-Einstellungen
            let filter = SCContentFilter(display: display, excludingWindows: [])

            let configuration = SCStreamConfiguration()
            configuration.width = Int(display.width) * 2 // Retina-Auflösung
            configuration.height = Int(display.height) * 2
            configuration.pixelFormat = kCVPixelFormatType_32BGRA
            configuration.showsCursor = false

            // Erstelle den Screenshot
            let image = try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )

            // Konvertiere CGImage zu NSImage
            let nsImage = NSImage(cgImage: image, size: NSSize(width: display.width, height: display.height))

            self.capturedImage = nsImage
            isCapturing = false

        } catch {
            errorMessage = "Screenshot fehlgeschlagen: \(error.localizedDescription)"
            isCapturing = false
        }
    }

    /// Alternative Screenshot-Methode mit screencapture Kommandozeilen-Tool
    func captureScreenLegacy() {
        isCapturing = true
        errorMessage = nil

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("screenshot_\(UUID().uuidString).png")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", tempURL.path] // -x = kein Sound

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                if let image = NSImage(contentsOf: tempURL) {
                    self.capturedImage = image
                }
                // Lösche temporäre Datei
                try? FileManager.default.removeItem(at: tempURL)
            } else {
                errorMessage = "Screenshot konnte nicht erstellt werden"
            }
        } catch {
            errorMessage = "Fehler: \(error.localizedDescription)"
        }

        isCapturing = false
    }

    /// Löscht das aktuelle Bild
    func clearImage() {
        capturedImage = nil
        errorMessage = nil
    }
}
