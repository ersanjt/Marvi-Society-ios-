import SwiftUI

// MARK: - Steps

private enum OnboardingStep: Int, CaseIterable {
    case welcome = 0
    case signIn = 1
    case invite = 2
    case profile = 3
    case venueSetup = 4
    case agreement = 5

    var title: String {
        switch self {
        case .welcome: "Welcome"
        case .signIn: "Sign in"
        case .invite: "Invite"
        case .profile: "Profile"
        case .venueSetup: "Venue"
        case .agreement: "Agreement"
        }
    }

    var ctaTitle: String {
        switch self {
        case .welcome: "Get started"
        case .signIn: "Continue"
        case .invite: "Continue"
        case .profile: "Continue"
        case .venueSetup: "Continue"
        case .agreement: "Join Marvi Society"
        }
    }

    /// Number of progress steps shown to the user (welcome is an intro, not counted).
    static let displayTotal = 4

    /// 1-based position used by the progress bar and the "Step x/4" eyebrow.
    /// `profile` and `venueSetup` are mutually exclusive paths, so both map to step 3.
    var displayIndex: Int {
        switch self {
        case .welcome: 0
        case .signIn: 1
        case .invite: 2
        case .profile, .venueSetup: 3
        case .agreement: 4
        }
    }
}

private enum SignupIntent: String, CaseIterable {
    case creator
    case business

    var icon: String {
        switch self {
        case .creator: "sparkles"
        case .business: "building.2.fill"
        }
    }

    var accent: Color {
        switch self {
        case .creator: MarviColor.rose
        case .business: MarviColor.gold
        }
    }

    func shortTitle(for language: AppLanguage) -> String {
        switch self {
        case .creator: MarviL10n.t(.joinAsCreator, language: language)
        case .business: MarviL10n.t(.joinAsBusiness, language: language)
        }
    }

    func title(for language: AppLanguage) -> String {
        switch self {
        case .creator:
            language == .turkish ? "İçerik üreticisi olarak katıl" : "Sign up as a Creator"
        case .business:
            language == .turkish ? "İşletme olarak katıl" : "Sign up as a Business"
        }
    }

    func subtitle(for language: AppLanguage) -> String {
        switch self {
        case .creator:
            language == .turkish
                ? "Markalar ve işletmelerle kolayca iş birliği kur."
                : "Easily collaborate with brands and venues."
        case .business:
            language == .turkish
                ? "İşletmeni tanıt, fotoğraf ekle ve creator’larla bağlan."
                : "Introduce your business, add photos, and connect with creators."
        }
    }
}

// MARK: - Root

