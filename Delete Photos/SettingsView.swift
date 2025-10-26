import SwiftUI

struct SettingsView: View {
    let resetData: () -> Void
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
                        .foregroundStyle(Color.black)
                }
                Text("Resetting will put all photos back that haven't been deleted.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
