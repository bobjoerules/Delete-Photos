import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Settings go here.")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
            .navigationTitle("Settings")
        }
    }
}