struct OnboardingView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var appState: AppState
    @StateObject private var appleSignIn = AppleSignInService()
    @StateObject private var googleSignIn = GoogleSignInService()

    @State private var step: OnboardingStep = .welcome
    @State private var instagramHandle = ""
    @State private var tiktokHandle = ""
    @State private var city = "Istanbul"
    @State private var selectedNiches: Set<String> = []
    @State private var inviteCode = ""
    @State private var referralError = ""
    @State private var email = ""
    @State private var password = ""
    @State private var fullName = ""
    @State private var isSigningInWithEmail = false
    @State private var isValidatingReferral = false
    @State private var isCreatingAccount = false
    @State private var signupIntent: SignupIntent = .creator
    @State private var confirmedAge18 = false
    @State private var acceptedTerms = false
    @State private var appleSignInError: String?
    @State private var inviteValidated = false
    @State private var showPasswordResetConfirmation = false
    @State private var showEmailConfirmation = false
    @State private var pendingSignupOnboarding = false
    @State private var venueName = ""
    @State private var venueArea = ""
    @State private var venueCategoryLabel = "Hotel"
    @State private var customBusinessCategory = ""
    @State private var showLaunchIntro = true
    @State private var welcomeReveal = WelcomeRevealPhase.hidden

    private var lang: AppLanguage { appState.preferredLanguage }

    var body: some View {
        ZStack {
            OnboardingBackdrop(isAnimated: step == .welcome && !showLaunchIntro)

            VStack(spacing: 0) {
                OnboardingTopBar(
                    step: step,
                    onBack: goBack
                )
                .opacity(showLaunchIntro ? 0 : 1)

                Group {
                    switch step {
                    case .welcome: welcomeStep
                    case .signIn: signInStep
                    case .invite: inviteStep
                    case .profile: profileStep
                    case .venueSetup: venueSetupStep
                    case .agreement: agreementStep
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(.easeInOut(duration: 0.32), value: step)
                .opacity(showLaunchIntro && step == .welcome ? 0 : 1)

                OnboardingBottomBar(
                    ctaTitle: primaryCTATitle,
                    isBusy: isBusy,
                    isPrimaryDisabled: !canAdvancePrimary,
                    showsPrimaryCTA: step != .welcome,
                    errorMessage: displayedError,
                    onPrimary: { Task { await handlePrimaryAction() } }
                )
                .opacity(showLaunchIntro ? 0 : 1)
            }
            .frame(maxWidth: horizontalSizeClass == .regular ? 520 : .infinity)
            .frame(maxWidth: .infinity)

            if showLaunchIntro, step == .welcome {
                OnboardingLaunchIntro {
                    finishLaunchIntro()
                }
                .transition(.opacity)
                .zIndex(2)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if let pending = appState.pendingInviteCode, inviteCode.isEmpty {
                inviteCode = pending
            }
            applyResumeState()
            if step != .welcome {
                showLaunchIntro = false
                welcomeReveal = .complete
            }
        }
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
            + Text("\n\n") + Text(appState.t(.passwordResetInstructions))
        }
        .alert(appState.t(.checkEmailTitle), isPresented: $showEmailConfirmation) {
            Button(appState.t(.ok)) {
                withAnimation { isCreatingAccount = false }
                appState.dismissSyncError()
            }
        } message: {
            Text(appState.t(.errConfirmEmail))
        }
    }

    private func finishLaunchIntro() {
        withAnimation(.easeOut(duration: 0.45)) {
            showLaunchIntro = false
        }
        runWelcomeReveal()
    }

    private func runWelcomeReveal() {
        if reduceMotion {
            welcomeReveal = .complete
            return
        }
        let steps: [(WelcomeRevealPhase, Double)] = [
            (.brand, 0.02),
            (.hero, 0.12),
            (.path, 0.28),
            (.cards, 0.42),
            (.footer, 0.58),
            (.complete, 0.72)
        ]
        for (phase, delay) in steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.84)) {
                    welcomeReveal = phase
                }
            }
        }
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            BrandMark(size: 64)
                .padding(.bottom, 20)
                .welcomeReveal(welcomeReveal, threshold: .brand)

            VStack(alignment: .leading, spacing: 8) {
                Text(appState.t(.heroLine1))
                    .font(.system(size: 34, weight: .bold, design: .serif))
                    .foregroundStyle(MarviColor.ink)
                    .minimumScaleFactor(0.8)
                    .lineLimit(2)

                Text(appState.t(.heroLine2))
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundStyle(MarviGradient.brand)

                Text(appState.t(.heroSubtitle))
                    .font(.subheadline)
                    .foregroundStyle(MarviColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
            .welcomeReveal(welcomeReveal, threshold: .hero)

            Spacer(minLength: 28)

            Text(appState.t(.choosePathPrompt))
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .tracking(0.8)
                .foregroundStyle(MarviColor.muted)
                .padding(.bottom, 12)
                .welcomeReveal(welcomeReveal, threshold: .path)

            VStack(spacing: 12) {
                SignupIntentCard(
                    intent: .creator,
                    language: appState.preferredLanguage,
                    isSelected: signupIntent == .creator
                ) {
                    signupIntent = .creator
                    isCreatingAccount = true
                    advance(to: .signIn)
                }
                .welcomeReveal(welcomeReveal, threshold: .cards, offsetY: 28)

                SignupIntentCard(
                    intent: .business,
                    language: appState.preferredLanguage,
                    isSelected: signupIntent == .business
                ) {
                    signupIntent = .business
                    isCreatingAccount = true
                    advance(to: .signIn)
                }
                .welcomeReveal(welcomeReveal, threshold: .cards, offsetY: 36, delayBoost: true)
            }

            Spacer(minLength: 24)

            Button {
                isCreatingAccount = false
                advance(to: .signIn)
            } label: {
                Text(appState.t(.alreadyMemberSignIn))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MarviColor.rose)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 8)
            .welcomeReveal(welcomeReveal, threshold: .footer)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    private var signInStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                OnboardingStepHeader(
                    eyebrow: appState.t(.step1of4),
                    title: isCreatingAccount ? signupIntent.title(for: appState.preferredLanguage) : appState.t(.signInContinue),
                    subtitle: isCreatingAccount ? appState.t(.createAccountSub) : appState.t(.signInSub)
                )

                if isCreatingAccount {
                    HStack(spacing: 10) {
                        ForEach(SignupIntent.allCases, id: \.rawValue) { intent in
                            Button {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                    signupIntent = intent
                                }
                            } label: {
                                Label(intent == .creator ? appState.t(.creator) : appState.t(.joinAsBusiness), systemImage: intent.icon)
                                    .font(.caption.weight(.bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 11)
                                    .foregroundStyle(signupIntent == intent ? .white : MarviColor.graphite)
                                    .background(
                                        signupIntent == intent
                                            ? AnyShapeStyle(MarviGradient.brand)
                                            : AnyShapeStyle(MarviColor.panelElevated)
                                    )
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(spacing: 12) {
                    if isCreatingAccount {
                        MarviTextField(placeholder: appState.t(.fullNamePlaceholder), text: $fullName)
                    }
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

                if APIConfig.googleSignInEnabled || APIConfig.appleSignInEnabled {
                    SocialDivider(label: appState.t(.orContinueWith))

                    if APIConfig.appleSignInEnabled {
                        AppleSignInButton(
                            title: appleSignIn.isSigningIn ? appState.t(.signingIn) : appState.t(.signInWithApple),
                            isLoading: appleSignIn.isSigningIn,
                            isDisabled: appleSignIn.isSigningIn || isBusy
                        ) {
                            Task { await signInWithAppleFlow() }
                        }
                    }

                    if APIConfig.googleSignInEnabled {
                        GoogleSignInButton(
                            title: googleSignIn.isSigningIn ? appState.t(.signingIn) : appState.t(.signInWithGoogle),
                            isLoading: googleSignIn.isSigningIn,
                            isDisabled: googleSignIn.isSigningIn || isBusy
                        ) {
                            Task { await signInWithGoogleFlow() }
                        }
                    }
                } else {
                    Text(appState.t(.emailSignInRecommended))
                        .font(.caption2)
                        .foregroundStyle(MarviColor.muted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
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

                MarviTextField(
                    placeholder: appState.t(.tiktokHandleField),
                    text: $tiktokHandle,
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

    private var venueSetupStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                OnboardingStepHeader(
                    eyebrow: signupIntent == .business ? appState.t(.step3of4) : appState.t(.step3of4),
                    title: appState.t(.addLocation),
                    subtitle: appState.t(.addLocationSub)
                )

                MarviCard {
                    VStack(alignment: .leading, spacing: 14) {
                        MarviTextField(placeholder: appState.t(.venueNamePh), text: $venueName)
                        MarviTextField(placeholder: appState.t(.areaPh), text: $venueArea)

                        Text(appState.t(.locationTypeLabel))
                            .font(.caption.weight(.bold))
                            .textCase(.uppercase)
                            .foregroundStyle(MarviColor.muted)

                        Picker(appState.t(.locationTypeLabel), selection: $venueCategoryLabel) {
                            ForEach(BusinessCategoryCatalog.all) { item in
                                Text(item.label(for: appState.preferredLanguage)).tag(item.english)
                            }
                            if !customBusinessCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(customBusinessCategory.trimmingCharacters(in: .whitespacesAndNewlines))
                                    .tag(customBusinessCategory.trimmingCharacters(in: .whitespacesAndNewlines))
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(MarviColor.rose)

                        MarviTextField(
                            placeholder: appState.preferredLanguage == .turkish
                                ? "Kategori yoksa buraya yazın"
                                : "Can't find it? Add your category",
                            text: $customBusinessCategory,
                            autocapitalization: .words
                        )

                        Button {
                            let custom = customBusinessCategory.trimmingCharacters(in: .whitespacesAndNewlines)
                            if custom.count >= 2 { venueCategoryLabel = custom }
                        } label: {
                            Label(
                                appState.preferredLanguage == .turkish ? "Bu kategoriyi kullan" : "Use this category",
                                systemImage: "plus.circle.fill"
                            )
                            .font(.caption.weight(.bold))
                            .foregroundStyle(MarviColor.rose)
                        }
                        .buttonStyle(.plain)
                        .disabled(customBusinessCategory.trimmingCharacters(in: .whitespacesAndNewlines).count < 2)
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
        isSigningInWithEmail || appleSignIn.isSigningIn || googleSignIn.isSigningIn || isValidatingReferral || appState.isBootstrapping
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
        case .invite, .profile, .venueSetup: return appState.t(.continueAction)
        case .agreement: return appState.t(.joinMarvi)
        }
    }

    private var canAdvancePrimary: Bool {
        switch step {
        case .welcome:
            return true
        case .signIn:
            if appState.isAuthenticated { return !isBusy }
            if isCreatingAccount {
                return canSignUpWithEmail && !isBusy
            }
            return canSignInWithEmail && !isBusy
        case .invite:
            guard appState.isAuthenticated else { return false }
            return !inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isBusy
        case .profile:
            return isProfileValid && !isBusy
        case .venueSetup:
            return !venueName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !venueArea.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !venueCategoryLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !isBusy
        case .agreement:
            return confirmedAge18 && acceptedTerms && !isBusy
        }
    }

    private var canSignInWithEmail: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty
    }

    private var canSignUpWithEmail: Bool {
        canSignInWithEmail &&
            !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            password.count >= 8
    }

    private var isProfileValid: Bool {
        !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Actions

    private func applyResumeState() {
        guard appState.isAuthenticated else { return }
        instagramHandle = appState.profile.handle
        tiktokHandle = appState.profile.tiktokHandle
        if !appState.profile.city.isEmpty {
            city = appState.profile.city
        }
        selectedNiches = Set(appState.profile.niches)

        Task {
            await routeAfterAuthentication(source: .resume)
        }
    }

    private func goBack() {
        let previous: OnboardingStep?
        switch step {
        case .welcome:
            previous = nil
        case .signIn:
            previous = .welcome
        case .invite:
            previous = .signIn
        case .profile, .venueSetup:
            previous = .signIn
        case .agreement:
            previous = signupIntent == .business ? .venueSetup : .profile
        }
        guard let previous else { return }
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
                await routeAfterAuthentication(source: .manual)
            } else if isCreatingAccount {
                await signUpWithEmailFlow()
            } else {
                await signInWithEmailFlow()
            }
        case .invite:
            // Invite codes removed — skip to profile/venue setup.
            if signupIntent == .business {
                advance(to: .venueSetup)
            } else {
                advance(to: .profile)
            }
        case .profile:
            appState.profile.handle = instagramHandle
            appState.profile.tiktokHandle = tiktokHandle
            appState.profile.city = city
            appState.profile.niches = Array(selectedNiches).sorted()
            if appState.profile.languages.isEmpty {
                appState.profile.languages = ["English"]
            }
            advance(to: .agreement)
        case .venueSetup:
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
            "tiktok_handle": tiktokHandle.trimmingCharacters(in: .whitespacesAndNewlines),
            "full_name": fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? appState.profile.name.trimmingCharacters(in: .whitespacesAndNewlines)
                : fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
    }

    /// Auth metadata for create-account only — never overwrite an existing profile on sign-in.
    private func authMetadataForCurrentMode() -> [String: String] {
        isCreatingAccount ? signupMetadata() : [:]
    }

    private enum AuthRouteSource {
        case resume
        case manual
    }

    private func routeAfterAuthentication(source: AuthRouteSource) async {
        instagramHandle = appState.profile.handle
        tiktokHandle = appState.profile.tiktokHandle
        if !appState.profile.city.isEmpty { city = appState.profile.city }
        selectedNiches = Set(appState.profile.niches)
        pendingSignupOnboarding = false

        if await appState.isExistingMemberOnServer() {
            let role: UserRole
            if signupIntent == .business, appState.allowedRoles.contains(.venue) {
                role = .venue
            } else {
                role = appState.allowedRoles.first ?? .creator
            }
            appState.completeOnboarding(role: role)
            return
        }

        // Don't yank users backward if they are already past sign-in (e.g. invite/profile).
        if source == .resume, step != .welcome, step != .signIn {
            return
        }

        advance(to: signupIntent == .business ? .venueSetup : .profile)
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
            await routeAfterAuthentication(source: .manual)
        }
    }

    private func signUpWithEmailFlow() async {
        appleSignInError = nil
        appState.dismissSyncError()

        isSigningInWithEmail = true
        defer { isSigningInWithEmail = false }

        pendingSignupOnboarding = true
        appState.profile.name = fullName.trimmingCharacters(in: .whitespacesAndNewlines)

        await appState.signUpWithEmail(
            email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password,
            metadata: signupMetadata()
        )

        if AppState.isAccountAlreadyExistsMessage(appState.lastSyncError) {
            pendingSignupOnboarding = false
            withAnimation { isCreatingAccount = false }
            return
        }

        if appState.lastSyncError != nil {
            pendingSignupOnboarding = false
            if let message = appState.lastSyncError,
               message.contains("confirmation link") || message.contains("onay bağlantısı") {
                showEmailConfirmation = true
            }
        }

        if appState.lastSyncError == nil, appState.isAuthenticated {
            instagramHandle = appState.profile.handle
            tiktokHandle = appState.profile.tiktokHandle
            await routeAfterAuthentication(source: .manual)
        }
    }

    private func signInWithGoogleFlow() async {
        appleSignInError = nil
        appState.dismissSyncError()

        await appState.signInWithGoogle(using: googleSignIn, metadata: authMetadataForCurrentMode())

        if appState.isAuthenticated {
            await routeAfterAuthentication(source: .manual)
        } else if let error = appState.lastSyncError {
            appleSignInError = error
        } else if let error = googleSignIn.lastError {
            appleSignInError = error
        }
    }

    private func signInWithAppleFlow() async {
        appleSignInError = nil
        appState.dismissSyncError()

        await appState.signInWithApple(using: appleSignIn, metadata: authMetadataForCurrentMode())

        if appState.isAuthenticated {
            await routeAfterAuthentication(source: .manual)
        } else if let error = appState.lastSyncError {
            appleSignInError = error
        } else if let error = appleSignIn.lastError {
            appleSignInError = error
        }
    }

    private func handlePostAuthentication() async {
        await routeAfterAuthentication(source: .manual)
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
                referralError = appState.t(.errInviteInvalid)
            } else if lower.contains("different email") {
                referralError = appState.t(.errInviteEmailMismatch)
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
        if signupIntent == .business {
            let trimmedName = venueName.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedArea = venueArea.trimmingCharacters(in: .whitespacesAndNewlines)
            let registered = await appState.registerVenue(
                name: trimmedName,
                area: trimmedArea,
                category: BusinessCategoryCatalog.offerCategory(for: venueCategoryLabel),
                categoryLabel: venueCategoryLabel,
                contactName: fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? appState.profile.name
                    : fullName.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            guard registered else { return }
        } else {
            appState.profile.handle = instagramHandle
            appState.profile.tiktokHandle = tiktokHandle
            appState.profile.city = city
            appState.profile.niches = Array(selectedNiches).sorted()
            if appState.profile.languages.isEmpty {
                appState.profile.languages = ["English"]
            }

            if appState.isAuthenticated {
                _ = await appState.saveProfileToServer()
            }
        }

        appState.completeOnboarding(role: signupIntent == .business ? .venue : .creator)
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

private enum WelcomeRevealPhase: Int, Comparable {
    case hidden = 0
    case brand = 1
    case hero = 2
    case path = 3
    case cards = 4
    case footer = 5
    case complete = 6

    static func < (lhs: WelcomeRevealPhase, rhs: WelcomeRevealPhase) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

private extension View {
    func welcomeReveal(
        _ phase: WelcomeRevealPhase,
        threshold: WelcomeRevealPhase,
        offsetY: CGFloat = 18,
        delayBoost: Bool = false
    ) -> some View {
        let visible = phase >= threshold
        return self
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : offsetY)
            .scaleEffect(visible ? 1 : (delayBoost ? 0.96 : 0.98), anchor: .leading)
            .allowsHitTesting(visible)
    }
}

private enum LaunchIntroSlide: Int, CaseIterable, Identifiable {
    case creators = 0
    case brand = 1
    case affiliate = 2

    var id: Int { rawValue }

    var iconSystemName: String {
        switch self {
        case .creators: "video"
        case .brand: "briefcase"
        case .affiliate: "hand.raised"
        }
    }

    var titleKey: MarviL10n.Key {
        switch self {
        case .creators: .introSlideCreatorsTitle
        case .brand: .introSlideBrandTitle
        case .affiliate: .introSlideAffiliateTitle
        }
    }

    var subtitleKey: MarviL10n.Key {
        switch self {
        case .creators: .introSlideCreatorsSub
        case .brand: .introSlideBrandSub
        case .affiliate: .introSlideAffiliateSub
        }
    }
}

private struct OnboardingLaunchIntro: View {
    let onFinished: () -> Void

    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var page = 0
    @State private var orbPulse = false
    @State private var contentAppeared = false

    private let accent = Color(hex: "#A855F7")
    private let autoAdvanceSeconds: TimeInterval = 3.2

    private var appVersionLabel: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.5.3"
        return "v\(version)"
    }

    var body: some View {
        ZStack {
            Color(hex: "#0B0E14").ignoresSafeArea()

            GeometryReader { geo in
                Circle()
                    .fill(accent.opacity(0.34))
                    .frame(width: geo.size.width * 0.95)
                    .blur(radius: 90)
                    .scaleEffect(orbPulse ? 1.08 : 0.92)
                    .offset(y: -geo.size.height * 0.18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                Circle()
                    .fill(MarviColor.aubergine.opacity(0.18))
                    .frame(width: geo.size.width * 0.7)
                    .blur(radius: 80)
                    .scaleEffect(orbPulse ? 0.95 : 1.08)
                    .offset(x: geo.size.width * 0.22, y: geo.size.height * 0.42)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                HStack {
                    Button(action: onFinished) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.body.weight(.semibold))
                            Text(appState.t(.introHome))
                                .font(.body.weight(.medium))
                        }
                        .foregroundStyle(Color.white.opacity(0.88))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(appState.t(.introHome))

                    Spacer()

                    Button(action: onFinished) {
                        Text(appState.t(.introSkip))
                            .font(.body.weight(.medium))
                            .foregroundStyle(Color.white.opacity(0.72))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(appState.t(.introSkip))
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                Spacer(minLength: 12)

                TabView(selection: $page) {
                    ForEach(LaunchIntroSlide.allCases) { slide in
                        LaunchIntroSlideCard(
                            slide: slide,
                            accent: accent,
                            language: appState.preferredLanguage
                        )
                        .tag(slide.rawValue)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(maxHeight: 360)
                .opacity(contentAppeared ? 1 : 0)
                .offset(y: contentAppeared ? 0 : 18)

                LaunchIntroPageIndicator(
                    count: LaunchIntroSlide.allCases.count,
                    current: page,
                    accent: accent
                )
                .padding(.top, 28)
                .opacity(contentAppeared ? 1 : 0)

                Spacer(minLength: 12)

                Text(appVersionLabel)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.28))
                    .padding(.bottom, 18)
            }
        }
        .onAppear(perform: start)
        .task(id: reduceMotion) {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(autoAdvanceSeconds * 1_000_000_000))
                guard !Task.isCancelled else { break }
                withAnimation(.easeInOut(duration: 0.45)) {
                    page = (page + 1) % LaunchIntroSlide.allCases.count
                }
            }
        }
    }

    private func start() {
        if reduceMotion {
            contentAppeared = true
            return
        }

        withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true)) {
            orbPulse = true
        }
        withAnimation(.spring(response: 0.55, dampingFraction: 0.86)) {
            contentAppeared = true
        }
    }
}

private struct LaunchIntroSlideCard: View {
    let slide: LaunchIntroSlide
    let accent: Color
    let language: AppLanguage

    var body: some View {
        VStack(spacing: 22) {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(hex: "#16122A"))
                    .frame(width: 108, height: 108)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(accent.opacity(0.22), lineWidth: 1)
                    )
                    .shadow(color: accent.opacity(0.28), radius: 28, x: 0, y: 10)

                Group {
                    if slide == .affiliate {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "hand.raised")
                                .font(.system(size: 40, weight: .regular))
                            HStack(spacing: -6) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 10))
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 12))
                            }
                            .offset(x: 10, y: -8)
                        }
                    } else {
                        Image(systemName: slide.iconSystemName)
                            .font(.system(size: 40, weight: .regular))
                    }
                }
                .foregroundStyle(accent)
                .shadow(color: accent.opacity(0.55), radius: 12, x: 0, y: 0)
            }

            VStack(spacing: 12) {
                Text(MarviL10n.t(slide.titleKey, language: language))
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.85)

                Text(MarviL10n.t(slide.subtitleKey, language: language))
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.58))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 28)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

