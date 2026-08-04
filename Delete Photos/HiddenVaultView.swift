import SwiftUI
import PhotosUI
import Photos

struct VaultItem: Identifiable, Codable {
    let id: UUID
    let filename: String
    let originalLocalIdentifier: String?
}

class VaultStore: ObservableObject {
    @Published private(set) var items: [VaultItem] = []
    private let fileURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.fileURL = docs.appendingPathComponent("vault.json")
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if let decoded = try? JSONDecoder().decode([VaultItem].self, from: data) {
            items = decoded
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: fileURL, options: [.atomic])
        }
    }

    func add(item: VaultItem) {
        items.append(item)
        save()
    }

    func remove(at offsets: IndexSet) {
        for i in offsets {
            let url = self.url(for: items[i])
            try? FileManager.default.removeItem(at: url)
        }
        items.remove(atOffsets: offsets)
        save()
    }

    func url(for item: VaultItem) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent(item.filename)
    }
}

struct HiddenVaultView: View {
    @StateObject private var vault = VaultStore()
    @State private var selection: [PhotosPickerItem] = []
    @State private var isImporting = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(vault.items) { item in
                    HStack {
                        thumbnailView(for: item)
                            .frame(width: 50, height: 50)
                            .cornerRadius(6)
                            .clipped()
                        Text(item.filename)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .onDelete(perform: vault.remove)
            }
            .navigationTitle("Hidden Vault (\(vault.items.count))")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    PhotosPicker(selection: $selection, matching: .any(of: [.images, .videos]), photoLibrary: .shared(), selectionLimit: 0) {
                        Image(systemName: "plus")
                    }
                    .onChange(of: selection) { newItems in
                        Task {
                            await importAssets(newItems)
                            selection.removeAll()
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func thumbnailView(for item: VaultItem) -> some View {
        let url = vault.url(for: item)
        let ext = url.pathExtension.lowercased()
        if ext == "jpg" || ext == "jpeg" || ext == "png" {
            if let uiImage = UIImage(contentsOfFile: url.path) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.gray)
                    .padding(8)
            }
        } else if ext == "mov" || ext == "mp4" {
            Image(systemName: "video")
                .resizable()
                .scaledToFit()
                .foregroundColor(.gray)
                .padding(8)
        } else {
            Image(systemName: "doc")
                .resizable()
                .scaledToFit()
                .foregroundColor(.gray)
                .padding(8)
        }
    }

    // MARK: - Import

    private func importAssets(_ items: [PhotosPickerItem]) async {
        for picked in items {
            do {
                if let type = picked.supportedContentTypes.first {
                    switch type.identifier {
                    case UTType.image.identifier:
                        try await importImage(picked)
                    case UTType.movie.identifier:
                        try await importVideo(picked)
                    default:
                        // Try image first, then video fallback
                        if await importImage(picked) == false {
                            _ = await importVideo(picked)
                        }
                    }
                } else {
                    // No supported types? Try image fallback.
                    _ = await importImage(picked)
                }
            } catch {
                // ignore errors here
            }
        }
    }

    private func importImage(_ item: PhotosPickerItem) async throws -> Bool {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return false }
        guard let uiImage = UIImage(data: data) else { return false }
        var savedData: Data?
        var ext = "jpg"
        if let jpegData = uiImage.jpegData(compressionQuality: 0.9) {
            savedData = jpegData
            ext = "jpg"
        } else if let pngData = uiImage.pngData() {
            savedData = pngData
            ext = "png"
        }
        guard let finalData = savedData else { return false }
        let filename = "\(UUID().uuidString).\(ext)"
        let url = vault.url(for: VaultItem(id: UUID(), filename: filename, originalLocalIdentifier: nil))
        try finalData.write(to: url, options: [.atomic])
        let originalID = item.itemIdentifier
        let vaultItem = VaultItem(id: UUID(), filename: filename, originalLocalIdentifier: originalID)
        await MainActor.run {
            vault.add(item: vaultItem)
        }
        if let originalID {
            deleteOriginalAsset(with: originalID)
        }
        return true
    }

    private func importVideo(_ item: PhotosPickerItem) async throws -> Bool {
        guard let file = try? await item.loadTransferable(type: FileRepresentation.self) else { return false }
        let ext = file.fileExtension.lowercased()
        guard ext == "mov" || ext == "mp4" else { return false }
        let filename = "\(UUID().uuidString).\(ext)"
        let url = vault.url(for: VaultItem(id: UUID(), filename: filename, originalLocalIdentifier: nil))
        try FileManager.default.copyItem(at: file.fileURL, to: url)
        let originalID = item.itemIdentifier
        let vaultItem = VaultItem(id: UUID(), filename: filename, originalLocalIdentifier: originalID)
        await MainActor.run {
            vault.add(item: vaultItem)
        }
        if let originalID {
            deleteOriginalAsset(with: originalID)
        }
        return true
    }

    private func deleteOriginalAsset(with localIdentifier: String) {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard assets.count > 0 else { return }
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets)
        }
    }
}

extension PhotosPickerItem {
    var itemIdentifier: String? {
        (self as? NSObject)?.value(forKey: "assetIdentifier") as? String
    }
}

struct FileRepresentation: Transferable {
    let fileURL: URL
    let fileExtension: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentationContent()
    }

    init(fileURL: URL) {
        self.fileURL = fileURL
        self.fileExtension = fileURL.pathExtension
    }

    private struct FileRepresentationContent: TransferRepresentation {
        static var representations: [FileRepresentationContent] { [] }

        static func load(from data: Data, contentType: UTType) throws -> FileRepresentation {
            fatalError()
        }

        static func load(from data: Data, contentType: UTType, fileURL: URL) async throws -> FileRepresentation {
            FileRepresentation(fileURL: fileURL)
        }

        static func load(from fileURL: URL, contentType: UTType) async throws -> FileRepresentation {
            FileRepresentation(fileURL: fileURL)
        }

        func transferRepresentation(for fileRepresentation: FileRepresentation) async throws -> Data {
            try Data(contentsOf: fileRepresentation.fileURL)
        }
    }
}

#if DEBUG
#Preview {
    HiddenVaultView()
}
#endif
