import SwiftUI
import Photos
import PhotosUI
import LinkPresentation

struct ContentView: View {
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("hiddenFolderEnabled") private var hiddenFolderEnabled = false
    @AppStorage("flashFeedbackEnabled") private var flashFeedbackEnabled = true
    @AppStorage("flipSwipeDirections") private var flipSwipeDirections = false
    @State private var photos: [PHAsset] = []
    @State private var currentIndex = 0
    @State private var delaycurrentIndex = 0
    @State private var currentImage: UIImage?
    @State private var swipeOffset: CGSize = .zero
    @State private var selectedForDeletion: Set<String> = []
    @State private var lastNewestID: String?
    @State private var displayedNewPhotos: Set<String> = []
    @State private var currentEmoji = "😀"
    @State private var showingPasscodePrompt = false
    @State private var isCreatingPasscode = false
    @State private var showHiddenVault = false
    @StateObject private var vaultStore = VaultStore()
    @State private var activeFlashColor: Color = .clear
    @State private var flashOpacity: Double = 0.0
    @State private var flashTask: Task<Void, Never>? = nil
    let emojis = ["😀", "😃", "😄", "😁", "😆", "😅", "😂", "🤣", "😊", "😇", "🙂", "🙃", "😉", "😌", "😍", "🥰", "😘", "😗", "😙", "😚", "😋", "😛", "😝", "😜", "🤪", "🤨", "🧐", "🤓", "😎", "🥸", "🤩", "🥳", "😏", "😒", "😞", "😔", "😟", "😕", "🙁", "☹️", "😣", "😖", "😫", "😩", "🥺", "😢", "😭", "😤", "😠", "😡", "🤬", "🤯", "😳", "🥴", "😵", "😵‍💫", "😱", "😨", "😰", "😥", "😓", "🤗", "🫣", "🫢", "🤔", "🤭", "🤫", "🤥", "😶", "😶‍🌫️", "😐", "😑", "😬", "🫠", "😴", "🤤", "😪", "😮", "😯", "😲", "😧", "😦", "😮‍💨", "🥹", "🤠", "💀", "🤐", "😷", "🤒", "🤕", "🤢", "🤮", "🤧", "🥵", "🥶", "😈", "👿", "💩", "🤡", "👹", "👺", "👻", "👽", "👾", "🤖"]
    let impact = UIImpactFeedbackGenerator(style: .heavy)
    init() {
            _currentEmoji = State(initialValue: emojis.randomElement() ?? "😀")
        }
    var body: some View {
        ZStack {
            NavigationStack {
                ZStack {
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
                            .foregroundStyle(Color.primary)
                            .padding(10)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .disabled(currentImage == nil)
                }
                VStack {
                    Text("Swipe Delete")
                        .font(.largeTitle)
                        .bold()
                        .padding()
                }
                HStack {
                    if hiddenFolderEnabled {
                        Button(action: {
                            if hapticsEnabled { impact.impactOccurred() }
                            isCreatingPasscode = !PasscodeManager.shared.hasPasscode()
                            showingPasscodePrompt = true
                        }) {
                            Image(systemName: "lock.circle")
                                .font(.system(size: 22))
                                .padding(10)
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                    } else {
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
                    }
                    Spacer()
                }
            }
            .padding(.horizontal)
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
                                        .onChanged {
                                            value in swipeOffset = CGSize(width: value.translation.width, height: 0)
                                        }
                                        .onEnded { value in handleSwipe(value: value) }
                                )
                        } else {
                            Text("No photo loaded")
                                .foregroundStyle(.secondary)
                        }
                        VStack {
                            HStack {
                                Spacer()
                                 if currentIndex < photos.count && selectedForDeletion.contains(photos[currentIndex].localIdentifier) {
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
                                .foregroundStyle(Color.primary)
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
                    Button(action: {
                        if hapticsEnabled {
                            impact.impactOccurred()
                        }
                        deleteSelectedPhotos()
                    }) {
                        Label("Delete Selected", systemImage: "trash")
                            .padding()
                            .opacity(selectedForDeletion.isEmpty ? 0.3 : 1)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(selectedForDeletion.isEmpty ? .gray : .red)
                    .disabled(selectedForDeletion.isEmpty)
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
                .navigationDestination(isPresented: $showHiddenVault) {
                    HiddenVaultView()
                        .environmentObject(vaultStore)
                }
            }
        }
        .edgesIgnoringSafeArea(.bottom)
        .overlay(
            ZStack {
                // Top Gradient (fades down)
                VStack {
                    LinearGradient(
                        colors: [activeFlashColor, activeFlashColor.opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 180)
                    .ignoresSafeArea(edges: .top)
                    Spacer()
                }
                
                // Bottom Gradient (fades up)
                VStack {
                    Spacer()
                    LinearGradient(
                        colors: [activeFlashColor.opacity(0.0), activeFlashColor],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 150)
                    .ignoresSafeArea(edges: .bottom)
                }
            }
            .opacity(flashOpacity)
            .allowsHitTesting(false)
        )
        .onAppear {
                loadPhotos()
                let center = NotificationCenter.default
                center.addObserver(forName: UIApplication.willEnterForegroundNotification,
                                   object: nil, queue: .main) { _ in
                    loadPhotos()
                }
            }
        .onChange(of: showHiddenVault) { oldValue, newValue in
            if !newValue {
                loadPhotos()
            }
        }

            if showingPasscodePrompt {
                PasscodeLockscreenView(
                    isCreating: isCreatingPasscode,
                    onSuccess: {
                        withAnimation {
                            showingPasscodePrompt = false
                        }
                        showHiddenVault = true
                    },
                    onCancel: {
                        withAnimation {
                            showingPasscodePrompt = false
                        }
                    }
                )
                .transition(.opacity)
                .zIndex(1)
            }
        }
    }
    private func handleSwipe(value: DragGesture.Value) {
        let threshold: CGFloat = 100
        let isLeft = value.translation.width < -threshold
        let isRight = value.translation.width > threshold
        let shouldDelete = flipSwipeDirections ? isRight : isLeft
        let shouldKeep = flipSwipeDirections ? isLeft : isRight

        if shouldDelete {
            triggerFlash(.red.opacity(0.35))
            guard currentIndex < photos.count else { return }
            let assetID = photos[currentIndex].localIdentifier
            if !selectedForDeletion.contains(assetID) {
                selectedForDeletion.insert(assetID)
                UserDefaults.standard.set(Array(selectedForDeletion), forKey: "selectedForDeletion")
            }
            withAnimation(.spring()) {
                swipeOffset = .zero
                markNewPhotoAsDisplayed()
                showNextPhoto()
                if hapticsEnabled {
                    impact.impactOccurred()
                }
            }
        } else if shouldKeep {
            triggerFlash(.green.opacity(0.35))
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
        delaycurrentIndex += 1
        let currentSwipes = UserDefaults.standard.integer(forKey: "totalSwipes")
        UserDefaults.standard.set(currentSwipes + 1, forKey: "totalSwipes")
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
    private func loadPhotos() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            guard status == .authorized || status == .limited else { return }
            DispatchQueue.main.async {
                let fetchOptions = PHFetchOptions()
                fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                let results = PHAsset.fetchAssets(with: .image, options: fetchOptions)
                var assets: [PHAsset] = []
                results.enumerateObjects { asset, _, _ in assets.append(asset) }
                
                let defaults = UserDefaults.standard
                let lastNewestID = defaults.string(forKey: "lastNewestPhoto")
                let lastViewedID = defaults.string(forKey: "lastViewedPhoto")
                self.displayedNewPhotos = Set(defaults.stringArray(forKey: "displayedNewPhotos") ?? [])
                self.selectedForDeletion = Set(defaults.stringArray(forKey: "selectedForDeletion") ?? [])
                
                // Clean up stale selections not present in library
                let libraryIDs = Set(assets.map { $0.localIdentifier })
                self.selectedForDeletion = self.selectedForDeletion.intersection(libraryIDs)
                defaults.set(Array(self.selectedForDeletion), forKey: "selectedForDeletion")
                
                var newPhotos: [PHAsset] = []
                if let lastNewestID = lastNewestID,
                   let lastIndex = assets.firstIndex(where: { $0.localIdentifier == lastNewestID }),
                   lastIndex > 0 {
                    newPhotos = Array(assets[0..<lastIndex])
                }
                newPhotos = newPhotos.filter { !displayedNewPhotos.contains($0.localIdentifier) }
                let oldPhotos = assets
                let combined = Array(NSOrderedSet(array: newPhotos + oldPhotos)) as! [PHAsset]
                let filtered = combined.filter { !selectedForDeletion.contains($0.localIdentifier) }
                self.photos = filtered
                
                if !newPhotos.isEmpty {
                    self.currentIndex = 0
                } else if let lastViewedID = lastViewedID,
                          let lastViewedIndex = filtered.firstIndex(where: { $0.localIdentifier == lastViewedID }) {
                    self.currentIndex = lastViewedIndex
                } else {
                    self.currentIndex = 0
                }
                self.delaycurrentIndex = self.currentIndex
                self.showPhoto()
                if let newest = assets.first {
                    defaults.set(newest.localIdentifier, forKey: "lastNewestPhoto")
                }
            }
        }
    }

    private func deleteSelectedPhotos() {
        guard !selectedForDeletion.isEmpty else { return }
        
        let currentID = currentIndex < photos.count ? photos[currentIndex].localIdentifier : ""
        let idsToDelete = selectedForDeletion.filter { $0 != currentID }
        guard !idsToDelete.isEmpty else { return }
        
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            guard status == .authorized else { return }
            
            DispatchQueue.main.async {
                let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: Array(idsToDelete), options: nil)
                var assetsToDelete: [PHAsset] = []
                fetchResult.enumerateObjects { asset, _, _ in
                    assetsToDelete.append(asset)
                }
                guard !assetsToDelete.isEmpty else { return }
                
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.deleteAssets(assetsToDelete as NSArray)
                }) { success, error in
                    DispatchQueue.main.async {
                        if success {
                            let currentAsset = currentIndex < photos.count ? photos[currentIndex] : nil
                            photos.removeAll { assetsToDelete.contains($0) }
                            selectedForDeletion.subtract(idsToDelete)
                            UserDefaults.standard.set(Array(selectedForDeletion), forKey: "selectedForDeletion")
                            
                            let currentTotal = UserDefaults.standard.integer(forKey: "totalPhotosDeleted")
                            UserDefaults.standard.set(currentTotal + assetsToDelete.count, forKey: "totalPhotosDeleted")
                            
                            if let currentAsset = currentAsset, let newIndex = photos.firstIndex(of: currentAsset) {
                                currentIndex = newIndex
                                delaycurrentIndex = newIndex
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
    }

    private func resetData() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "lastViewedPhoto")
        defaults.removeObject(forKey: "lastNewestPhoto")
        defaults.removeObject(forKey: "displayedNewPhotos")
        defaults.removeObject(forKey: "selectedForDeletion")
        photos.removeAll()
        currentImage = nil
        currentIndex = 0
        delaycurrentIndex = 0
        selectedForDeletion.removeAll()
        displayedNewPhotos.removeAll()
        lastNewestID = nil
        loadPhotos()
    }
    private func shareCurrentPhoto() {
        guard let image = currentImage else { return }
        let itemSource = ImageActivityItemSource(image: image, title: "Share Photo")
        let activityVC = UIActivityViewController(activityItems: [itemSource], applicationActivities: nil)

        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = scene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
    private func undoLastSwipe() {
        guard currentIndex > 0 else { return }
        withAnimation(.spring()) {
            currentIndex -= 1
            _ = Task {
                do {
                    try await Task.sleep(for: .seconds(0.5))
                } catch {
                }
                delaycurrentIndex -= 1
            }
            if currentIndex < photos.count {
                selectedForDeletion.remove(photos[currentIndex].localIdentifier)
                UserDefaults.standard.set(Array(selectedForDeletion), forKey: "selectedForDeletion")
            }
            showPhoto()
        }
    }
    
    private func triggerFlash(_ color: Color) {
        guard flashFeedbackEnabled else { return }
        flashTask?.cancel()
        activeFlashColor = color
        
        withAnimation(.easeOut(duration: 0.2)) {
            flashOpacity = 1.0
        }
        
        flashTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.4)) {
                    flashOpacity = 0.0
                }
            }
        }
    }
}

class ImageActivityItemSource: NSObject, UIActivityItemSource {
    let image: UIImage
    let title: String
    
    init(image: UIImage, title: String) {
        self.image = image
        self.title = title
        super.init()
    }
    
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return image
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return image
    }
    
    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = title
        metadata.imageProvider = NSItemProvider(object: image)
        metadata.iconProvider = NSItemProvider(object: image)
        return metadata
    }
}
