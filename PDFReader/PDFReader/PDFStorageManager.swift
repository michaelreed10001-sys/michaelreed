import Foundation
import UIKit
import PDFKit
import CoreData

class PDFStorageManager {
    static let shared = PDFStorageManager()
    private let fileManager = FileManager.default
    private let documentsDirectory: URL

    private init() {
        documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }

    // MARK: - File Operations
    func savePDF(data: Data, fileName: String) -> URL? {
        let fileURL = documentsDirectory.appendingPathComponent("\(fileName)_\(UUID().uuidString).pdf")
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
//            print("Failed to save PDF: \(error)")
            return nil
        }
    }

    func deletePDF(at url: URL) {
        try? fileManager.removeItem(at: url)
    }

    func generateThumbnail(for url: URL, page: Int = 0) -> UIImage? {
        guard let document = PDFKit.PDFDocument(url: url),
              let page = document.page(at: page) else { return nil }
        let pageRect = page.bounds(for: .mediaBox)
        let thumbnailSize = CGSize(width: 200, height: 200 * pageRect.height / pageRect.width)
        let thumbnail = page.thumbnail(of: thumbnailSize, for: .mediaBox)
        return thumbnail
    }

    // MARK: - Core Data
    func saveMetadata(fileName: String, fileURL: URL, pageCount: Int, fileSize: Double, thumbnail: UIImage? = nil) {
        let context = PersistenceController.shared.container.viewContext
        let pdfDoc = StoredPDF(context: context) // changed
        pdfDoc.id = UUID()
        pdfDoc.fileName = fileName
        pdfDoc.fileURL = fileURL.path
        pdfDoc.pageCount = Int16(pageCount) // note: pageCount is Integer 16 in entity
        pdfDoc.fileSize = fileSize
        pdfDoc.createdAt = Date()
        pdfDoc.thumbnailData = thumbnail?.jpegData(compressionQuality: 0.7)
        try? context.save()
    }

    func fetchAllPDFs() -> [StoredPDF] { // changed
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<StoredPDF> = StoredPDF.fetchRequest() // changed
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        return (try? context.fetch(request)) ?? []
    }

    func deleteFromCoreData(_ document: StoredPDF) { // changed
        let context = PersistenceController.shared.container.viewContext
        if let urlString = document.fileURL {
            let url = URL(fileURLWithPath: urlString)
            deletePDF(at: url)
        }
        context.delete(document)
        try? context.save()
    }
}
