import SwiftUI
import PhotosUI
import Photos
import Combine
import UniformTypeIdentifiers
import AVKit

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
    @EnvironmentObject var vault: VaultStore
    @State private var selection: [PhotosPickerItem] = []
    @State private var selectedPreviewIndex: Int? = nil
    @State private var isSelectionMode = false
    @State private var selectedItems: Set<UUID> = []

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if vault.items.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("No Photos or Videos")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Tap + to import from your library")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(0..<vault.items.count, id: \.self) { index in
                                let item = vault.items[index]
                                thumbnailView(for: item)
                                    .aspectRatio(1, contentMode: .fill)
                                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                                    .clipped()
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if isSelectionMode {
                                            if selectedItems.contains(item.id) {
                                                selectedItems.remove(item.id)
                                            } else {
                                                selectedItems.insert(item.id)
                                            }
                                        } else {
                                            selectedPreviewIndex = index
                                        }
                                    }
                                    .contextMenu {
                                        if !isSelectionMode {
                                            Button(role: .destructive) {
                                                vault.remove(at: IndexSet(integer: index))
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
            }
            .navigationTitle(isSelectionMode ? "Selected (\(selectedItems.count))" : "Hidden Vault (\(vault.items.count))")
            .sheet(isPresented: Binding<Bool>(
                get: { selectedPreviewIndex != nil },
                set: { if !$0 { selectedPreviewIndex = nil } }
            )) {
                if let index = selectedPreviewIndex, index >= 0 && index < vault.items.count {
                    VaultGalleryPreviewView(selectedIndex: Binding<Int>(
                        get: { selectedPreviewIndex ?? 0 },
                        set: { selectedPreviewIndex = $0 }
                    ), vault: vault)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        if isSelectionMode {
                            Button(role: .destructive) {
                                deleteSelectedItems()
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(selectedItems.isEmpty ? .secondary : .red)
                            }
                            .disabled(selectedItems.isEmpty)
                            
                            Button("Cancel") {
                                withAnimation {
                                    isSelectionMode = false
                                    selectedItems.removeAll()
                                }
                            }
                        } else {
                            if !vault.items.isEmpty {
                                Button("Select") {
                                    withAnimation {
                                        isSelectionMode = true
                                        selectedItems.removeAll()
                                    }
                                }
                            }
                            
                            PhotosPicker(
                                selection: $selection,
                                maxSelectionCount: nil,
                                matching: .any(of: [.images, .videos]),
                                photoLibrary: .shared()
                            ) {
                                Image(systemName: "plus")
                            }
                            .onChange(of: selection) { oldValue, newValue in
                                guard !newValue.isEmpty else { return }
                                Task {
                                    await importAssets(newValue)
                                    selection = []
                                }
                            }
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
        GeometryReader { geo in
            ZStack(alignment: .bottomTrailing) {
                if ext == "jpg" || ext == "jpeg" || ext == "png" {
                    if let uiImage = UIImage(contentsOfFile: url.path) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    } else {
                        placeholderThumbnail
                    }
                } else if ext == "mov" || ext == "mp4" {
                    placeholderVideoThumbnail
                } else {
                    placeholderThumbnail
                }
                
                if ext == "mov" || ext == "mp4" {
                    Image(systemName: "play.circle.fill")
                        .foregroundColor(.white)
                        .shadow(radius: 2)
                        .padding(6)
                }
                
                if isSelectionMode {
                    let isSelected = selectedItems.contains(item.id)
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? .blue : .white.opacity(0.8))
                        .shadow(radius: 2)
                        .padding(6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
        }
    }

    private var placeholderThumbnail: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.2))
            .overlay(
                Image(systemName: "photo")
                    .foregroundColor(.secondary)
            )
    }

    private var placeholderVideoThumbnail: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.2))
            .overlay(
                Image(systemName: "video")
                    .foregroundColor(.secondary)
            )
    }

    private func deleteSelectedItems() {
        var indicesToDelete = IndexSet()
        for i in 0..<vault.items.count {
            if selectedItems.contains(vault.items[i].id) {
                indicesToDelete.insert(i)
            }
        }
        
        vault.remove(at: indicesToDelete)
        
        withAnimation {
            isSelectionMode = false
            selectedItems.removeAll()
        }
    }

    // MARK: - Import

    @MainActor
    private func importAssets(_ items: [PhotosPickerItem]) async {
        var idsToDelete: [String] = []
        for picked in items {
            if let type = picked.supportedContentTypes.first {
                switch type.identifier {
                case UTType.image.identifier:
                    if let id = await importImage(picked) {
                        idsToDelete.append(id)
                    }
                case UTType.movie.identifier:
                    if let id = await importVideo(picked) {
                        idsToDelete.append(id)
                    }
                default:
                    // Try image first, then video fallback
                    if let id = await importImage(picked) {
                        idsToDelete.append(id)
                    } else if let id = await importVideo(picked) {
                        idsToDelete.append(id)
                    }
                }
            } else {
                // No supported types? Try image fallback.
                if let id = await importImage(picked) {
                    idsToDelete.append(id)
                }
            }
        }
        
        if !idsToDelete.isEmpty {
            deleteOriginalAssets(with: idsToDelete)
        }
    }

    @MainActor
    private func importImage(_ item: PhotosPickerItem) async -> String? {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return nil }
        guard let uiImage = UIImage(data: data) else { return nil }
        var savedData: Data?
        var ext = "jpg"
        if let jpegData = uiImage.jpegData(compressionQuality: 0.9) {
            savedData = jpegData
            ext = "jpg"
        } else if let pngData = uiImage.pngData() {
            savedData = pngData
            ext = "png"
        }
        guard let finalData = savedData else { return nil }
        let filename = "\(UUID().uuidString).\(ext)"
        let url = vault.url(for: VaultItem(id: UUID(), filename: filename, originalLocalIdentifier: nil))
        if (try? finalData.write(to: url, options: [.atomic])) == nil { return nil }
        let originalID = item.itemIdentifier
        let vaultItem = VaultItem(id: UUID(), filename: filename, originalLocalIdentifier: originalID)
        vault.add(item: vaultItem)
        return originalID
    }

    @MainActor
    private func importVideo(_ item: PhotosPickerItem) async -> String? {
        // Attempt to load raw data for the video from the picker
        guard let data = try? await item.loadTransferable(type: Data.self) else { return nil }

        // Determine file extension from supported content type; default to mov
        let ext: String = {
            if let type = item.supportedContentTypes.first {
                if type.conforms(to: .mpeg4Movie) { return "mp4" }
                if type.conforms(to: .quickTimeMovie) { return "mov" }
                if let preferred = type.preferredFilenameExtension { return preferred }
            }
            return "mov"
        }()

        let filename = "\(UUID().uuidString).\(ext)"
        let tempItem = VaultItem(id: UUID(), filename: filename, originalLocalIdentifier: nil)
        let url = vault.url(for: tempItem)
        if (try? data.write(to: url, options: [.atomic])) == nil { return nil }

        let originalID = item.itemIdentifier
        let vaultItem = VaultItem(id: UUID(), filename: filename, originalLocalIdentifier: originalID)
        vault.add(item: vaultItem)
        return originalID
    }

    @MainActor
    private func deleteOriginalAssets(with localIdentifiers: [String]) {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: localIdentifiers, options: nil)
        guard assets.count > 0 else { return }
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.deleteAssets(assets)
        }, completionHandler: { _, _ in })
    }
}

