import SwiftUI

struct SettingsView: View {
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("hiddenFolderEnabled") private var hiddenFolderEnabled = false
    @AppStorage("flashFeedbackEnabled") private var flashFeedbackEnabled = true
    @AppStorage("flipSwipeDirections") private var flipSwipeDirections = false
    
    // Hidden toggle starts as false, revealed by pulling down (scrolling up)
    @State private var showHiddenToggle = false
    
    let impact = UIImpactFeedbackGenerator(style: .heavy)
    let resetData: () -> Void
    let skipToLastPhoto: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        Form {
            if showHiddenToggle {
                Section {
                    Toggle("Hidden Folder", isOn: $hiddenFolderEnabled)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            Section {
                Toggle("Haptic Feedback", isOn: $hapticsEnabled)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 3) {
                        // Failsafe triple-tap easter egg to reveal
                        revealToggle()
                    }
                
                Toggle("Swipe Flash Feedback", isOn: $flashFeedbackEnabled)
                
                Toggle("Flip Swipe Directions", isOn: $flipSwipeDirections)
            }
            
            Section(header: Text("Debug")) {
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
                
                Button {
                    skipToLastPhoto()
                    dismiss()
                    impact.impactOccurred()
                } label: {
                    HStack {
                        Label("Skip to Last Photo", systemImage: "arrow.left")
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
