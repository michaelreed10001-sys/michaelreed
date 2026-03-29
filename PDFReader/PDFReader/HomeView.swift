import SwiftUI
import PDFKit
import CoreData
import UniformTypeIdentifiers
import GoogleMobileAds

struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \StoredPDF.createdAt, ascending: false)],
        animation: .default)
    private var documents: FetchedResults<StoredPDF>

    @State private var searchText = ""
    @State private var showingScanner = false
    @State private var showingImagePicker = false
    @State private var showingFavorites = false   // replaces showingSignView
    @State private var showingImporter = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all)

                ScrollView {
                    VStack(spacing: 20) {
                        quickActionsSection

                        HStack {
                            Text("Recent")
                                .font(.title2)
                                .bold()
                            Spacer()
                        }
                        .padding(.horizontal)

                        documentListWithAds
                    }
                    .padding(.bottom, 80) // space for banner
                }

                // Banner ad
                BannerAdView(adUnitID: AdManager.shared.bannerAdUnitID)
                    .frame(height: 50)
                    .background(Color(.systemBackground))
                    .overlay(Divider(), alignment: .top)
            }
            .navigationTitle("PDFs")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingImporter = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    for url in urls {
                        importPDF(from: url)
                    }
                case .failure(let error):
                    print("Import error: \(error)")
                    break
                }
            }
            .sheet(isPresented: $showingScanner) {
                ScanView { url in
                    print("Saved PDF at \(url)")
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImageToPDFView { url in
                    print("Image PDF saved")
                }
            }
            .sheet(isPresented: $showingFavorites) {
                FavoritesView()
                    .environment(\.managedObjectContext, viewContext)
            }
        }
    }

    // MARK: - Quick Actions
    private var quickActionsSection: some View {
        HStack(spacing: 12) {
            QuickActionButton(title: "Scan", color: .blue, icon: "doc.viewfinder") {
                showingScanner = true
            }
            QuickActionButton(title: "Image to PDF", color: .green, icon: "photo.on.rectangle") {
                showingImagePicker = true
            }
            QuickActionButton(title: "Favorites", color: .yellow, icon: "star.fill") {
                showingFavorites = true
            }
            QuickActionButton(title: "New PDF", color: .orange, icon: "doc.badge.plus") {
                createBlankPDF()
            }
        }
        .padding(.horizontal)
    }

    // Document list + native ad injection
    private var documentListWithAds: some View {
        let filteredDocs = documents.filter { searchText.isEmpty ? true : ($0.fileName?.localizedCaseInsensitiveContains(searchText) ?? false) }
        return LazyVStack(spacing: 12) {
            ForEach(Array(filteredDocs.enumerated()), id: \.element.id) { index, doc in
                // Ensure the URL is valid before passing it
                let pdfURL: URL? = {
                    guard let path = doc.fileURL else { return nil }
                    let url = URL(fileURLWithPath: path)
                    // Optional: verify file exists
                    if FileManager.default.fileExists(atPath: path) {
                        return url
                    } else {
                        print("⚠️ Missing file: \(path)")
                        return nil
                    }
                }()
                
                if let validURL = pdfURL {
                    NavigationLink(destination: PDFReaderView(url: validURL)) {
                        DocumentCardView(document: doc)
                            .padding(.horizontal)
                    }
                    .buttonStyle(.plain)
                } else {
                    // Show a placeholder for broken files (optional)
                    DocumentCardView(document: doc)
                        .padding(.horizontal)
                        .opacity(0.5)
                        .overlay(
                            Text("File missing")
                                .font(.caption)
                                .foregroundColor(.red)
                        )
                }

                // Insert native ad card every 6 documents
                if (index + 1) % 6 == 0 {
                    NativeAdCardView()
                        .padding(.horizontal)
                }
            }
        }
    }

    private func createBlankPDF() {
        let pdfDocument = PDFKit.PDFDocument()
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 612, height: 792))
        let image = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 612, height: 792))
        }
        if let pdfPage = PDFKit.PDFPage(image: image) {
            pdfDocument.insert(pdfPage, at: 0)
        }
        let data = pdfDocument.dataRepresentation()!
        if let url = PDFStorageManager.shared.savePDF(data: data, fileName: "Blank_\(Date().timeIntervalSince1970)") {
            PDFStorageManager.shared.saveMetadata(fileName: "Blank PDF",
                                                 fileURL: url,
                                                 pageCount: 1,
                                                 fileSize: Double(data.count),
                                                 thumbnail: nil)
        }
    }

    private func importPDF(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let data = try Data(contentsOf: url)
            let fileName = url.lastPathComponent
            if let savedURL = PDFStorageManager.shared.savePDF(data: data, fileName: fileName) {
                let pdfDocument = PDFKit.PDFDocument(url: savedURL)
                let pageCount = pdfDocument?.pageCount ?? 1
                let thumbnail = PDFStorageManager.shared.generateThumbnail(for: savedURL)
                PDFStorageManager.shared.saveMetadata(
                    fileName: fileName,
                    fileURL: savedURL,
                    pageCount: pageCount,
                    fileSize: Double(data.count),
                    thumbnail: thumbnail
                )
            }
        } catch {
            print("Failed to read PDF data: \(error)")
        }
    }
}

// MARK: - Favorites View
struct FavoritesView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \StoredPDF.createdAt, ascending: false)],
        predicate: NSPredicate(format: "isFavorite == YES"),
        animation: .default)
    private var favoriteDocuments: FetchedResults<StoredPDF>

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).edgesIgnoringSafeArea(.all)
                
                if favoriteDocuments.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "star.slash")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("No favorites yet")
                            .font(.headline)
                        Text("Mark a PDF as favorite from its menu")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(favoriteDocuments, id: \.id) { doc in
                                let pdfURL: URL? = {
                                    guard let path = doc.fileURL else { return nil }
                                    let url = URL(fileURLWithPath: path)
                                    if FileManager.default.fileExists(atPath: path) {
                                        return url
                                    } else {
                                        print("⚠️ Missing favorite file: \(path)")
                                        return nil
                                    }
                                }()
                                
                                if let validURL = pdfURL {
                                    NavigationLink(destination: PDFReaderView(url: validURL)) {
                                        DocumentCardView(document: doc)
                                            .padding(.horizontal)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    DocumentCardView(document: doc)
                                        .padding(.horizontal)
                                        .opacity(0.5)
                                        .overlay(
                                            Text("File missing")
                                                .font(.caption)
                                                .foregroundColor(.red)
                                        )
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Quick Action Button Component
struct QuickActionButton: View {
    let title: String
    let color: Color
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: icon)
                            .font(.title2)
                            .foregroundColor(color)
                    )
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
