import SwiftUI

struct SettingsView: View {
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("hiddenFolderEnabled") private var hiddenFolderEnabled = false
    @AppStorage("flashFeedbackEnabled") private var flashFeedbackEnabled = true
    @AppStorage("flipSwipeDirections") private var flipSwipeDirections = false
    
    @AppStorage("totalPhotosDeleted") private var totalPhotosDeleted = 0
    
    @AppStorage("totalSwipes") private var totalSwipes = 0
    
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
                        Text("SWIPES")
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
