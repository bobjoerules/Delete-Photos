import SwiftUI
import Photos
import PhotosUI
struct ContentView: View {
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @State private var photos: [PHAsset] = []
    @State private var currentIndex = 0
    @State private var delaycurrentIndex = 0
    @State private var currentImage: UIImage?
    @State private var swipeOffset: CGSize = .zero
    @State private var selectedForDeletion: Set<Int> = []
    @State private var lastNewestID: String?
    @State private var displayedNewPhotos: Set<String> = []
    @State private var currentEmoji = "😀"
    let emojis = ["😀", "😃", "😄", "😁", "😆", "😅", "😂", "🤣", "😊", "😇", "🙂", "🙃", "😉", "😌", "😍", "🥰", "😘", "😗", "😙", "😚", "😋", "😛", "😝", "😜", "🤪", "🤨", "🧐", "🤓", "😎", "🥸", "🤩", "🥳", "😏", "😒", "😞", "😔", "😟", "😕", "🙁", "☹️", "😣", "😖", "😫", "😩", "🥺", "😢", "😭", "😤", "😠", "😡", "🤬", "🤯", "😳", "🥴", "😵", "😵‍💫", "😱", "😨", "😰", "😥", "😓", "🤗", "🫣", "🫢", "🤔", "🤭", "🤫", "🤥", "😶", "😶‍🌫️", "😐", "😑", "😬", "🫠", "😴", "🤤", "😪", "😮‍💨", "😮", "😯", "😲", "😧", "😦", "😮‍💨", "🥹", "😇", "🤠", "💀"]
    let impact = UIImpactFeedbackGenerator(style: .heavy)
    init() {
            _currentEmoji = State(initialValue: emojis.randomElement() ?? "😀")
        }
    var body: some View {
        NavigationStack {
            ZStack {
// MARK: - Share Button
                HStack {
                    Spacer()
                    Button(action: {
                        if hapticsEnabled {
                            impact.impactOccurred()
                        }
                        shareCurrentPhoto()
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 22))
                            .foregroundStyle(Color.primary) // automatically adapts to light/dark mode
                            .padding(10)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .disabled(currentImage == nil)
                }
                Text("Swipe Delete")
                    .font(.largeTitle)
                    .bold()
                    .padding()
// MARK: - Emoji Button
                HStack {
                    Button(action: {
                        currentEmoji = emojis.randomElement() ?? "😀"
                        if hapticsEnabled {
                            impact.impactOccurred()
                        }
                    }) {
                        Text(currentEmoji)
                            .font(.system(size: 22))
                            .padding(10)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .buttonRepeatBehavior(.enabled)
                    Spacer()
                }
            }
            .padding(.horizontal)
            VStack {
                VStack {
// MARK: - Current Photo
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
                                        .onChanged {
                                            value in swipeOffset = CGSize(width: value.translation.width, height: 0)
                                        }
                                        .onEnded { value in handleSwipe(value: value) }
                                )
                        } else {
                            Text("No photo loaded")
                                .foregroundStyle(.secondary)
                        }
// MARK: - Selected For Deletion Indicator
                        VStack {
                            HStack {
                                Spacer()
                                if selectedForDeletion.contains(currentIndex) {
                                    Image(systemName: "trash.circle.fill")
                                        .resizable()
                                        .frame(width: 50, height: 50)
                                        .foregroundColor(.red)
                                        .padding()
                                }
                            }
                            Spacer()
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                if !photos.isEmpty && currentImage != nil {
                    Text("\(currentIndex) / \(photos.count)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 8)
                        .transition(.opacity)
                }
                ZStack {
// MARK: - Settings Button
                    HStack {
                        Spacer()
                        NavigationLink(destination: SettingsView(
                            resetData: resetData,
                            skipToLastPhoto: {
                                guard !photos.isEmpty else { return }
                                currentIndex = photos.count - 1
                                delaycurrentIndex = photos.count - 1
                                showPhoto()
                            }
                        )) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 22))
                                .foregroundStyle(Color.primary) // automatically adapts to light/dark mode
                                .padding(10)
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .simultaneousGesture(TapGesture().onEnded {
                            if hapticsEnabled {
                                impact.impactOccurred()
                            }
                        })
                    }
// MARK: - Delete Selected Button
                    Button(action: {
                        if hapticsEnabled {
                            impact.impactOccurred()
                        }
                        deleteSelectedPhotos()
                    }) {
                        Label("Delete Selected", systemImage: "trash")
                            .padding()
                    }
                    .buttonStyle(.glassProminent)
                    .tint(selectedForDeletion.isEmpty ? .gray : .red)
                    .opacity(selectedForDeletion.isEmpty ? 0.3 : 1)
                    .disabled(selectedForDeletion.isEmpty)
// MARK: - Undo Swipe Button
                    HStack {
                        Button(action: {
                            if hapticsEnabled {
                                if currentIndex > 0 {
                                    impact.impactOccurred()
                                }
                            }
                            undoLastSwipe()
                        }) {
                            Image(systemName: "arrow.uturn.backward.circle")
                                .font(.system(size: 22))
                                .foregroundStyle(Color.primary.opacity(delaycurrentIndex == 0 ? 0.3 : 1.0))
                                .padding(10)
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .buttonRepeatBehavior(.enabled)
                        .disabled(delaycurrentIndex == 0)
                        Spacer()
                    }
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
// MARK: - Swipe Handling
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
                if hapticsEnabled {
                    impact.impactOccurred()
                }
            }
        } else if value.translation.width > threshold {
            withAnimation(.spring()) {
                swipeOffset = .zero
                markNewPhotoAsDisplayed()
                showNextPhoto()
                if hapticsEnabled {
                    impact.impactOccurred()
                }
            }
        } else {
            withAnimation(.spring()) {
                swipeOffset = .zero
            }
        }
    }
// MARK: - Mark Photo As Displayed
    private func markNewPhotoAsDisplayed() {
        guard currentIndex < photos.count else { return }
        let assetID = photos[currentIndex].localIdentifier
        displayedNewPhotos.insert(assetID)
        UserDefaults.standard.set(Array(displayedNewPhotos), forKey: "displayedNewPhotos")
    }
// MARK: - Show Photo
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
// MARK: - Show Next Photo
    private func showNextPhoto() {
        currentIndex += 1
        delaycurrentIndex += 1
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
// MARK: - Delete Selected Photos
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
                            delaycurrentIndex = 0
                            showPhoto()
                        } else {
                            currentIndex = 0
                            delaycurrentIndex = 0
                            showPhoto()
                        }
                    } else {
                        print("Error deleting: \(error?.localizedDescription ?? "unknown")")
                    }
                }
            }
        }
    }