private struct LaunchIntroPageIndicator: View {
    let count: Int
    let current: Int
    let accent: Color

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? accent : Color.white.opacity(0.22))
                    .frame(width: index == current ? 28 : 8, height: 8)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: current)
            }
        }
        .accessibilityLabel("Slide \(current + 1) of \(count)")
    }
}

private struct OnboardingBackdrop: View {
    var isAnimated: Bool = false
    @State private var pulse = false

    var body: some View {
        ZStack {
            MarviColor.surface.ignoresSafeArea()

            GeometryReader { geo in
                Ellipse()
                    .fill(MarviGradient.brandVertical)
                    .frame(width: geo.size.width * 1.2, height: geo.size.height * 0.45)
                    .blur(radius: 90)
                    .opacity(isAnimated ? (pulse ? 0.5 : 0.34) : 0.42)
                    .scaleEffect(isAnimated ? (pulse ? 1.06 : 0.96) : 1)
                    .offset(y: -geo.size.height * 0.12)

                Ellipse()
                    .fill(MarviColor.aubergine.opacity(0.25))
                    .frame(width: geo.size.width * 0.9, height: geo.size.height * 0.35)
                    .blur(radius: 70)
                    .opacity(isAnimated ? (pulse ? 0.32 : 0.2) : 0.25)
                    .offset(x: geo.size.width * 0.2, y: geo.size.height * 0.55)
            }
            .ignoresSafeArea()
            .animation(
                isAnimated
                    ? .easeInOut(duration: 3.2).repeatForever(autoreverses: true)
                    : .default,
                value: pulse
            )

            OnboardingPatternOverlay()
                .opacity(0.06)
                .ignoresSafeArea()
        }
        .onAppear {
            guard isAnimated else { return }
            pulse = true
        }
        .onChange(of: isAnimated) { _, animated in
            pulse = animated
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

            if step != .welcome {
                OnboardingProgressBar(current: step)
            }
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
            ForEach(1...OnboardingStep.displayTotal, id: \.self) { index in
                Capsule()
                    .fill(
                        index <= current.displayIndex
                            ? AnyShapeStyle(MarviGradient.brand)
                            : AnyShapeStyle(MarviColor.panelElevated)
                    )
                    .frame(height: 4)
                    .overlay(
                        Capsule().stroke(MarviColor.border.opacity(0.5), lineWidth: index > current.displayIndex ? 1 : 0)
                    )
            }
        }
    }
}

