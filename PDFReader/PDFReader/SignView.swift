import SwiftUI
import PDFKit
import PencilKit

struct SignView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.displayScale) var displayScale
    @State private var canvasView = PKCanvasView()
    
    var onSave: (UIImage) -> Void
    var originalPDFURL: URL?  // Optional – if provided, signature will be appended to this PDF
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).edgesIgnoringSafeArea(.all)
                VStack {
                    Text("Sign here")
                        .font(.headline)
                        .padding()
                    
                    SignatureCanvas(canvasView: $canvasView)
                        .frame(height: 200)
                        .border(Color.gray.opacity(0.5))
                        .padding()
                    
                    HStack {
                        Button("Clear") {
                            canvasView.drawing = PKDrawing()
                        }
                        Spacer()
                        Button("Save") {
                            let image = canvasView.drawing.image(from: canvasView.bounds, scale: displayScale)
                            
                            if let originalURL = originalPDFURL {
                                // Merge signature into existing PDF
                                mergeSignatureIntoPDF(image: image, originalPDFURL: originalURL)
                            } else {
                                // Create standalone signature PDF
                                createStandaloneSignaturePDF(image: image)
                            }
                            
                            onSave(image)
                            presentationMode.wrappedValue.dismiss()
                        }
                        .bold()
                    }
                    .padding(.horizontal, 40)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    private func mergeSignatureIntoPDF(image: UIImage, originalPDFURL: URL) {
        // Load the original PDF
        guard let originalDocument = PDFDocument(url: originalPDFURL) else {
            print("Failed to load original PDF")
            return
        }
        
        // Create a new PDF page from the signature image
        guard let signaturePage = PDFPage(image: image) else {
            print("Failed to create page from signature")
            return
        }
        
        // Append the signature page to the original document
        originalDocument.insert(signaturePage, at: originalDocument.pageCount)
        
        // Save the new document
        let data = originalDocument.dataRepresentation()
        let fileName = "Signed_" + originalPDFURL.lastPathComponent
        if let url = PDFStorageManager.shared.savePDF(data: data!, fileName: fileName) {
            let thumbnail = PDFStorageManager.shared.generateThumbnail(for: url)
            PDFStorageManager.shared.saveMetadata(
                fileName: fileName,
                fileURL: url,
                pageCount: originalDocument.pageCount + 1,
                fileSize: Double(data?.count ?? 0),
                thumbnail: thumbnail
            )
        }
    }
    
    private func createStandaloneSignaturePDF(image: UIImage) {
        let pdfDocument = PDFDocument()
        if let pdfPage = PDFPage(image: image) {
            pdfDocument.insert(pdfPage, at: 0)
        }
        let data = pdfDocument.dataRepresentation()!
        if let url = PDFStorageManager.shared.savePDF(data: data, fileName: "Signed_\(Date().timeIntervalSince1970)") {
            let thumbnail = PDFStorageManager.shared.generateThumbnail(for: url)
            PDFStorageManager.shared.saveMetadata(
                fileName: "Signed Document",
                fileURL: url,
                pageCount: 1,
                fileSize: Double(data.count),
                thumbnail: thumbnail
            )
        }
    }
}

struct SignatureCanvas: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    
    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 2)
        return canvasView
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {}
}
