import SwiftUI
import VisionKit
import PDFKit

struct ScanView: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    var onScanCompleted: (URL) -> Void
    
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }
    
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: ScanView
        
        init(_ parent: ScanView) {
            self.parent = parent
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            // Convert scanned pages to PDF
            let pdfDocument = PDFKit.PDFDocument()
            for pageIndex in 0..<scan.pageCount {
                let image = scan.imageOfPage(at: pageIndex)
                if let pdfPage = PDFKit.PDFPage(image: image) {
                    pdfDocument.insert(pdfPage, at: pageIndex)
                }
            }
            
            // Save PDF
            let data = pdfDocument.dataRepresentation()
            if let url = PDFStorageManager.shared.savePDF(data: data!, fileName: "Scanned_\(Date().timeIntervalSince1970)") {
                // Generate thumbnail
                let thumbnail = PDFStorageManager.shared.generateThumbnail(for: url)
                PDFStorageManager.shared.saveMetadata(fileName: "Scanned Document",
                                                     fileURL: url,
                                                     pageCount: scan.pageCount,
                                                     fileSize: Double(data?.count ?? 0),
                                                     thumbnail: thumbnail)
                parent.onScanCompleted(url)
                
                // Show interstitial after save (frequency capped)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if let rootVC = UIApplication.shared.firstKeyWindow?.rootViewController {
                        _ = AdManager.shared.showInterstitial(from: rootVC, afterScan: true)
                    }
                }
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
