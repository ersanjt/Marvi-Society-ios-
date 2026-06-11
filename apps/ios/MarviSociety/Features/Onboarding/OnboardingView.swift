import SwiftUI

// MARK: - Steps

private enum OnboardingStep: Int, CaseIterable {
    case welcome
    case signIn
    case invite
    case profile
    case agreement

    var title: String {
        switch self {
        case .welcome: "Welcome"
        case .signIn: "Sign in"
        case .invite: "Invite"
        case .profile: "Profile"
        case .agreement: "Agreement"
        }
    }

    var ctaTitle: String {
        switch self {
        case .welcome: "Get started"
        case .signIn: "Sign in"
        case .invite: "Continue"
        case .profile: "Continue"
        case .agreement: "Join Marvi Society"
        }
    }
}

// MARK: - Root

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var appleSignIn = AppleSignInService()

    @State private var step: OnboardingStep = .welcome
    @State private var instagramHandle = ""
    @State private var city = "Istanbul"
    @State private var inviteCode = ""
    @State private var referralError = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isSigningInWithEmail = false
    @State private var isValidatingReferral = false
    @State private var confirmedAge18 = false
    @State private var acceptedTerms = false
    @State private var appleSignInError: String?
    @State private var inviteValidated = false

    var body: some View {
        ZStack {
            OnboardingBackdrop()

            VStack(spacing: 0) {
                OnboardingTopBar(
                    step: step,
                    onBack: goBack
                )

                Group {
                    switch step {
                    case .welcome: welcomeStep
                    case .signIn: signInStep
                    case .invite: inviteStep
                    case .profile: profileStep
                    case .agreement: agreementStep
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(.easeInOut(duration: 0.32), value: step)

                OnboardingBottomBar(
                    ctaTitle: primaryCTATitle,
                    isBusy: isBusy,
                    isPrimaryDisabled: !canAdvancePrimary,
                    errorMessage: displayedError,
                    onPrimary: { Task { await handlePrimaryAction() } }
                )
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { applyResumeState() }
        .overlay { busyOverlay }
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 12)

            BrandMark(size: 72)
                .padding(.bottom, 28)

            VStack(alignment: .leading, spacing: 12) {
                Text("Do what you can't")
                    .font(.system(size: 42, weight: .bold, design: .serif))
                    .foregroundStyle(MarviColor.ink)
                    .minimumScaleFactor(0.85)
                    .lineLimit(2)

                Text("with Marvi Society")
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundStyle(MarviGradient.brand)

                Text("Istanbul's invite-only club for creators and venues. Curated events, structured proof, trusted matching.")
                    .font(.subheadline)
                    .foregroundStyle(MarviColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }

            Spacer(minLength: 28)

            HStack(spacing: 10) {
                OnboardingPill(icon: "calendar", title: "When")
                OnboardingPill(icon: "mappin.and.ellipse", title: "Where")
                OnboardingPill(icon: "sparkles", title: "Event type")
            }

            VStack(spacing: 12) {
                OnboardingFeatureRow(
                    icon: "checkmark.seal.fill",
                    title: "Approved members only",
                    subtitle: "Every creator application is reviewed by our team."
                )
                OnboardingFeatureRow(
                    icon: "building.2.fill",
                    title: "Premium venue experiences",
                    subtitle: "Dining, nightlife, wellness, and more."
                )
                OnboardingFeatureRow(
                    icon: "camera.fill",
                    title: "Proof that protects venues",
                    subtitle: "Submit content links after each collaboration."
                )
            }
            .padding(.top, 22)

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 24)
    }

    private var signInStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                OnboardingStepHeader(
                    eyebrow: "Step 1 of 4",
                    title: "Sign in to continue",
                    subtitle: "Use your Marvi Society account. Profile details come next."
                )

                Button {
                    Task { await signInWithAppleFlow() }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "apple.logo")
                            .font(.title3.weight(.semibold))
                        Text(appleSignIn.isSigningIn ? "Signing in…" : "Sign in with Apple")
                            .font(.headline.weight(.bold))
                    }
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(appleSignIn.isSigningIn || isBusy)

                HStack(spacing: 12) {
                    Rectangle().fill(MarviColor.border).frame(height: 1)
                    Text("or email")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MarviColor.muted)
                    Rectangle().fill(MarviColor.border).frame(height: 1)
                }

                VStack(spacing: 12) {
                    MarviTextField(placeholder: "Email", text: $email, autocapitalization: .never)
                    OnboardingSecureField(placeholder: "Password", text: $password)
                }

                Text("Apple Sign-In works on TestFlight builds. For device testing, use email.")
                    .font(.caption2)
                    .foregroundStyle(MarviColor.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    private var inviteStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                OnboardingStepHeader(
                    eyebrow: "Step 2 of 4",
                    title: "Enter your invite code",
                    subtitle: "Marvi Society is invite-only. Ask your curator or venue partner for a code."
                )

                MarviTextField(
                    placeholder: "e.g. MARVI-IST",
                    text: $inviteCode,
                    autocapitalization: .characters
                )

                if inviteValidated {
                    Label("Invite code accepted", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MarviColor.emerald)
                }

                if !referralError.isEmpty {
                    Label(referralError, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MarviColor.tomato)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Member benefits")
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(MarviColor.muted)

                    OnboardingFeatureRow(
                        icon: "star.fill",
                        title: "Curated invitations",
                        subtitle: "Access live campaigns matched to your niche."
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    private var profileStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                OnboardingStepHeader(
                    eyebrow: "Step 3 of 4",
                    title: "Your creator profile",
                    subtitle: "Used for verification and invitation matching."
                )

                MarviTextField(
                    placeholder: "Instagram handle",
                    text: $instagramHandle,
                    autocapitalization: .never
                )

                MarviTextField(placeholder: "City", text: $city)

                Text("Popular cities")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(MarviColor.muted)

                HStack(spacing: 10) {
                    ForEach(["Istanbul", "Dubai", "London"], id: \.self) { option in
                        Button {
                            city = option
                        } label: {
                            Text(option)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(city == option ? .white : MarviColor.ink)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(
                                    city == option
                                        ? AnyShapeStyle(MarviGradient.brand)
                                        : AnyShapeStyle(MarviColor.panel)
                                )
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(MarviColor.border, lineWidth: city == option ? 0 : 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    private var agreementStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                OnboardingStepHeader(
                    eyebrow: "Step 4 of 4",
                    title: "Membership agreement",
                    subtitle: "Required before entering the club."
                )

                MarviCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Toggle(isOn: $confirmedAge18) {
                            Text("I am 18 years of age or older.")
                                .font(.subheadline)
                                .foregroundStyle(MarviColor.ink)
                        }
                        .tint(MarviColor.rose)

                        Toggle(isOn: $acceptedTerms) {
                            Text("I agree to the Terms of Service, Privacy Policy, and Community Guidelines.")
                                .font(.subheadline)
                                .foregroundStyle(MarviColor.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .tint(MarviColor.rose)

                        VStack(alignment: .leading, spacing: 8) {
                            Link("Privacy Policy", destination: AppLinks.privacyPolicy)
                            Link("Terms of Service", destination: AppLinks.termsOfService)
                            Link("Community Guidelines", destination: AppLinks.communityGuidelines)
                        }
                        .font(.caption.weight(.semibold))
                    }
                }

                Text("Venue and admin workspaces unlock automatically based on your account role.")
                    .font(.caption)
                    .foregroundStyle(MarviColor.muted)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }

    // MARK: - State

    private var isBusy: Bool {
        isSigningInWithEmail || appleSignIn.isSigningIn || isValidatingReferral || appState.isBootstrapping
    }

    private var displayedError: String? {
        if let appleSignInError { return appleSignInError }
        if let error = appState.lastSyncError { return error }
        return nil
    }

    private var primaryCTATitle: String {
        if step == .signIn, appState.isAuthenticated { return "Continue" }
        return step.ctaTitle
    }

    private var canAdvancePrimary: Bool {
        switch step {
        case .welcome:
            return true
        case .signIn:
            if appState.isAuthenticated { return !isBusy }
            return canSignInWithEmail && !isBusy
        case .invite:
            guard appState.isAuthenticated else { return false }
            return !inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isBusy
        case .profile:
            return isProfileValid && !isBusy
        case .agreement:
            return confirmedAge18 && acceptedTerms && !isBusy
        }
    }

    private var canSignInWithEmail: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty
    }

    private var isProfileValid: Bool {
        !instagramHandle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Actions

    private func applyResumeState() {
        guard appState.isAuthenticated else { return }
        instagramHandle = appState.profile.handle
        if !appState.profile.city.isEmpty {
            city = appState.profile.city
        }
        withAnimation { step = .invite }
    }

    private func goBack() {
        guard let previous = OnboardingStep(rawValue: step.rawValue - 1) else { return }
        referralError = ""
        appleSignInError = nil
        appState.dismissSyncError()
        withAnimation { step = previous }
    }

    private func advance(to next: OnboardingStep) {
        referralError = ""
        appleSignInError = nil
        appState.dismissSyncError()
        withAnimation { step = next }
    }

    private func handlePrimaryAction() async {
        switch step {
        case .welcome:
            advance(to: .signIn)
        case .signIn:
            if appState.isAuthenticated {
                advance(to: .invite)
            } else {
                await signInWithEmailFlow()
            }
        case .invite:
            guard appState.isAuthenticated else {
                advance(to: .signIn)
                return
            }
            guard await validateInviteCode() else { return }
            inviteValidated = true
            advance(to: .profile)
        case .profile:
            appState.profile.handle = instagramHandle
            appState.profile.city = city
            advance(to: .agreement)
        case .agreement:
            await finishOnboarding()
        }
    }

    private func signInWithEmailFlow() async {
        appleSignInError = nil
        appState.dismissSyncError()

        isSigningInWithEmail = true
        defer { isSigningInWithEmail = false }

        await appState.signInWithEmail(
            email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password,
            metadata: [:]
        )

        if appState.lastSyncError == nil, appState.isAuthenticated {
            instagramHandle = appState.profile.handle
            if !appState.profile.city.isEmpty { city = appState.profile.city }
            advance(to: .invite)
        }
    }

    private func signInWithAppleFlow() async {
        appleSignInError = nil
        appState.dismissSyncError()

        await appState.signInWithApple(using: appleSignIn, metadata: [:])

        if appState.isAuthenticated {
            instagramHandle = appState.profile.handle
            if !appState.profile.city.isEmpty { city = appState.profile.city }
            advance(to: .invite)
        } else if let error = appState.lastSyncError {
            appleSignInError = error
        } else if let error = appleSignIn.lastError {
            appleSignInError = error
        }
    }

    private func validateInviteCode() async -> Bool {
        referralError = ""
        isValidatingReferral = true
        defer { isValidatingReferral = false }

        let valid = await appState.validateReferralCode(inviteCode)
        guard valid else {
            referralError = "Invite code not recognized. Try MARVI-IST or MARVI2026."
            return false
        }
        return true
    }

    private func finishOnboarding() async {
        appState.profile.handle = instagramHandle
        appState.profile.city = city

        if appState.isAuthenticated {
            _ = await appState.saveProfileToServer()
        }

        appState.completeOnboarding(role: .creator)
    }

    @ViewBuilder
    private var busyOverlay: some View {
        if isBusy {
            ZStack {
                Color.black.opacity(0.55).ignoresSafeArea()
                VStack(spacing: 14) {
                    ProgressView().tint(MarviColor.rose).scaleEffect(1.2)
                    Text(busyMessage)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MarviColor.ink)
                }
                .padding(28)
                .background(MarviColor.panel)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(MarviColor.border, lineWidth: 1)
                )
            }
        }
    }

    private var busyMessage: String {
        if isValidatingReferral { return "Validating invite code…" }
        if appState.isBootstrapping { return "Setting up your account…" }
        return "Signing in…"
    }
}

// MARK: - Chrome

private struct OnboardingBackdrop: View {
    var body: some View {
        ZStack {
            MarviColor.surface.ignoresSafeArea()

            GeometryReader { geo in
                Ellipse()
                    .fill(MarviGradient.brandVertical)
                    .frame(width: geo.size.width * 1.2, height: geo.size.height * 0.45)
                    .blur(radius: 90)
                    .opacity(0.42)
                    .offset(y: -geo.size.height * 0.12)

                Ellipse()
                    .fill(MarviColor.aubergine.opacity(0.25))
                    .frame(width: geo.size.width * 0.9, height: geo.size.height * 0.35)
                    .blur(radius: 70)
                    .offset(x: geo.size.width * 0.2, y: geo.size.height * 0.55)
            }
            .ignoresSafeArea()

            OnboardingPatternOverlay()
                .opacity(0.06)
                .ignoresSafeArea()
        }
    }
}

private struct OnboardingPatternOverlay: View {
    var body: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 28
            let cols = Int(geo.size.width / spacing) + 2
            let rows = Int(geo.size.height / spacing) + 2

            Canvas { context, size in
                for row in 0..<rows {
                    for col in 0..<cols {
                        let x = CGFloat(col) * spacing
                        let y = CGFloat(row) * spacing
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: y + 8))
                        path.addLine(to: CGPoint(x: x + 8, y: y))
                        path.addLine(to: CGPoint(x: x + 16, y: y + 8))
                        path.addLine(to: CGPoint(x: x + 8, y: y + 16))
                        path.closeSubpath()
                        context.stroke(path, with: .color(.white), lineWidth: 0.6)
                    }
                }
            }
        }
    }
}

