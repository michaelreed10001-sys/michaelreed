import SwiftUI
import PDFKit

struct SignaturePlacementView: View {
    let pdfURL: URL
    let signatureImage: UIImage
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack(spacing: 20) {
            Text("Adding signature to PDF...")
                .font(.headline)
                .padding()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .onAppear {
            appendSignatureAsNewPage()
        }
        .navigationBarTitle("Signing", displayMode: .inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }

    private func appendSignatureAsNewPage() {
        guard let originalDocument = PDFDocument(url: pdfURL) else {
            presentationMode.wrappedValue.dismiss()
            return
        }

        guard let signaturePage = PDFPage(image: signatureImage) else {
            presentationMode.wrappedValue.dismiss()
            return
        }

        originalDocument.insert(signaturePage, at: originalDocument.pageCount)

        let data = originalDocument.dataRepresentation()
        let newFileName = "Signed_\(pdfURL.lastPathComponent)"
        if let newURL = PDFStorageManager.shared.savePDF(data: data!, fileName: newFileName) {
            let thumbnail = PDFStorageManager.shared.generateThumbnail(for: newURL)
            PDFStorageManager.shared.saveMetadata(
                fileName: newFileName,
                fileURL: newURL,
                pageCount: originalDocument.pageCount,
                fileSize: Double(data?.count ?? 0),
                thumbnail: thumbnail
            )
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            presentationMode.wrappedValue.dismiss()
        }
    }
}
