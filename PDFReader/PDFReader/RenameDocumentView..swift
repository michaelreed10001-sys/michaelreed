import SwiftUI
import CoreData

struct RenameDocumentView: View {
    @ObservedObject var document: StoredPDF
    @Environment(\.dismiss) var dismiss
    @State private var newName: String
    
    init(document: StoredPDF) {
        self.document = document
        _newName = State(initialValue: document.fileName ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                TextField("File name", text: $newName)
                    .autocapitalization(.none)
            }
            .navigationTitle("Rename PDF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if !newName.isEmpty {
                            document.fileName = newName
                            try? document.managedObjectContext?.save()
                            renamePhysicalFile(to: newName)
                        }
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func renamePhysicalFile(to newName: String) {
        guard let oldURLString = document.fileURL,
              let oldURL = URL(string: oldURLString) else { return }
        let directory = oldURL.deletingLastPathComponent()
        let fileExtension = oldURL.pathExtension
        let newFileName = newName + "." + fileExtension
        let newURL = directory.appendingPathComponent(newFileName)
        
        do {
            try FileManager.default.moveItem(at: oldURL, to: newURL)
            document.fileURL = newURL.path
            try? document.managedObjectContext?.save()
        } catch {
//            print("Failed to rename file: \(error)")
        }
    }
}//
//  RenameDocumentView..swift
//  PDFReader
//
//  Created by Admin on 10/03/2026.
//