private struct OnboardingTopBar: View {
    let step: OnboardingStep
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                if step != .welcome {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(MarviColor.ink)
                            .frame(width: 40, height: 40)
                            .background(MarviColor.panel)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear.frame(width: 40, height: 40)
                }

                Spacer()

                Text("MARVI SOCIETY")
                    .font(.caption2.weight(.bold))
                    .tracking(2)
                    .foregroundStyle(MarviColor.muted)
            }

            OnboardingProgressBar(current: step)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }
}

private struct OnboardingProgressBar: View {
    let current: OnboardingStep

    var body: some View {
        HStack(spacing: 6) {
            ForEach(OnboardingStep.allCases, id: \.rawValue) { item in
                Capsule()
                    .fill(
                        item.rawValue <= current.rawValue
                            ? AnyShapeStyle(MarviGradient.brand)
                            : AnyShapeStyle(MarviColor.panelElevated)
                    )
                    .frame(height: 4)
                    .overlay(
                        Capsule().stroke(MarviColor.border.opacity(0.5), lineWidth: item.rawValue > current.rawValue ? 1 : 0)
                    )
            }
        }
    }
}

private struct OnboardingBottomBar: View {
    let ctaTitle: String
    let isBusy: Bool
    let isPrimaryDisabled: Bool
    let errorMessage: String?
    let onPrimary: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(MarviColor.tomato)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Button(action: onPrimary) {
                Text(ctaTitle.uppercased())
                    .font(.subheadline.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        isPrimaryDisabled
                            ? AnyShapeStyle(MarviColor.muted.opacity(0.35))
                            : AnyShapeStyle(MarviGradient.brand)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isPrimaryDisabled || isBusy)
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .padding(.top, 8)
        .background(
            LinearGradient(
                colors: [MarviColor.surface.opacity(0), MarviColor.surface, MarviColor.surface],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

private struct OnboardingStepHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow)
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(MarviColor.rose)

            Text(title)
                .font(.system(size: 30, weight: .bold, design: .serif))
                .foregroundStyle(MarviColor.ink)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(MarviColor.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }
}

private struct OnboardingPill: View {
    let icon: String
    let title: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MarviColor.rose)
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(MarviColor.ink)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(MarviColor.panel)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(MarviGradient.brand.opacity(0.35), lineWidth: 1)
        )
    }
}

private struct OnboardingFeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.headline.weight(.semibold))
                .foregroundStyle(MarviColor.rose)
                .frame(width: 36, height: 36)
                .background(MarviColor.rose.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(MarviColor.ink)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(MarviColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(MarviColor.panel.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct OnboardingSecureField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        SecureField(placeholder, text: $text)
            .padding(12)
            .foregroundStyle(MarviColor.ink)
            .background(MarviColor.panelElevated)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(MarviColor.border, lineWidth: 1)
            )
    }
}
