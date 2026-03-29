import SwiftUI
import PDFKit
import UIKit

enum AnnotationTool {
    case text
}

struct PDFReaderView: View {
    let url: URL
    @State private var pdfView = PDFView()
    @State private var showControls = true
    @State private var showAnnotationToolbar = false
    @State private var selectedTool: AnnotationTool? = nil
    @State private var annotationColor: Color = .black
    @State private var textToAdd = ""
    @State private var showingTextEntry = false

    var body: some View {
        ZStack {
            PDFViewWrapper(url: url, pdfView: pdfView)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation { showControls.toggle() }
                }

            if showControls && showAnnotationToolbar {
                VStack {
                    Spacer()
                    annotationToolbar
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .padding()
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button("Annotate") {
                    showAnnotationToolbar.toggle()
                }
                Spacer()
                Button("Share") { sharePDF() }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            saveChanges()
        }
        .alert("Add Text", isPresented: $showingTextEntry) {
            TextField("Enter text", text: $textToAdd)
            Button("Cancel", role: .cancel) { }
            Button("Add") {
                addTextAnnotation()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .textToolTapped)) { _ in
            showingTextEntry = true
        }
    }

    var annotationToolbar: some View {
        HStack(spacing: 20) {
            Button(action: { toggleTextTool() }) {
                Image(systemName: "textbox")
                    .foregroundColor(selectedTool == .text ? .blue : .primary)
            }
            Divider().frame(height: 24)
            ColorPicker("", selection: $annotationColor)
                .labelsHidden()
                .onChange(of: annotationColor) { _, _ in }
            Divider().frame(height: 24)
            Button(action: { pdfView.undoManager?.undo() }) {
                Image(systemName: "arrow.uturn.backward")
            }
            Button(action: { pdfView.undoManager?.redo() }) {
                Image(systemName: "arrow.uturn.forward")
            }
        }
        .font(.title2)
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    func toggleTextTool() {
        if selectedTool == .text {
            selectedTool = nil
        } else {
            selectedTool = .text
        }
    }

    func addTextAnnotation() {
        guard !textToAdd.isEmpty, let page = pdfView.currentPage else { return }
        let pageBounds = page.bounds(for: .cropBox)
        let centerPoint = CGPoint(x: pageBounds.midX, y: pageBounds.midY)
        let annotation = PDFAnnotation(bounds: CGRect(x: centerPoint.x - 100, y: centerPoint.y - 20, width: 200, height: 100),
                                       forType: .freeText,
                                       withProperties: nil)
        annotation.contents = textToAdd
        annotation.font = UIFont.systemFont(ofSize: 12)
        annotation.fontColor = UIColor(annotationColor)
        annotation.color = UIColor(annotationColor).withAlphaComponent(0.3)
        page.addAnnotation(annotation)
        textToAdd = ""
        selectedTool = nil
    }

    func sharePDF() {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }

    func saveChanges() {
        guard let document = pdfView.document,
              let data = document.dataRepresentation() else { return }
        do {
            try data.write(to: url)
        } catch {
            print("Failed to save PDF: \(error)")
        }
    }
}

struct PDFViewWrapper: UIViewRepresentable {
    let url: URL
    let pdfView: PDFView

    func makeUIView(context: Context) -> PDFView {
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .systemGroupedBackground
        if let document = PDFDocument(url: url) {
            pdfView.document = document
        }
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = context.coordinator
        pdfView.addGestureRecognizer(tap)
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let parent: PDFViewWrapper
        init(_ parent: PDFViewWrapper) { self.parent = parent }
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            NotificationCenter.default.post(name: .textToolTapped, object: nil)
        }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }
    }
}

extension Notification.Name {
    static let textToolTapped = Notification.Name("textToolTapped")
}
