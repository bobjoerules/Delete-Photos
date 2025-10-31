import SwiftUI
struct SettingsView: View {
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    let impact = UIImpactFeedbackGenerator(style: .heavy)
    let resetData: () -> Void
    let skipToLastPhoto: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Haptic Feedback", isOn: $hapticsEnabled)
                    Button {
                        resetData()
                        dismiss()
                        impact.impactOccurred()
                    } label: {
                        Label("Reset Swipes", systemImage: "arrow.clockwise")
                    }
                    .foregroundColor(.red)
                    
                    Button {
                        skipToLastPhoto()
                        impact.impactOccurred()
                    } label: {
                        Label("Skip to Last Photo", systemImage: "arrow.left")
                    }
                }
            }
            .navigationTitle("Settings / Tools")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
