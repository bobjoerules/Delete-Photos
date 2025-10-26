import SwiftUI
import Photos
import PhotosUI
struct ContentView: View {
    @State private var photos: [PHAsset] = []
    @State private var currentIndex = 0
    @State private var currentImage: UIImage?
    @State private var swipeOffset: CGSize = .zero
    @State private var selectedForDeletion: Set<Int> = []
    @State private var lastNewestID: String?
    @State private var displayedNewPhotos: Set<String> = []
    var body: some View {
        NavigationStack {
            VStack {
                VStack {
                    ZStack {
                        if let currentImage = currentImage {
                            Image(uiImage: currentImage)
                                .resizable()
                                .scaledToFit()
                                .opacity(Double(1 - min(abs(swipeOffset.width) / 300, 1)))
                                .offset(x: swipeOffset.width, y: swipeOffset.height)
                                .rotationEffect(.degrees(Double(swipeOffset.width / 10)))
                                .scaleEffect(1 - min(abs(swipeOffset.width)/500, 0.5))
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in swipeOffset = value.translation }
                                        .onEnded { value in handleSwipe(value: value) }
                                )
                                .overlay(
                                    selectedForDeletion.contains(currentIndex) ?
                                    Image(systemName: "trash.circle.fill")
                                        .resizable()
                                        .frame(width: 50, height: 50)
                                        .foregroundColor(.red)
                                        .padding() : nil,
                                    alignment: .topTrailing
                                )
                        } else {
                            Text("No photo loaded")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                ZStack {
                    HStack {
                        Spacer() // pushes the settings to the right
                        NavigationLink(destination: SettingsView(resetData: resetData)) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 22))
                                .foregroundStyle(Color.primary) // automatically adapts to light/dark mode
                                .padding()
                                .background(
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                        .opacity(0.1)
                                )
                        }
                        .glassEffect(
                            in: .circle
                        )
                    }
                    Button(action: deleteSelectedPhotos) {
                        Label("Delete Selected", systemImage: "trash")
                            .padding()
                            .foregroundStyle(.black)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                .fill(selectedForDeletion.isEmpty ? Color.red.opacity(0.1) : Color.red)
                            )
                    }
                    .disabled(selectedForDeletion.isEmpty)
                }
                .padding(.horizontal)
            }
        }
        .edgesIgnoringSafeArea(.bottom)
        .onAppear {
            loadPhotos()
            let center = NotificationCenter.default
            center.addObserver(forName: UIApplication.didEnterBackgroundNotification,
                               object: nil, queue: .main) { _ in
                saveCurrentState()
            }
            center.addObserver(forName: UIApplication.willEnterForegroundNotification,
                               object: nil, queue: .main) { _ in
                loadPhotos() // refresh on foreground
            }
            center.addObserver(forName: UIApplication.willTerminateNotification,
                               object: nil, queue: .main) { _ in
                saveCurrentState()
            }
        }
    }
    private func handleSwipe(value: DragGesture.Value) {
        let threshold: CGFloat = 100

        if value.translation.width < -threshold {
            if !selectedForDeletion.contains(currentIndex) {
                selectedForDeletion.insert(currentIndex)
            }
            withAnimation(.spring()) {
                swipeOffset = .zero
                markNewPhotoAsDisplayed()
                showNextPhoto()
            }
        } else if value.translation.width > threshold {
            withAnimation(.spring()) {
                swipeOffset = .zero
                markNewPhotoAsDisplayed()
                showNextPhoto()
            }
        } else {
            withAnimation(.spring()) {
                swipeOffset = .zero
            }
        }
    }
    private func markNewPhotoAsDisplayed() {
        guard currentIndex < photos.count else { return }
        let assetID = photos[currentIndex].localIdentifier
        displayedNewPhotos.insert(assetID)
        UserDefaults.standard.set(Array(displayedNewPhotos), forKey: "displayedNewPhotos")
    }
    private func showPhoto() {
        guard currentIndex < photos.count else { currentImage = nil; return }
        let manager = PHImageManager.default()
        manager.requestImage(for: photos[currentIndex],
                             targetSize: CGSize(width: 1500, height: 1500),
                             contentMode: .aspectFit,
                             options: nil) { result, _ in
            DispatchQueue.main.async {
                currentImage = result
                swipeOffset = .zero
                UserDefaults.standard.set(photos[currentIndex].localIdentifier, forKey: "lastViewedPhoto")
            }
        }
    }
    private func showNextPhoto() {
        currentIndex += 1
        if currentIndex < photos.count {
            showPhoto()
        } else {
            if let lastAsset = photos.last {
                displayedNewPhotos.insert(lastAsset.localIdentifier)
                UserDefaults.standard.set(Array(displayedNewPhotos), forKey: "displayedNewPhotos")
            }
            currentImage = nil
            if let first = photos.first {
                UserDefaults.standard.set(first.localIdentifier, forKey: "lastNewestPhoto")
            }
        }
    }
    // MARK: - Load Photos
    private func loadPhotos() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            guard status == .authorized || status == .limited else { return }
            let fetchOptions = PHFetchOptions()
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            let results = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            var assets: [PHAsset] = []
            results.enumerateObjects { asset, _, _ in assets.append(asset) }
            DispatchQueue.main.async {
                let defaults = UserDefaults.standard
                let lastNewestID = defaults.string(forKey: "lastNewestPhoto")
                let lastViewedID = defaults.string(forKey: "lastViewedPhoto")
                self.displayedNewPhotos = Set(defaults.stringArray(forKey: "displayedNewPhotos") ?? [])
                var newPhotos: [PHAsset] = []
                var oldPhotos: [PHAsset] = []
                if let lastNewestID = lastNewestID,
                   let lastIndex = assets.firstIndex(where: { $0.localIdentifier == lastNewestID }),
                   lastIndex > 0 {
                    newPhotos = Array(assets[0..<lastIndex])
                }
                newPhotos = newPhotos.filter { !displayedNewPhotos.contains($0.localIdentifier) }
                if let lastViewedID = lastViewedID,
                   let lastViewedIndex = assets.firstIndex(where: { $0.localIdentifier == lastViewedID }) {
                    oldPhotos = Array(assets[lastViewedIndex...])
                } else {
                    oldPhotos = assets
                }
                let combined = Array(NSOrderedSet(array: newPhotos + oldPhotos)) as! [PHAsset]
                self.photos = combined
                if !newPhotos.isEmpty {
                    self.currentIndex = 0
                } else if let lastViewedID = lastViewedID,
                          let lastViewedIndex = combined.firstIndex(where: { $0.localIdentifier == lastViewedID }) {
                    self.currentIndex = lastViewedIndex
                } else {
                    self.currentIndex = 0
                }
                self.showPhoto()
                if let newest = assets.first {
                    defaults.set(newest.localIdentifier, forKey: "lastNewestPhoto")
                }
            }
        }
    }
    private func deleteSelectedPhotos() {
        guard !selectedForDeletion.isEmpty else { return }
        let indexesToDelete = selectedForDeletion.filter { $0 != currentIndex }
        guard !indexesToDelete.isEmpty else { return }
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            guard status == .authorized else { return }
            let assetsToDelete = indexesToDelete.map { photos[$0] }
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.deleteAssets(assetsToDelete as NSArray)
            }) { success, error in
                DispatchQueue.main.async {
                    if success {
                        let currentAsset = photos[currentIndex]
                        photos.removeAll { assetsToDelete.contains($0) }
                        selectedForDeletion.subtract(indexesToDelete)
                        if let newIndex = photos.firstIndex(of: currentAsset) {
                            currentIndex = newIndex
                            showPhoto()
                        } else {
                            currentIndex = 0
                            showPhoto()
                        }
                    } else {
                        print("Error deleting: \(error?.localizedDescription ?? "unknown")")
                    }
                }
            }
        }
    }
    private func saveCurrentState() {
        if currentIndex < photos.count {
            UserDefaults.standard.set(photos[currentIndex].localIdentifier, forKey: "lastViewedPhoto")
        }
        UserDefaults.standard.set(Array(displayedNewPhotos), forKey: "displayedNewPhotos")
        UserDefaults.standard.set(Array(selectedForDeletion), forKey: "selectedForDeletion")
    }
    private func resetData() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "lastViewedPhoto")
        defaults.removeObject(forKey: "lastNewestPhoto")
        defaults.removeObject(forKey: "displayedNewPhotos")
        photos.removeAll()
        currentImage = nil
        currentIndex = 0
        selectedForDeletion.removeAll()
        displayedNewPhotos.removeAll()
        lastNewestID = nil
        loadPhotos()
    }
}
