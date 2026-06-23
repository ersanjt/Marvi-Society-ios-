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
        case .signIn: "Continue"
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
    @State private var selectedNiches: Set<String> = []
    @State private var inviteCode = ""
    @State private var referralError = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isSigningInWithEmail = false
    @State private var isValidatingReferral = false
    @State private var isCreatingAccount = false
    @State private var confirmedAge18 = false
    @State private var acceptedTerms = false
    @State private var appleSignInError: String?
    @State private var inviteValidated = false
    @State private var showPasswordResetConfirmation = false

    private var lang: AppLanguage { appState.preferredLanguage }

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
        .onChange(of: appState.isAuthenticated) { _, isAuthenticated in
            if isAuthenticated { applyResumeState() }
        }
        .overlay { busyOverlay }
        .alert(appState.t(.checkEmailTitle), isPresented: $showPasswordResetConfirmation) {
            Button(appState.t(.ok)) {
                appState.dismissPasswordResetMessage()
            }
        } message: {
            Text(appState.passwordResetMessage ?? appState.t(.passwordResetDefault))
        }
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 12)

            BrandMark(size: 72)
                .padding(.bottom, 28)

            VStack(alignment: .leading, spacing: 12) {
                Text(appState.t(.heroLine1))
                    .font(.system(size: 42, weight: .bold, design: .serif))
                    .foregroundStyle(MarviColor.ink)
                    .minimumScaleFactor(0.85)
                    .lineLimit(2)

                Text(appState.t(.heroLine2))
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundStyle(MarviGradient.brand)

                Text(appState.t(.heroSubtitle))
                    .font(.subheadline)
                    .foregroundStyle(MarviColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }

            Spacer(minLength: 28)

            HStack(spacing: 10) {
                OnboardingPill(icon: "calendar", title: appState.t(.when))
                OnboardingPill(icon: "mappin.and.ellipse", title: appState.t(.whereAxis))
                OnboardingPill(icon: "sparkles", title: appState.t(.eventTypeAxis))
            }

            VStack(spacing: 12) {
                OnboardingFeatureRow(
                    icon: "checkmark.seal.fill",
                    title: appState.t(.featApprovedTitle),
                    subtitle: appState.t(.featApprovedSub)
                )
                OnboardingFeatureRow(
                    icon: "building.2.fill",
                    title: appState.t(.featVenuesTitle),
                    subtitle: appState.t(.featVenuesSub)
                )
                OnboardingFeatureRow(
                    icon: "camera.fill",
                    title: appState.t(.featProofTitle),
                    subtitle: appState.t(.featProofSub)
                )
            }
            .padding(.top, 22)

            Spacer(minLength: 8)

            Button {
                isCreatingAccount = false
                advance(to: .signIn)
            } label: {
                Text(appState.t(.alreadyMemberSignIn))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MarviColor.rose)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
    }

    private var signInStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                OnboardingStepHeader(
                    eyebrow: appState.t(.step1of4),
                    title: isCreatingAccount ? appState.t(.createAccount) : appState.t(.signInContinue),
                    subtitle: isCreatingAccount ? appState.t(.createAccountSub) : appState.t(.signInSub)
                )

                Button {
                    Task { await signInWithAppleFlow() }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "apple.logo")
                            .font(.title3.weight(.semibold))
                        Text(appleSignIn.isSigningIn ? appState.t(.signingIn) : appState.t(.signInWithApple))
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
                    Text(appState.t(.orEmail))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MarviColor.muted)
                    Rectangle().fill(MarviColor.border).frame(height: 1)
                }

                VStack(spacing: 12) {
                    MarviTextField(placeholder: appState.t(.email), text: $email, autocapitalization: .never)
                    OnboardingSecureField(placeholder: appState.t(.password), text: $password)
                }

                Button {
                    withAnimation { isCreatingAccount.toggle() }
                } label: {
                    Text(isCreatingAccount ? appState.t(.alreadyMemberToggle) : appState.t(.newMemberCreate))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MarviColor.rose)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)

                if !isCreatingAccount {
                    Button {
                        Task { await requestPasswordReset() }
                    } label: {
                        Text(appState.t(.forgotPasswordReset))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MarviColor.muted)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isBusy)
                }

                if AppState.isAccountAlreadyExistsMessage(appState.lastSyncError), isCreatingAccount {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(appState.t(.accountExistsTitle))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(MarviColor.tomato)
                        Button {
                            withAnimation {
                                isCreatingAccount = false
                                appState.dismissSyncError()
                            }
                        } label: {
                            Text(appState.t(.signInToAccount))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(MarviColor.emerald)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text(appState.t(.appleDevNotice))
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
                    eyebrow: appState.t(.step2of4),
                    title: appState.t(.inviteTitle),
                    subtitle: appState.t(.inviteSubtitle)
                )

                MarviTextField(
                    placeholder: appState.t(.invitePlaceholder),
                    text: $inviteCode,
                    autocapitalization: .characters
                )

                if inviteValidated {
                    Label(appState.t(.inviteAccepted), systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MarviColor.emerald)
                }

                if !referralError.isEmpty {
                    Label(referralError, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MarviColor.tomato)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(appState.t(.memberBenefits))
                        .font(.caption.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(MarviColor.muted)

                    OnboardingFeatureRow(
                        icon: "star.fill",
                        title: appState.t(.featCuratedTitle),
                        subtitle: appState.t(.featCuratedSub)
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
                    eyebrow: appState.t(.step3of4),
                    title: appState.t(.profileSetupTitle),
                    subtitle: appState.t(.profileSetupSub)
                )

                MarviTextField(
                    placeholder: appState.t(.instagramPlaceholder),
                    text: $instagramHandle,
                    autocapitalization: .never
                )

                MarviTextField(placeholder: appState.t(.cityPlaceholder), text: $city)

                Text(appState.t(.yourNiches))
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(MarviColor.muted)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(["Dining", "Nightlife", "Beauty", "Wellness", "Fitness", "Retail"], id: \.self) { niche in
                            Button {
                                if selectedNiches.contains(niche) {
                                    selectedNiches.remove(niche)
                                } else {
                                    selectedNiches.insert(niche)
                                }
                            } label: {
                                Text(niche)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(selectedNiches.contains(niche) ? .white : MarviColor.ink)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        selectedNiches.contains(niche)
                                            ? AnyShapeStyle(MarviGradient.brand)
                                            : AnyShapeStyle(MarviColor.panelElevated)
                                    )
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Text(appState.t(.popularCities))
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
                    eyebrow: appState.t(.step4of4),
                    title: appState.t(.agreementTitle),
                    subtitle: appState.t(.agreementSub)
                )

                MarviCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Toggle(isOn: $confirmedAge18) {
                            Text(appState.t(.age18Toggle))
                                .font(.subheadline)
                                .foregroundStyle(MarviColor.ink)
                        }
                        .tint(MarviColor.rose)

                        Toggle(isOn: $acceptedTerms) {
                            Text(appState.t(.termsToggle))
                                .font(.subheadline)
                                .foregroundStyle(MarviColor.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .tint(MarviColor.rose)

                        VStack(alignment: .leading, spacing: 8) {
                            Link(appState.t(.privacyPolicy), destination: AppLinks.privacyPolicy)
                            Link(appState.t(.termsOfService), destination: AppLinks.termsOfService)
                            Link(appState.t(.communityGuidelines), destination: AppLinks.communityGuidelines)
                        }
                        .font(.caption.weight(.semibold))
                    }
                }

                Text(appState.t(.venueWorkspaceNote))
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
        if step == .signIn, appState.isAuthenticated { return appState.t(.continueAction) }
        switch step {
        case .welcome: return appState.t(.getStarted)
        case .signIn: return appState.t(.continueAction)
        case .invite, .profile: return appState.t(.continueAction)
        case .agreement: return appState.t(.joinMarvi)
        }
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
        Task {
            if await appState.isExistingMemberOnServer() {
                appState.completeOnboarding(role: appState.allowedRoles.first ?? .creator)
            } else {
                withAnimation { step = .invite }
            }
        }
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
                if await appState.isExistingMemberOnServer() {
                    appState.completeOnboarding(role: appState.allowedRoles.first ?? .creator)
                } else {
                    advance(to: .invite)
                }
            } else if isCreatingAccount {
                await signUpWithEmailFlow()
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
            appState.profile.niches = Array(selectedNiches).sorted()
            if appState.profile.languages.isEmpty {
                appState.profile.languages = ["English"]
            }
            advance(to: .agreement)
        case .agreement:
            await finishOnboarding()
        }
    }

    private func inferredSignupLocale() -> String {
        if appState.preferredLanguage == .turkish { return "tr" }
        if Locale.current.language.languageCode?.identifier == "tr" { return "tr" }
        let istanbulCities = ["istanbul", "kadıköy", "kadikoy", "beşiktaş", "besiktas", "şişli", "sisli"]
        if istanbulCities.contains(city.lowercased()) { return "tr" }
        if appState.profile.languages.contains(where: { $0.lowercased().contains("turk") }) { return "tr" }
        return "en"
    }

    private func signupMetadata() -> [String: String] {
        [
            "locale": inferredSignupLocale(),
            "city": city.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            "instagram_handle": instagramHandle.trimmingCharacters(in: .whitespacesAndNewlines),
            "full_name": appState.profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
    }

    private func signInWithEmailFlow() async {
        appleSignInError = nil
        appState.dismissSyncError()

        isSigningInWithEmail = true
        defer { isSigningInWithEmail = false }

        await appState.signInWithEmail(
            email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password,
            metadata: signupMetadata()
        )

        if appState.lastSyncError == nil, appState.isAuthenticated {
            await handlePostAuthentication()
        }
    }

    private func signUpWithEmailFlow() async {
        appleSignInError = nil
        appState.dismissSyncError()

        isSigningInWithEmail = true
        defer { isSigningInWithEmail = false }

        await appState.signUpWithEmail(
            email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password,
            metadata: signupMetadata()
        )

        if AppState.isAccountAlreadyExistsMessage(appState.lastSyncError) {
            withAnimation { isCreatingAccount = false }
            return
        }

        if appState.lastSyncError == nil, appState.isAuthenticated {
            instagramHandle = appState.profile.handle
            await handlePostAuthentication()
        }
    }

    private func signInWithAppleFlow() async {
        appleSignInError = nil
        appState.dismissSyncError()

        await appState.signInWithApple(using: appleSignIn, metadata: signupMetadata())

        if appState.isAuthenticated {
            await handlePostAuthentication()
        } else if let error = appState.lastSyncError {
            appleSignInError = error
        } else if let error = appleSignIn.lastError {
            appleSignInError = error
        }
    }

    private func handlePostAuthentication() async {
        instagramHandle = appState.profile.handle
        if !appState.profile.city.isEmpty { city = appState.profile.city }
        selectedNiches = Set(appState.profile.niches)

        if await appState.isExistingMemberOnServer() {
            appState.completeOnboarding(role: appState.allowedRoles.first ?? .creator)
        } else {
            advance(to: .invite)
        }
    }

    private func requestPasswordReset() async {
        appState.dismissSyncError()
        await appState.requestPasswordReset(email: email)
        if appState.passwordResetMessage != nil {
            showPasswordResetConfirmation = true
        }
    }

    private func validateInviteCode() async -> Bool {
        referralError = ""
        isValidatingReferral = true
        defer { isValidatingReferral = false }

        // Redeem on the server (SECURITY DEFINER) — avoids brittle PostgREST filters on the client.
        if let redeemError = await appState.redeemReferralCode(inviteCode) {
            let lower = redeemError.lowercased()
            if lower.contains("invalid invite") || lower.contains("invite code required") {
                referralError = "Invite code not recognized. Ask your curator for a valid code."
            } else if lower.contains("could not find the function") {
                referralError = "Server setup incomplete. Run apply-referral-fix.sql in Supabase."
            } else {
                referralError = redeemError
            }
            return false
        }
        return true
    }

    private func finishOnboarding() async {
        appState.profile.handle = instagramHandle
        appState.profile.city = city
        appState.profile.niches = Array(selectedNiches).sorted()
        if appState.profile.languages.isEmpty {
            appState.profile.languages = ["English"]
        }

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
        if isValidatingReferral { return appState.t(.validatingInvite) }
        if appState.isBootstrapping { return appState.t(.settingUpAccount) }
        return appState.t(.signingIn)
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
