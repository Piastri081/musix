import SwiftUI

struct PlansView: View {
    @EnvironmentObject private var session: Session
    @Environment(\.dismiss) private var dismiss

    @State private var plans: [Plan] = PlansView.fallbackPlans
    @State private var code = ""
    @State private var isRedeeming = false
    @State private var notice: Notice?

    @FocusState private var codeFocused: Bool

    private struct Notice {
        let text: String
        let isError: Bool
    }

    private var user: AppUser { session.user ?? .preview }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    sheetHeader
                    inviteBanner

                    ForEach(plans) { plan in
                        planCard(plan, isCurrent: plan.id == user.planId)
                    }

                    redeemCard
                    if user.planId == "family" || user.planId == "duo" {
                        familyCard
                    }
                    finePrint
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 30)
            }
        }
        .presentationDetents([.large])
        .presentationBackground(Theme.background)
        .task { await loadPlans() }
    }

    // MARK: - Header

    private var sheetHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Plans")
                    .font(Theme.display(28))
                    .tracking(-1)
                    .foregroundStyle(Theme.textPrimary)
                Text("Built for one, two, or six.")
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Theme.surface))
            }
            .buttonStyle(.plain)
        }
    }

    private var inviteBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "ticket.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.lime)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Theme.lime.opacity(0.12)))

            VStack(alignment: .leading, spacing: 4) {
                Text("Invite only while we scale")
                    .font(Theme.title(14))
                    .foregroundStyle(Theme.textPrimary)
                Text("Pricing is shared with your invite. A promo code unlocks your first months and locks the rate.")
                    .font(Theme.body(12))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.lime.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Plan card

    private func planCard(_ plan: Plan, isCurrent: Bool) -> some View {
        let tint = color(for: plan.accent)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.name)
                        .font(Theme.display(24))
                        .tracking(-0.8)
                        .foregroundStyle(Theme.textPrimary)
                    Text(plan.tagline)
                        .font(Theme.body(12))
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer()

                if isCurrent {
                    Text("CURRENT")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(tint))
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(plan.priceLabel)
                    .font(Theme.title(18))
                    .foregroundStyle(tint)

                Text("· \(plan.seats) \(plan.seats == 1 ? "seat" : "seats")")
                    .font(Theme.body(13))
                    .foregroundStyle(Theme.textSecondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(plan.features, id: \.self) { feature in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(tint)
                        Text(feature)
                            .font(Theme.body(13))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }

            Button {
                codeFocused = true
            } label: {
                Text(isCurrent ? "Activated" : "Have a code? Activate \(plan.name)")
                    .font(Theme.title(14))
                    .foregroundStyle(isCurrent ? Theme.textTertiary : Color.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(isCurrent ? AnyShapeStyle(Theme.surfaceRaised) : AnyShapeStyle(tint))
                    )
            }
            .buttonStyle(PressableStyle())
            .disabled(isCurrent)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(isCurrent ? tint.opacity(0.6) : Theme.stroke, lineWidth: isCurrent ? 1.5 : 1)
        )
    }

    // MARK: - Redeem

    private var redeemCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ACCESS OR PROMO CODE")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(Theme.textSecondary)

            HStack(spacing: 10) {
                TextField("", text: $code, prompt: Text("MUSIX-DUO-2026").foregroundColor(Theme.textTertiary))
                    .font(Theme.mono(15))
                    .foregroundStyle(Theme.textPrimary)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .focused($codeFocused)
                    .submitLabel(.done)
                    .onSubmit(redeem)
                    .padding(.horizontal, 14)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.background)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(codeFocused ? Theme.lime.opacity(0.5) : Theme.stroke, lineWidth: 1)
                    )

                Button(action: redeem) {
                    if isRedeeming {
                        ProgressView().tint(.black)
                            .frame(width: 54, height: 50)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.lime))
                    } else {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color.black)
                            .frame(width: 54, height: 50)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.lime))
                    }
                }
                .buttonStyle(PressableStyle())
                .disabled(isRedeeming)
            }

            if let notice {
                HStack(spacing: 6) {
                    Image(systemName: notice.isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                    Text(notice.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(Theme.body(12))
                .foregroundStyle(notice.isError ? Theme.pink : Theme.lime)
            }

            Text("Codes are single use and bind to your email.")
                .font(Theme.body(11))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1)
        )
    }

    // MARK: - Family

    private var familyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your household")
                    .font(Theme.title(16))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(user.seatsUsed)/\(user.seats)")
                    .font(Theme.mono(12))
                    .foregroundStyle(Theme.textSecondary)
            }

            Text("Everyone on your plan gets their own login, their own wrap and their own library. Add people by email.")
                .font(Theme.body(12))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                ForEach(0..<user.seats, id: \.self) { index in
                    ZStack {
                        Circle()
                            .fill(index < user.seatsUsed ? Theme.surfaceRaised : Theme.background)
                            .frame(width: 34, height: 34)

                        Image(systemName: index < user.seatsUsed ? "person.fill" : "plus")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(index < user.seatsUsed ? Theme.lime : Theme.textTertiary)
                    }
                    .overlay(Circle().strokeBorder(Theme.stroke, lineWidth: 1))
                }
                Spacer()
            }

            SecondaryButton(title: "Invite by email", systemImage: "envelope") {
                notice = Notice(text: "Invites open in the next update. Use a code for now.", isError: false)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.stroke, lineWidth: 1)
        )
    }

    private var finePrint: some View {
        Text("Plans renew per billing period. Cancel anytime in account settings. Pricing is set per invite and is not published in-app.")
            .font(Theme.body(11))
            .foregroundStyle(Theme.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Actions

    private func redeem() {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isRedeeming else { return }

        isRedeeming = true
        notice = nil
        hideKeyboard()

        Task { @MainActor in
            defer { isRedeeming = false }
            do {
                try await session.redeem(code: trimmed)
                notice = Notice(text: "You're on \(session.user?.planName ?? "a new plan"). Welcome in.", isError: false)
                code = ""
            } catch {
                notice = Notice(text: (error as? APIError)?.message ?? "That code didn't work.", isError: true)
            }
        }
    }

    @MainActor
    private func loadPlans() async {
        do {
            let response: PlansResponse = try await APIClient.shared.get("/v1/plans")
            if !response.plans.isEmpty { plans = response.plans }
        } catch {
            // Fallback list keeps the screen useful offline.
        }
    }

    private func color(for accent: String) -> Color {
        switch accent {
        case "violet": return Theme.violet
        case "pink": return Theme.pink
        case "cyan": return Theme.cyan
        default: return Theme.lime
        }
    }

    // MARK: - Fallback catalogue of plans

    static let fallbackPlans: [Plan] = [
        Plan(id: "solo",
             name: "Solo",
             seats: 1,
             priceLabel: "Invite only",
             invitesOnly: true,
             tagline: "Just you, no interruptions.",
             features: ["1 account", "Lossless audio", "Daily Wraps", "No ads, ever"],
             accent: "pink"),
        Plan(id: "duo",
             name: "Duo",
             seats: 2,
             priceLabel: "Invite only",
             invitesOnly: true,
             tagline: "Two accounts, one code.",
             features: ["2 accounts", "Lossless audio", "Daily Wraps", "Shared playlists"],
             accent: "lime"),
        Plan(id: "family",
             name: "Family",
             seats: 6,
             priceLabel: "Invite only",
             invitesOnly: true,
             tagline: "Six seats, one bill.",
             features: ["6 accounts", "Lossless audio", "Daily Wraps", "Shared library", "Separate logins"],
             accent: "violet")
    ]
}