// MARK: - Save Current State
    private func saveCurrentState() {
        if currentIndex < photos.count {
            UserDefaults.standard.set(photos[currentIndex].localIdentifier, forKey: "lastViewedPhoto")
        }
        UserDefaults.standard.set(Array(displayedNewPhotos), forKey: "displayedNewPhotos")
        UserDefaults.standard.set(Array(selectedForDeletion), forKey: "selectedForDeletion")
    }
// MARK: - Reset Data
    private func resetData() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "lastViewedPhoto")
        defaults.removeObject(forKey: "lastNewestPhoto")
        defaults.removeObject(forKey: "displayedNewPhotos")
        photos.removeAll()
        currentImage = nil
        currentIndex = 0
        delaycurrentIndex = 0
        selectedForDeletion.removeAll()
        displayedNewPhotos.removeAll()
        lastNewestID = nil
        loadPhotos()
    }
// MARK: - Share Photo
    private func shareCurrentPhoto() {
        guard let image = currentImage else { return }
        let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)

        // Present the share sheet
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = scene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
// MARK: - Undo Swipe
    private func undoLastSwipe() {
        guard currentIndex > 0 else { return }
        withAnimation(.spring()) {
            currentIndex -= 1
            Task {
                    try await Task.sleep(for: .seconds(0.5))
                    delaycurrentIndex -= 1
                }
            selectedForDeletion.remove(currentIndex)
            showPhoto()
        }
    }
}