struct VaultGalleryPreviewView: View {
    @Binding var selectedIndex: Int
    @ObservedObject var vault: VaultStore
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            TabView(selection: $selectedIndex) {
                ForEach(0..<vault.items.count, id: \.self) { index in
                    let item = vault.items[index]
                    VaultDetailView(item: item, vault: vault)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .indexViewStyle(.page(backgroundDisplayMode: .never))
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("\(selectedIndex + 1) of \(vault.items.count)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(role: .destructive) {
                        deleteCurrentItem()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
    
    private func deleteCurrentItem() {
        guard selectedIndex >= 0 && selectedIndex < vault.items.count else { return }
        let indexToDelete = selectedIndex
        
        vault.remove(at: IndexSet(integer: indexToDelete))
        
        if vault.items.isEmpty {
            dismiss()
        } else if selectedIndex >= vault.items.count {
            selectedIndex = vault.items.count - 1
        }
    }
}

struct VaultDetailView: View {
    let item: VaultItem
    @ObservedObject var vault: VaultStore
    
    var body: some View {
        VStack {
            Spacer()
            let url = vault.url(for: item)
            let ext = url.pathExtension.lowercased()
            if ext == "jpg" || ext == "jpeg" || ext == "png" {
                if let uiImage = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .padding()
                } else {
                    placeholderView
                }
            } else if ext == "mov" || ext == "mp4" {
                VideoPlayer(player: AVPlayer(url: url))
                    .padding()
            } else {
                placeholderView
            }
            Spacer()
        }
    }
    
    private var placeholderView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            Text("Cannot load preview")
                .foregroundColor(.secondary)
        }
    }
}

#if DEBUG
#Preview {
    HiddenVaultView()
        .environmentObject(VaultStore())
}
#endif