private struct OnboardingBottomBar: View {
    let ctaTitle: String
    let isBusy: Bool
    let isPrimaryDisabled: Bool
    var showsPrimaryCTA: Bool = true
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

            if showsPrimaryCTA {
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
        }
        .padding(.top, showsPrimaryCTA || errorMessage != nil ? 8 : 0)
        .background(
            showsPrimaryCTA
                ? AnyShapeStyle(LinearGradient(
                    colors: [MarviColor.surface.opacity(0), MarviColor.surface, MarviColor.surface],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                : AnyShapeStyle(Color.clear)
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

private struct SignupIntentCard: View {
    let intent: SignupIntent
    let language: AppLanguage
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: intent.icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(intent.accent.gradient)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: intent.accent.opacity(0.35), radius: 10, x: 0, y: 4)

                VStack(alignment: .leading, spacing: 5) {
                    Text(intent.shortTitle(for: language))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(MarviColor.ink)

                    Text(intent.subtitle(for: language))
                        .font(.subheadline)
                        .foregroundStyle(MarviColor.graphite)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.body.weight(.bold))
                    .foregroundStyle(intent.accent)
                    .frame(width: 36, height: 36)
                    .background(intent.accent.opacity(0.14))
                    .clipShape(Circle())
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(MarviColor.panelElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(intent.accent.opacity(isSelected ? 0.85 : 0.45), lineWidth: isSelected ? 2 : 1.5)
            )
            .shadow(color: intent.accent.opacity(0.12), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(SocialButtonStyle())
        .accessibilityLabel(intent.title(for: language))
        .accessibilityHint(intent.subtitle(for: language))
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
