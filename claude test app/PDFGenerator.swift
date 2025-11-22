//
//  PDFGenerator.swift
//  claude test app
//
//  PDF-Generator für Screenshot-Export
//

import Foundation
import AppKit
import PDFKit

class PDFGenerator {

    /// Erstellt ein PDF aus einem Bild mit Überschrift
    /// - Parameters:
    ///   - image: Das Screenshot-Bild
    ///   - title: Die Überschrift für das Bild
    /// - Returns: PDF-Daten oder nil bei Fehler
    static func createPDF(from image: NSImage, title: String) -> Data? {
        // PDF-Seitengröße (A4)
        let pageWidth: CGFloat = 595.0
        let pageHeight: CGFloat = 842.0
        let margin: CGFloat = 40.0
        let titleHeight: CGFloat = 60.0

        // Berechne verfügbaren Platz für das Bild
        let availableWidth = pageWidth - (2 * margin)
        let availableHeight = pageHeight - (2 * margin) - titleHeight - 20 // 20 für Abstand

        // Skaliere das Bild proportional
        let imageSize = image.size
        let widthRatio = availableWidth / imageSize.width
        let heightRatio = availableHeight / imageSize.height
        let scale = min(widthRatio, heightRatio, 1.0) // Nicht größer als Original

        let scaledWidth = imageSize.width * scale
        let scaledHeight = imageSize.height * scale

        // Erstelle PDF-Kontext
        let pdfData = NSMutableData()

        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)

        guard let context = CGContext(consumer: CGDataConsumer(data: pdfData as CFMutableData)!,
                                       mediaBox: &mediaBox,
                                       nil) else {
            return nil
        }

        // Starte PDF-Seite
        context.beginPDFPage(nil)

        // Weißer Hintergrund
        context.setFillColor(CGColor.white)
        context.fill(mediaBox)

        // Zeichne Überschrift
        let titleFont = NSFont.boldSystemFont(ofSize: 24)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: NSColor.black
        ]

        let titleString = NSAttributedString(string: title, attributes: titleAttributes)
        let titleLine = CTLineCreateWithAttributedString(titleString)

        // Zentriere die Überschrift
        let titleBounds = CTLineGetBoundsWithOptions(titleLine, .useOpticalBounds)
        let titleX = (pageWidth - titleBounds.width) / 2
        let titleY = pageHeight - margin - 30

        context.textPosition = CGPoint(x: titleX, y: titleY)
        CTLineDraw(titleLine, context)

        // Zeichne horizontale Linie unter der Überschrift
        context.setStrokeColor(NSColor.gray.cgColor)
        context.setLineWidth(1.0)
        context.move(to: CGPoint(x: margin, y: pageHeight - margin - titleHeight))
        context.addLine(to: CGPoint(x: pageWidth - margin, y: pageHeight - margin - titleHeight))
        context.strokePath()

        // Zeichne das Bild (zentriert)
        let imageX = (pageWidth - scaledWidth) / 2
        let imageY = margin + (availableHeight - scaledHeight) / 2
        let imageRect = CGRect(x: imageX, y: imageY, width: scaledWidth, height: scaledHeight)

        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            context.draw(cgImage, in: imageRect)
        }

        // Zeichne Rahmen um das Bild
        context.setStrokeColor(NSColor.lightGray.cgColor)
        context.setLineWidth(0.5)
        context.stroke(imageRect.insetBy(dx: -2, dy: -2))

        // Datum und Zeit am unteren Rand
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM.yyyy HH:mm:ss"
        let dateString = "Erstellt am: \(dateFormatter.string(from: Date()))"

        let dateFont = NSFont.systemFont(ofSize: 10)
        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: dateFont,
            .foregroundColor: NSColor.gray
        ]

        let dateAttrString = NSAttributedString(string: dateString, attributes: dateAttributes)
        let dateLine = CTLineCreateWithAttributedString(dateAttrString)

        context.textPosition = CGPoint(x: margin, y: 20)
        CTLineDraw(dateLine, context)

        // Beende PDF-Seite und Dokument
        context.endPDFPage()
        context.closePDF()

        return pdfData as Data
    }

    /// Speichert PDF mit Dateiauswahl-Dialog
    /// - Parameters:
    ///   - image: Das Screenshot-Bild
    ///   - title: Die Überschrift
    ///   - completion: Callback mit Erfolg/Fehler
    static func savePDFWithDialog(image: NSImage, title: String, completion: @escaping (Result<URL, Error>) -> Void) {
        guard let pdfData = createPDF(from: image, title: title) else {
            completion(.failure(PDFError.creationFailed))
            return
        }

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.nameFieldStringValue = sanitizeFilename(title) + ".pdf"
        savePanel.title = "PDF speichern"
        savePanel.prompt = "Speichern"
        savePanel.message = "Wählen Sie einen Speicherort für das PDF"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                do {
                    try pdfData.write(to: url)
                    completion(.success(url))
                } catch {
                    completion(.failure(error))
                }
            } else {
                completion(.failure(PDFError.cancelled))
            }
        }
    }

    /// Bereinigt einen Dateinamen
    private static func sanitizeFilename(_ name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        var sanitized = name.components(separatedBy: invalidCharacters).joined(separator: "_")
        sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)

        if sanitized.isEmpty {
            sanitized = "Screenshot"
        }

        return sanitized
    }

    enum PDFError: LocalizedError {
        case creationFailed
        case cancelled

        var errorDescription: String? {
            switch self {
            case .creationFailed:
                return "PDF konnte nicht erstellt werden"
            case .cancelled:
                return "Speichern abgebrochen"
            }
        }
    }
}
