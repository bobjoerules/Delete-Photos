import SwiftUI

struct PasscodeLockscreenView: View {
    let isCreating: Bool
    let onSuccess: () -> Void
    let onCancel: () -> Void
    
    @State private var input: String = ""
    @State private var errorText: String? = nil
    @State private var shakeOffset: CGFloat = 0
    
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    private let impact = UIImpactFeedbackGenerator(style: .medium)
    private let feedbackGenerator = UINotificationFeedbackGenerator()
    
    var body: some View {
        ZStack {
            // Dark glassmorphic background overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            
            VStack {
                Spacer()
                
                VStack(spacing: 40) {
                    // Header Title
                    VStack(spacing: 12) {
                        Text(isCreating ? "Create Passcode" : "Enter Passcode")
                            .font(.title2)
                            .bold()
                            .foregroundStyle(.primary)
                        
                        if let errorText = errorText {
                            Text(errorText)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .transition(.opacity)
                        }
                    }
                    
                    // Passcode Dot Indicators
                    HStack(spacing: 24) {
                        ForEach(0..<4) { index in
                            Circle()
                                .stroke(Color.primary.opacity(0.5), lineWidth: 2)
                                .background(
                                    Circle()
                                        .fill(index < input.count ? Color.primary : Color.clear)
                                )
                                .frame(width: 16, height: 16)
                                .scaleEffect(index < input.count ? 1.2 : 1.0)
                                .animation(.spring(response: 0.2, dampingFraction: 0.5), value: input.count)
                        }
                    }
                    .offset(x: shakeOffset)
                    
                    // Keypad Grid
                    VStack(spacing: 18) {
                        ForEach(0..<3) { row in
                            HStack(spacing: 24) {
                                ForEach(1..<4) { col in
                                    let num = row * 3 + col
                                    keypadButton(text: "\(num)") {
                                        appendDigit("\(num)")
                                    }
                                }
                            }
                        }
                        
                        HStack(spacing: 24) {
                            // Cancel Button
                            Button(action: {
                                playHaptic()
                                onCancel()
                            }) {
                                Text("Cancel")
                                    .font(.body)
                                    .bold()
                                    .frame(width: 75, height: 75)
                                    .foregroundStyle(.primary)
                            }
                            
                            // 0 Button
                            keypadButton(text: "0") {
                                appendDigit("0")
                            }
                            
                            // Delete Button
                            Button(action: {
                                playHaptic()
                                deleteDigit()
                            }) {
                                Image(systemName: "delete.left")
                                    .font(.title2)
                                    .frame(width: 75, height: 75)
                                    .foregroundStyle(.primary)
                            }
                            .disabled(input.isEmpty)
                            .opacity(input.isEmpty ? 0.3 : 1.0)
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
            }
            .padding()
        }
    }
    
    // Keypad circular button view helper
    @ViewBuilder
    private func keypadButton(text: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            playHaptic()
            action()
        }) {
            Text(text)
                .font(.title)
                .frame(width: 75, height: 75)
                .background(Color.primary.opacity(0.15))
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                )
                .foregroundStyle(.primary)
        }
    }
    
    // Helper to append digit and trigger auto-submit
    private func appendDigit(_ digit: String) {
        guard input.count < 4 else { return }
        input.append(digit)
        
        if input.count == 4 {
            // Add a very slight delay so the user sees the 4th dot fill up before validation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                validate()
            }
        }
    }
    
    // Helper to delete digit
    private func deleteDigit() {
        if !input.isEmpty {
            input.removeLast()
        }
    }
    
    // Validation logic
    private func validate() {
        if isCreating {
            do {
                try PasscodeManager.shared.setPasscode(input)
                errorText = nil
                feedbackGenerator.notificationOccurred(.success)
                onSuccess()
            } catch {
                errorText = "Error saving passcode."
                feedbackGenerator.notificationOccurred(.error)
                shake()
                input = ""
            }
        } else {
            if PasscodeManager.shared.validatePasscode(input) {
                errorText = nil
                feedbackGenerator.notificationOccurred(.success)
                onSuccess()
            } else {
                errorText = "Incorrect passcode."
                feedbackGenerator.notificationOccurred(.error)
                shake()
                input = ""
            }
        }
    }
    
    // Shake animation
    private func shake() {
        withAnimation(.default) {
            shakeOffset = 15
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.default) {
                shakeOffset = -15
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.default) {
                shakeOffset = 15
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.default) {
                shakeOffset = 0
            }
        }
    }
    
    // Haptics helper
    private func playHaptic() {
        if hapticsEnabled {
            impact.impactOccurred()
        }
    }
}

#Preview {
    PasscodeLockscreenView(isCreating: false, onSuccess: {}, onCancel: {})
}
