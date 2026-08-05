import SwiftUI

struct PasscodeLockscreenView: View {
    let isCreating: Bool
    let onSuccess: () -> Void
    let onCancel: () -> Void

    @State private var input: String = ""
    @State private var errorText: String? = nil
    @State private var shakeOffset: CGFloat = 0
    @State private var isFlashRed = false

    @Environment(\.verticalSizeClass) var verticalSizeClass
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    private let impact = UIImpactFeedbackGenerator(style: .medium)
    private let feedbackGenerator = UINotificationFeedbackGenerator()

    var body: some View {
        ZStack {
            VStack {
                Spacer()

                if verticalSizeClass == .compact {

                    HStack(spacing: 50) {
                        VStack(spacing: 24) {

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


                            HStack(spacing: 24) {
                                ForEach(0..<4) { index in
                                    Circle()
                                        .stroke(isFlashRed ? Color.red : Color.primary.opacity(0.5), lineWidth: 2)
                                        .background(
                                            Circle()
                                                .fill(index < input.count ? (isFlashRed ? Color.red : Color.primary) : Color.clear)
                                        )
                                        .frame(width: 16, height: 16)
                                        .scaleEffect(index < input.count ? 1.2 : 1.0)
                                        .animation(.spring(response: 0.2, dampingFraction: 0.5), value: input.count)
                                }
                            }
                            .offset(x: shakeOffset)
                        }


                        keypadGrid
                    }
                } else {

                    VStack(spacing: 40) {

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


                        HStack(spacing: 24) {
                            ForEach(0..<4) { index in
                                Circle()
                                    .stroke(isFlashRed ? Color.red : Color.primary.opacity(0.5), lineWidth: 2)
                                    .background(
                                        Circle()
                                            .fill(index < input.count ? (isFlashRed ? Color.red : Color.primary) : Color.clear)
                                    )
                                    .frame(width: 16, height: 16)
                                    .scaleEffect(index < input.count ? 1.2 : 1.0)
                                    .animation(.spring(response: 0.2, dampingFraction: 0.5), value: input.count)
                            }
                        }
                        .offset(x: shakeOffset)


                        keypadGrid
                    }
                }

                Spacer()
            }
            .padding()
        }
    }


    private var keypadGrid: some View {
        VStack(spacing: 18) {
            let subtexts = ["", "A B C", "D E F", "G H I", "J K L", "M N O", "P Q R S", "T U V", "W X Y Z"]
            ForEach(0..<3) { row in
                HStack(spacing: 24) {
                    ForEach(1..<4) { col in
                        let num = row * 3 + col
                        keypadButton(text: "\(num)", subtext: subtexts[num - 1]) {
                            appendDigit("\(num)")
                        }
                    }
                }
            }

            HStack(spacing: 24) {

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


                keypadButton(text: "0") {
                    appendDigit("0")
                }


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


    @ViewBuilder
    private func keypadButton(text: String, subtext: String = "", action: @escaping () -> Void) -> some View {
        Button(action: {
            playHaptic()
            action()
        }) {
            VStack(spacing: 0) {
                Text(text)
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(.primary)
                if !subtext.isEmpty {
                    Text(subtext)
                        .font(.system(size: 9, weight: .semibold))
                        .kerning(1)
                        .foregroundStyle(.primary.opacity(0.6))
                }
            }
            .frame(width: 75, height: 75)
            .glassEffect(.regular.interactive(), in: Circle())
        }
    }


    private func appendDigit(_ digit: String) {
        guard input.count < 4 else { return }
        input.append(digit)

        if input.count == 4 {

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                validate()
            }
        }
    }


    private func deleteDigit() {
        if !input.isEmpty {
            input.removeLast()
        }
    }


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
                feedbackGenerator.notificationOccurred(.error)
                withAnimation(.easeInOut(duration: 0.15)) {
                    isFlashRed = true
                }
                shake()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isFlashRed = false
                        input = ""
                    }
                }
            }
        }
    }


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


    private func playHaptic() {
        if hapticsEnabled {
            impact.impactOccurred()
        }
    }
}

#Preview {
    PasscodeLockscreenView(isCreating: false, onSuccess: {}, onCancel: {})
}
