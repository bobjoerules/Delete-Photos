import SwiftUI

struct SettingsView: View {
    let resetData: () -> Void
    let skipToLastPhoto: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Button(action: {
                    resetData()
                    dismiss()
                }) {
                    Label("Reset", systemImage: "arrow.clockwise")
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.red)
                        )
                        .foregroundStyle(Color(.systemBackground))
                }
                Text("Resetting will put all photos back that haven't been deleted.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button(action: {
                    skipToLastPhoto()
                }) {
                    Label("Skip", systemImage: "arrow.left")
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.primary)
                        )
                        .foregroundStyle(Color(.systemBackground))
                }
                Text("Skip to the last photo and wait for new photos (use this if you accidently clicked reset.)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
            .navigationTitle("Settings/Tools")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
