import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var session: Session

    private enum Step { case email, code }

    @State private var step: Step = .email
    @State private var email = ""
    @State private var code = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var devCode: String?
    @State private var resendCountdown = 0

    @FocusState private var emailFocused: Bool
    @FocusState private var codeFocused: Bool

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            RadialGradient(colors: [Theme.violet.opacity(0.22), Color.clear],
                           center: .topTrailing,
                           startRadius: 0,
                           endRadius: 480)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                brandHeader
                    .padding(.top, 28)

                Spacer(minLength: 24)

                if step == .email {
                    emailStep
                        .transition(.asymmetric(insertion: .opacity, removal: .opacity))
                } else {
                    codeStep
                        .transition(.asymmetric(insertion: .opacity, removal: .opacity))
                }

                Spacer(minLength: 20)

                footnote
            }
            .pageGutter()
            .padding(.bottom, 12)
        }
        .animation(.easeInOut(duration: 0.25), value: step)
        .onChange(of: code) { _, newValue in
            handleCodeChange(newValue)
        }
    }

    // MARK: - Header

    private var brandHeader: some View {
        HStack(spacing: 10) {
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { index in
                    Capsule()
                        .fill(index == 2 ? Theme.lime : Theme.textPrimary)
                        .frame(width: 4, height: [10, 18, 24, 14, 8][index])
                }
            }
            .frame(height: 26)

            Text("musix")
                .font(Theme.display(22))
                .tracking(-0.8)
                .foregroundStyle(Theme.textPrimary)

            Spacer()
        }
    }

    // MARK: - Step 1: email

    private var emailStep: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Music,\nminus the noise.")
                    .font(Theme.display(40))
                    .tracking(-1.6)
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Ad-free streaming, daily wraps, and plans built for two or six. Invite only while we scale.")
                    .font(Theme.body(15))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            MusixField(title: "Email",
                       placeholder: "you@example.com",
                       text: $email,
                       keyboard: .emailAddress,
                       contentType: .emailAddress,
                       focus: $emailFocused)
                .submitLabel(.continue)
                .onSubmit(sendCode)

            if let errorMessage {
                ErrorBanner(message: errorMessage)
            }

            PrimaryButton(title: "Email me a code",
                          systemImage: "paperplane.fill",
                          isLoading: isLoading,
                          action: sendCode)

            featureRow

            if Config.allowDemoMode {
                Button {
                    hideKeyboard()
                    session.enterDemoMode(email: email.isEmpty ? "demo@musix.app" : email)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                        Text("Explore in demo mode")
                    }
                    .font(Theme.title(14))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var featureRow: some View {
        HStack(spacing: 8) {
            FeaturePill(icon: "hand.raised.fill", text: "No ads")
            FeaturePill(icon: "chart.bar.fill", text: "Daily Wrap")
            FeaturePill(icon: "person.2.fill", text: "Up to 6")
        }
    }

    // MARK: - Step 2: code

    private var codeStep: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Check your inbox")
                    .font(Theme.display(34))
                    .tracking(-1.2)
                    .foregroundStyle(Theme.textPrimary)

                Text("We sent a 6-digit code to \(email).")
                    .font(Theme.body(15))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let devCode {
                    Text("Dev code: \(devCode)")
                        .font(Theme.mono(13))
                        .foregroundStyle(Theme.lime)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Theme.lime.opacity(0.12)))
                }
            }

            codeBoxes

            if let errorMessage {
                ErrorBanner(message: errorMessage)
            }

            PrimaryButton(title: "Verify and continue",
                          systemImage: "checkmark",
                          isLoading: isLoading,
                          action: verifyCode)

            HStack(spacing: 16) {
                Button {
                    step = .email
                    code = ""
                    errorMessage = nil
                } label: {
                    Text("Change email")
                        .font(Theme.title(14))
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer()

                Button {
                    resend()
                } label: {
                    Text(resendCountdown > 0 ? "Resend in \(resendCountdown)s" : "Resend code")
                        .font(Theme.title(14))
                        .foregroundStyle(resendCountdown > 0 ? Theme.textTertiary : Theme.lime)
                }
                .disabled(resendCountdown > 0)
            }
            .buttonStyle(.plain)
        }
        .onAppear {
            codeFocused = true
        }
    }

    private var codeBoxes: some View {
        ZStack {
            HStack(spacing: 9) {
                ForEach(0..<6, id: \.self) { index in
                    let characters = Array(code)
                    let digit = index < characters.count ? String(characters[index]) : ""
                    let isNext = index == characters.count

                    Text(digit)
                        .font(Theme.mono(26))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 62)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Theme.surface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(isNext ? Theme.lime.opacity(0.8) : Theme.stroke,
                                              lineWidth: isNext ? 1.5 : 1)
                        )
                }
            }

            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($codeFocused)
                .opacity(0.001)
                .frame(height: 62)
        }
        .contentShape(Rectangle())
        .onTapGesture { codeFocused = true }
    }

    // MARK: - Footer

    private var footnote: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Config.inviteOnlyNotice)
                .font(Theme.body(12))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)

            Text("No ads. No trackers. Cancel anytime.")
                .font(Theme.body(12))
                .foregroundStyle(Theme.textTertiary)
        }
    }

    // MARK: - Actions

    private func sendCode() {
        let cleaned = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard cleaned.contains("@"), cleaned.contains(".") else {
            errorMessage = "Enter a valid email address."
            return
        }

        email = cleaned
        errorMessage = nil
        isLoading = true
        hideKeyboard()

        Task { @MainActor in
            defer { isLoading = false }
            do {
                devCode = try await session.requestCode(email: cleaned)
                step = .code
                startCountdown()
            } catch {
                errorMessage = (error as? APIError)?.message ?? error.localizedDescription
            }
        }
    }

    private func verifyCode() {
        guard code.count == 6, !isLoading else { return }
        errorMessage = nil
        isLoading = true
        hideKeyboard()

        Task { @MainActor in
            defer { isLoading = false }
            do {
                try await session.verify(email: email, code: code)
            } catch {
                errorMessage = (error as? APIError)?.message ?? error.localizedDescription
                code = ""
                codeFocused = true
            }
        }
    }

    private func handleCodeChange(_ newValue: String) {
        let digits = String(newValue.filter { $0.isNumber }.prefix(6))
        if digits != newValue { code = digits }
        errorMessage = nil

        if digits.count == 6 {
            codeFocused = false
            verifyCode()
        }
    }

    private func resend() {
        guard resendCountdown == 0 else { return }
        isLoading = true
        Task { @MainActor in
            defer { isLoading = false }
            do {
                devCode = try await session.requestCode(email: email)
                startCountdown()
            } catch {
                errorMessage = (error as? APIError)?.message ?? error.localizedDescription
            }
        }
    }

    private func startCountdown() {
        resendCountdown = 30
        Task { @MainActor in
            while resendCountdown > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                resendCountdown -= 1
            }
        }
    }
}

// MARK: - Small pieces

private struct FeaturePill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(Theme.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Capsule().fill(Theme.surface))
        .overlay(Capsule().strokeBorder(Theme.stroke, lineWidth: 1))
    }
}

struct ErrorBanner: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .semibold))
            Text(message)
                .font(Theme.body(13))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Theme.pink)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.pink.opacity(0.10))
        )
    }
}
