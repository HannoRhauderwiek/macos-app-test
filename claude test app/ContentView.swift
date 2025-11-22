//
//  ContentView.swift
//  claude test app
//
//  Hauptansicht der Screenshot-App
//

import SwiftUI

struct ContentView: View {
    @State private var screenshotManager = ScreenshotManager()
    @State private var imageTitle = ""
    @State private var showingSaveSuccess = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var savedURL: URL?

    var body: some View {
        VStack(spacing: 20) {
            // Header
            headerView

            Divider()

            // Hauptbereich
            if let image = screenshotManager.capturedImage {
                // Screenshot wurde aufgenommen
                capturedImageView(image: image)
            } else {
                // Platzhalter - noch kein Screenshot
                emptyStateView
            }

            Divider()

            // Steuerungsbereich
            controlsView
        }
        .padding(20)
        .frame(minWidth: 600, minHeight: 500)
        .alert("Erfolgreich gespeichert", isPresented: $showingSaveSuccess) {
            Button("OK") { }
            if let url = savedURL {
                Button("Im Finder anzeigen") {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
            }
        } message: {
            if let url = savedURL {
                Text("PDF wurde gespeichert unter:\n\(url.path)")
            }
        }
        .alert("Fehler", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Header View
    private var headerView: some View {
        HStack {
            Image(systemName: "camera.viewfinder")
                .font(.largeTitle)
                .foregroundColor(.accentColor)

            VStack(alignment: .leading) {
                Text("Screenshot zu PDF")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Bildschirmfoto aufnehmen, beschriften und als PDF speichern")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 80))
                .foregroundColor(.secondary.opacity(0.5))

            Text("Noch kein Screenshot aufgenommen")
                .font(.title2)
                .foregroundColor(.secondary)

            Text("Klicken Sie auf 'Screenshot aufnehmen' um zu beginnen")
                .font(.body)
                .foregroundColor(.secondary.opacity(0.8))

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }

    // MARK: - Captured Image View
    private func capturedImageView(image: NSImage) -> some View {
        VStack(spacing: 16) {
            // Bildvorschau
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 300)
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )

            // Titel-Eingabe
            VStack(alignment: .leading, spacing: 8) {
                Text("Bild-Überschrift:")
                    .font(.headline)

                TextField("Geben Sie eine Überschrift ein...", text: $imageTitle)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }

    // MARK: - Controls View
    private var controlsView: some View {
        HStack(spacing: 16) {
            // Screenshot aufnehmen Button
            Button(action: captureScreenshot) {
                HStack {
                    if screenshotManager.isCapturing {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 16, height: 16)
                    } else {
                        Image(systemName: "camera.fill")
                    }
                    Text(screenshotManager.capturedImage == nil ? "Screenshot aufnehmen" : "Neuer Screenshot")
                }
                .frame(minWidth: 160)
            }
            .buttonStyle(.borderedProminent)
            .disabled(screenshotManager.isCapturing)

            Spacer()

            // Nur anzeigen wenn ein Bild vorhanden ist
            if screenshotManager.capturedImage != nil {
                // Verwerfen Button
                Button(action: discardScreenshot) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Verwerfen")
                    }
                }
                .buttonStyle(.bordered)
                .tint(.red)

                // Als PDF speichern Button
                Button(action: saveAsPDF) {
                    HStack {
                        Image(systemName: "doc.fill")
                        Text("Als PDF speichern")
                    }
                    .frame(minWidth: 140)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(imageTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    // MARK: - Actions

    private func captureScreenshot() {
        // Fenster minimieren vor Screenshot
        if let window = NSApplication.shared.windows.first {
            window.miniaturize(nil)
        }

        // Kurze Verzögerung, damit das Fenster verschwindet
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            Task {
                await screenshotManager.captureScreen()

                // Fenster wieder anzeigen
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    if let window = NSApplication.shared.windows.first {
                        window.deminiaturize(nil)
                        window.makeKeyAndOrderFront(nil)
                        NSApplication.shared.activate(ignoringOtherApps: true)
                    }
                }
            }
        }
    }

    private func discardScreenshot() {
        screenshotManager.clearImage()
        imageTitle = ""
    }

    private func saveAsPDF() {
        guard let image = screenshotManager.capturedImage else { return }

        let title = imageTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }

        PDFGenerator.savePDFWithDialog(image: image, title: title) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let url):
                    savedURL = url
                    showingSaveSuccess = true
                    // Nach erfolgreichem Speichern zurücksetzen
                    screenshotManager.clearImage()
                    imageTitle = ""

                case .failure(let error):
                    if case PDFGenerator.PDFError.cancelled = error {
                        // Abbruch ist kein Fehler
                        return
                    }
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
