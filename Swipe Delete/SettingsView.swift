import SwiftUI

struct SettingsView: View {
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("hiddenFolderEnabled") private var hiddenFolderEnabled = false
    @AppStorage("flashFeedbackEnabled") private var flashFeedbackEnabled = true
    @AppStorage("flipSwipeDirections") private var flipSwipeDirections = false
    @AppStorage("lockOrientationVertical") private var lockOrientationVertical = false

    @AppStorage("totalPhotosDeleted") private var totalPhotosDeleted = 0

    @AppStorage("totalSwipes") private var totalSwipes = 0


    @State private var showHiddenToggle = false

    let impact = UIImpactFeedbackGenerator(style: .heavy)
    let resetData: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            if showHiddenToggle {
                Section {
                    Toggle("Hidden Folder", isOn: $hiddenFolderEnabled)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            Section(header: Text("Statistics")) {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TOTAL DELETED")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(totalPhotosDeleted)")
                            .font(.title2)
                            .bold()
                            .foregroundColor(.red)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider()

                    VStack(alignment: .leading, spacing: 4) {
                        Text("TOTAL SWIPES")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("\(totalSwipes)")
                            .font(.title2)
                            .bold()
                            .foregroundColor(.green)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 4)
            }

            Section {
                Toggle("Haptic Feedback", isOn: $hapticsEnabled)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 3) {

                        revealToggle()
                    }

                Toggle("Swipe Flash Feedback", isOn: $flashFeedbackEnabled)

                Toggle("Flip Swipe Directions", isOn: $flipSwipeDirections)

                Toggle("Lock Vertical Orientation", isOn: $lockOrientationVertical)
            }

            Section {
                Button(role: .destructive) {
                    resetData()
                    dismiss()
                    impact.impactOccurred()
                } label: {
                    HStack {
                        Label("Reset Swipes", systemImage: "arrow.clockwise")
                            .foregroundColor(.red)
                        Spacer()
                    }
                }
            }
        }
        .refreshable {
            revealToggle()
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: lockOrientationVertical) { oldValue, newValue in
            updateOrientation(lock: newValue)
        }
    }

    private func updateOrientation(lock: Bool) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        
        let orientations: UIInterfaceOrientationMask = lock ? .portrait : .all
        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: orientations)) { error in
            print("Geometry update failed: \(error.localizedDescription)")
        }
        
        if let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
            rootVC.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }

    private func revealToggle() {
        if !showHiddenToggle {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            withAnimation(.spring()) {
                showHiddenToggle = true
            }
        }
    }
}
