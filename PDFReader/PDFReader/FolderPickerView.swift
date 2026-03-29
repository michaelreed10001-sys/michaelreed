import SwiftUI

struct FolderPickerView: View {
    let currentFileURL: URL
    @Environment(\.dismiss) var dismiss
    @State private var folders: [URL] = []
    @State private var showingNewFolderAlert = false
    @State private var newFolderName = ""
    
    var onMove: (URL) -> Void  // callback with the destination folder URL
    
    var body: some View {
        NavigationView {
            List {
                ForEach(folders, id: \.self) { folder in
                    HStack {
                        Image(systemName: "folder")
                        Text(folder.lastPathComponent)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onMove(folder)
                        dismiss()
                    }
                }
            }
            .navigationTitle("Choose Folder")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("New Folder") { showingNewFolderAlert = true }
                }
            }
            .alert("New Folder", isPresented: $showingNewFolderAlert) {
                TextField("Name", text: $newFolderName)
                Button("Cancel", role: .cancel) { newFolderName = "" }
                Button("Create") {
                    createFolder(named: newFolderName)
                    newFolderName = ""
                }
            } message: {
                Text("Enter a name for the new folder.")
            }
            .onAppear {
                loadFolders()
            }
        }
    }
    
    private func loadFolders() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: documents, includingPropertiesForKeys: nil)
            folders = contents.filter { $0.hasDirectoryPath }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
        } catch {
//            print("Failed to load folders: \(error)")
        }
    }
    
    private func createFolder(named name: String) {
        guard !name.isEmpty else { return }
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let newFolder = documents.appendingPathComponent(name)
        do {
            try FileManager.default.createDirectory(at: newFolder, withIntermediateDirectories: false)
            loadFolders() // refresh list
        } catch {
            print("Failed to create folder: \(error)")
        }
    }
}
