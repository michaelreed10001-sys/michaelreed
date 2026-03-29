import SwiftUI
import PhotosUI
import PDFKit

struct ImageToPDFView: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    var onComplete: (URL) -> Void
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 0 // 0 = unlimited
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImageToPDFView
        
        init(_ parent: ImageToPDFView) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard !results.isEmpty else {
                parent.presentationMode.wrappedValue.dismiss()
                return
            }
            
            // Show interstitial before export (per spec)
            if let rootVC = UIApplication.shared.firstKeyWindow?.rootViewController {
                _ = AdManager.shared.showInterstitial(from: rootVC)
            }
            
            // Load images and create PDF (simplified: we take first image only for demo)
            let itemProvider = results.first?.itemProvider
            if let itemProvider = itemProvider, itemProvider.canLoadObject(ofClass: UIImage.self) {
                itemProvider.loadObject(ofClass: UIImage.self) { image, error in
                    
                    // Inside the itemProvider.loadObject closure, after getting the image:
                    DispatchQueue.main.async {
                        if let image = image as? UIImage {
                            let pdfDocument = PDFKit.PDFDocument()
                            if let pdfPage = PDFKit.PDFPage(image: image) {
                                pdfDocument.insert(pdfPage, at: 0)
                            }
                            let data = pdfDocument.dataRepresentation()
                            if let url = PDFStorageManager.shared.savePDF(data: data!, fileName: "Image_\(Date().timeIntervalSince1970)") {
                                let thumbnail = PDFStorageManager.shared.generateThumbnail(for: url)
                                PDFStorageManager.shared.saveMetadata(fileName: "Image to PDF",
                                                                     fileURL: url,
                                                                     pageCount: 1,
                                                                     fileSize: Double(data?.count ?? 0),
                                                                     thumbnail: thumbnail)
                                self.parent.onComplete(url)
                            }
                        }
                        self.parent.presentationMode.wrappedValue.dismiss()
                    }
                }
            } else {
                parent.presentationMode.wrappedValue.dismiss()
            }
        }
    }
}
