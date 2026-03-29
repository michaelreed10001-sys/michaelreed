import SwiftUI
import CoreData

struct DocumentCardView: View {
    @ObservedObject var document: StoredPDF
    @State private var showingRenameSheet = false
    @State private var showingSignSheet = false
    @State private var showingPlacementSheet = false
    @State private var drawnSignature: UIImage?

    var body: some View {
        HStack(spacing: 16) {
            // Thumbnail with favorite star
            ZStack(alignment: .topTrailing) {
                if let thumbData = document.thumbnailData, let uiImage = UIImage(data: thumbData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .frame(width: 60, height: 80)
                        .cornerRadius(8)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 80)
                        .cornerRadius(8)
                        .overlay(Image(systemName: "doc").foregroundColor(.gray))
                }

                if document.isFavorite {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .padding(4)
                        .background(Circle().fill(Color.white))
                        .offset(x: 8, y: -8)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(document.fileName ?? "Untitled")
                    .font(.headline)
                    .lineLimit(1)
                Text("\(document.pageCount) pages · \(formattedSize(document.fileSize))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(formattedDate(document.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()

            Menu {
                Button("Rename", action: renameDocument)
                Button("Share", action: shareDocument)
                if document.isFavorite {
                    Button("Unfavorite", action: toggleFavorite)
                } else {
                    Button("Favorite", action: toggleFavorite)
                }
                Button("Print", action: printDocument)
                Button("Sign", action: signDocument)
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        .sheet(isPresented: $showingRenameSheet) {
            RenameDocumentView(document: document)
        }
        .sheet(isPresented: $showingSignSheet) {
            SignView { image in
                drawnSignature = image
                showingSignSheet = false
                showingPlacementSheet = true
            }
        }
        .sheet(isPresented: $showingPlacementSheet) {
            if let signature = drawnSignature,
               let url = URL(string: document.fileURL ?? "") {
                SignaturePlacementView(pdfURL: url, signatureImage: signature)
            }
        }
    }

    // MARK: - Helpers
    private func formattedSize(_ size: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Menu Actions
    private func renameDocument() {
        showingRenameSheet = true
    }

    private func shareDocument() {
        guard let urlString = document.fileURL, let url = URL(string: urlString) else { return }
        let av = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(av, animated: true)
        }
    }

    private func toggleFavorite() {
        document.isFavorite.toggle()
        try? document.managedObjectContext?.save()
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func printDocument() {
        guard let urlString = document.fileURL, let url = URL(string: urlString) else { return }
        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.jobName = document.fileName ?? "PDF"
        printInfo.outputType = .general
        printController.printInfo = printInfo
        printController.printingItem = url
        printController.present(animated: true)
    }

    private func signDocument() {
        showingSignSheet = true
    }
}
