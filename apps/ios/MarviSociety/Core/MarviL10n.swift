import Foundation

// MARK: - Istanbul Turkish + English UI strings

enum MarviL10n {
    static func t(_ key: Key, language: AppLanguage) -> String {
        switch language {
        case .english: english[key] ?? key.rawValue
        case .turkish: turkish[key] ?? english[key] ?? key.rawValue
        }
    }

    enum Key: String, CaseIterable {
        // Common
        case ok, cancel, close, done, continueAction, save, delete, retry, refresh, loading
        case email, password, signIn, signOut, signUp, forgotPassword, deleteConfirmWord
        // Tabs
        case explore, myEvents, profile, studio, inbox, account, admin
        // Onboarding
        case heroLine1, heroLine2, heroSubtitle, getStarted, alreadyMemberSignIn
        case when, whereAxis, eventTypeAxis
        case featApprovedTitle, featApprovedSub, featVenuesTitle, featVenuesSub
        case featProofTitle, featProofSub
        case step1of4, step2of4, step3of4, step4of4
        case createAccount, signInContinue, welcomeBackSignIn, createAccountSub, signInSub
        case orEmail, orAppleSignIn, orContinueWith, newMemberCreate, alreadyMemberToggle, forgotPasswordReset
        case accountExistsTitle, signInToAccount
        case signInWithApple, signInWithGoogle, signingIn, appleDevNotice, emailSignInRecommended
        case inviteTitle, inviteSubtitle, invitePlaceholder, inviteAccepted, memberBenefits
        case featCuratedTitle, featCuratedSub
        case profileSetupTitle, profileSetupSub, fullNamePlaceholder, instagramPlaceholder, cityPlaceholder
        case yourNiches, popularCities
        case agreementTitle, agreementSub, age18Toggle, termsToggle
        case joinMarvi, welcome, signInStep, inviteStep, profileStep, agreementStep
        case validatingInvite, settingUpAccount, checkEmailTitle
        case passwordResetDefault, passwordResetInstructions
        // Discover
        case privateAccess, yourCity, findExploreEvents, eventsCount
        case filterAll, filterSaved, filterFewSlots, sortNewest, sortFewSlots, sortBestMatch
        case listMode, mapMode, tonight, thisWeek, weekend
        case filters, sortBy, location, date, anyWhen, anyWhere, anyType
        case searchEvents, noEventsTitle, noEventsSub, viewEventBrief, nearYou
        case dining, nightlife, wellness, beauty, fitness, retail
        // Offers / bookings
        case acceptInvitation, rsvpEvent, confirmGift, useNow, shippingAddress, guestCount
        case myEventsTitle, requests, toConfirm, toReview, toVisit, completed
        case noBookings, noBookingsSub, checkIn, submitProof, proofLinks
        case cancelInvitation, fullyBooked, awaitingApproval, membershipPaused
        case eventRSVP, giftDelivery, guestCountLabel
        // Profile
        case followers, profileHealth, management, venueStudio, adminConsole
        case member, creator, saveToAccount, syncFromServer, signingOut
        case signOutTitle, signOutMessage, applicationChecklist, instagramConnected
        case cityVerified, nichesSet, creatorReferences, membershipApproved
        case accountSection, accountSectionSub, pauseAccount, pauseAccountSub
        case reactivateAccount, deleteAccountForever, deleteAccountSub
        case pauseConfirmTitle, pauseConfirmMessage, deleteConfirmTitle, deleteConfirmMessage
        case typeDeleteHint, accountPausedMessage, legalSection, settingsSection
        case pushNotifications, proofReminders, autoSaveProofLinks, languageLabel
        case deleteOnWeb, helpSupport, emailSupport, reportSafety
        case underReviewBanner, underReviewBannerSub, approvedBanner, approvedBannerSub
        case pausedSelfBanner, pausedSelfBannerSub, pausedAdminBanner, pausedAdminBannerSub
        case reactivateMyAccount
        // Inbox / reauth
        case inboxTitle, inboxEmpty, inboxSub, inboxLoading, openAction
        case welcomeBack, signInToContinue, forgotPasswordEmail
        // Membership status labels
        case statusUnderReview, statusApproved, statusPaused
        // Booking stages
        case stageInvited, stageConfirmed, stageCheckedIn, stageProofDue, stageCompleted, stageCancelled
        // Roles
        case roleCreator, roleVenue, roleAdmin
        // Collaboration models
        case modelInvitation, modelEvent, modelGift, modelInstant
        // Errors (user-facing)
        case errSessionExpired, errSignInRequired, errWrongPassword, errAccountExists
        case errInviteInvalid, errInviteFull, errCheckInInvalid, errProfileNotReady
        case errReactivateSupport, errEnterEmail, errTypeDelete, errSomeDataRefresh
        case errInvitationFull, errAlreadyAccepted, errNotAuthenticated, errConfirmEmail
        // Misc
        case openAdminConsole, bootstrapLoading, syncErrorTitle, hiGreeting
        case saveProfile, mapLocationNeeded, enableLocation, instantNearby
        case upcomingEventsIn, upNextInCity, venueWorkspaceNote
        // Profile extended
        case workspace, workspaceAdminSub, workspaceSwitchSub, adminConsoleSub
        case openTasks, liveOffers, creatorSignals, creatorSignalsSub
        case scoreLabel, deliveryLabel, strikeHistory, strikeHistorySub
        case socialAccounts, socialAccountsSub, displayName, bio, cityField, tiktokHandleField
        case handleEmpty
        case changeAvatar, changeCover
        case nichesComma, languagesComma, openInstagram, openTiktok
        case profileSavedSuccess, saving, checklistProgress
        case nicheSelected, audienceReviewed, agreementSigned
        case tiktokConnected, inviteFriends, inviteFriendsSub, inviteEmailPlaceholder
        case sendInviteBtn, inviteSentSuccess, socialSetupTitle, socialSetupSub, socialSetupContinue
        case errInviteEmailMismatch
        case signedIn, notSignedIn, developer, debugBuildsOnly, reactivating
        case closeAccountBtn, deleteForeverBtn, unreadSuffix, settingsSub
        case privacyPolicy, termsOfService, communityGuidelines, legalSectionSub
        // Bookings extended
        case myEventsSub, pendingInvites, interestShown, decline, accept
        case noInterestShown, saveEventsExploreSub
        case noPendingInvites, nothingToConfirm, nothingToReview, noVisitsScheduled
        case emptyRequestsSub, emptyConfirmSub, emptyReviewSub, emptyVisitSub
        case categoryLabel
        case checkInAtVenue, checkInSheetSub, checkInCode, checkingIn, confirmCheckIn, checkInNav
        case submitProofTitle, submitProofSub, attachScreenshot, submitting, sendToReview, proofNav
        case timelineConfirm, timelineCheckIn, timelineProof, addProof
        // Offer detail
        case eventRSVPSub, giftDeliverySub, campaignBrief
        case metricDate, metricTime, creatorValue, openSlots, capacity
        case creatorsConfirmed, percentFilled, deliverables, requirements, hostNote
        case acceptanceTerms, termAttendance, termAttendanceVal, termContent, termContentVal
        case termPolicy, termPolicyVal, cancelInvitationQ, keepBtn, venueNotifiedCancel
        case pleaseWait, confirmedStatus, matchPercent, slotsLeft, extrasRequiredSub
        case featuredEvent, featuredEvents, sortEvents, loadingEvents, noEventsYet
        case fetchingLive, newVenueInvites, searchVenuePrompt
        // Map & misc UI
        case now, details, eventsFound, loadingWorkspace, configurationRequired, configurationSub
        // Admin / venue studio
        case strikePolicyMessage, updating, loadingApplicant, applicantProfile
        case reviewContext, noLinksYet, campaignDetails, createAccountDirect, sendInviteEmail
        case actionsLabel, liveMap, liveMapLegend, radiusLabel, enableLocationBroadcast
        case manageEvents, atEstablishments, liveCampaign, creatorsLeft, loadingCreators
        case reviewLabel, checkedInAt, collaborationModelLabel, creatorSlotsCount
        // Admin extended
        case confirm, issueStrike, reasonLabel, issueStrikeTitle, strikeDefaultReason
        case operationsCommand, adminControl, adminControlSub
        case usersLabel, bookingsLabel, strikesLabel, reviewQueue, reviewQueueSub
        case adminTabQueue, adminTabUsers, adminTabMap, adminTabBroadcast
        case studioUnderReview, studioUpcoming, studioOpenSwipe, studioHappening, studioPast, studioCreate
        case profileEngagement
        case geoBroadcast, geoBroadcastSub, sendToArea, locationUnavailable
        case inviteEmailQueued, noUsersLoaded, noUsersLoadedSub, searchUsersPrompt
        case approve, block, approvedMsg, accountBlocked
        case sendInAppNotification, sendEmailBtn, notificationSent, emailQueued
        case loadingProfile, roleLabel, referralLabel, instagramLabel, lastLocationLabel, notSharedYet
        case statusField, notificationTitlePh, notificationBodyPh, emailSubjectPh, emailBodyPh
        case liveMapStats, noEmail, liveStatusLabel
        // Venue studio extended
        case venuePartnerWorkspace, reviewCreators, campaigns, campaignsSub
        case brandPartners, brandPartnersSub, noBrandCampaigns, noBrandCampaignsSub
        case toReviewVenueSub, noReviewsTab, noReviewsTabSub
        case creatorMatching, shortlistComplete, noCreatorsMatch, noCreatorsMatchSub, allReviewedSub
        case visitLabel, shareThoughts, shareThoughtsSub, punctuality, presentation, optionalNote
        case hospitality, experience
        case reviewAlreadySubmitted, submitReview, creatorReviewNav
        case newCampaign, newCampaignSub, campaignTitlePh, venueNamePh, areaPh, eventDateLabel
        case valuePh, deliverablesPh, sendToAdminReview, createNav
        case segmentCheckedIn, segmentCheckedOut, segmentNoShow, tabEstablishments, tabBrands
        case followersCount, creatorSlotsVenue
        case myLocations, myLocationsSub, addLocation, addLocationSub, selectLocation
        case locationPendingReview, locationTypeLabel, addressOptional, contactPhoneOptional
        // AppState errors
        case errServerSetupReferral, errServerSetupMultiVenue, errAppleSignInUnavailable, errServerConfig
        case errAdminAccessDisabled, errNoLinkedBooking, errSignInCheckIn
        case errEnterCheckInCode, errEnterInviteCode, errSignInRedeemInvite
        case errSignInSubmitProof, errUploadScreenshot, errAddProofLink
        case errAdminRequired, errNoUsersInArea, errSentToUsers
    }

    private static let english: [Key: String] = [
        .ok: "OK", .cancel: "Cancel", .close: "Close", .done: "Done",
        .continueAction: "Continue", .save: "Save", .delete: "Delete",
        .retry: "Retry", .refresh: "Refresh", .loading: "Loading…",
        .email: "Email", .password: "Password", .signIn: "Sign in", .signOut: "Sign out",
        .signUp: "Sign up", .forgotPassword: "Forgot password?",
        .deleteConfirmWord: "DELETE",
        .explore: "Explore", .myEvents: "My Events", .profile: "Profile",
        .studio: "Studio", .inbox: "Inbox", .account: "Account", .admin: "Admin",
        .heroLine1: "Do what you can't", .heroLine2: "with Marvi Society",
        .heroSubtitle: "Istanbul's invite-only club for creators and venues. Curated events, structured proof, trusted matching.",
        .getStarted: "Get started", .alreadyMemberSignIn: "Already a member? Sign in",
        .when: "When", .whereAxis: "Where", .eventTypeAxis: "Event type",
        .featApprovedTitle: "Approved members only",
        .featApprovedSub: "Every creator application is reviewed by our team.",
        .featVenuesTitle: "Premium venue experiences",
        .featVenuesSub: "Dining, nightlife, wellness, and more.",
        .featProofTitle: "Proof that protects venues",
        .featProofSub: "Submit content links after each collaboration.",
        .step1of4: "Step 1 of 4", .step2of4: "Step 2 of 4",
        .step3of4: "Step 3 of 4", .step4of4: "Step 4 of 4",
        .createAccount: "Create your account", .signInContinue: "Sign in to continue",
        .welcomeBackSignIn: "Welcome back — enter your email and password.",
        .createAccountSub: "Full name, email, and password. Invite code and profile come next.",
        .signInSub: "Welcome back — enter your email and password.",
        .orEmail: "or email", .orAppleSignIn: "or Apple", .orContinueWith: "or continue with",
        .newMemberCreate: "New member? Create account",
        .alreadyMemberToggle: "Already a member? Sign in",
        .forgotPasswordReset: "Forgot password? Reset via email",
        .accountExistsTitle: "This email is already registered.",
        .signInToAccount: "Sign in to your account",
        .signInWithApple: "Sign in with Apple", .signInWithGoogle: "Continue with Google", .signingIn: "Signing in…",
        .appleDevNotice: "Sign in with Apple needs an active Apple Developer account ($99/yr). Until then, use email to create an account and sign in.",
        .emailSignInRecommended: "Sign in with the email and password for your Marvi account.",
        .inviteTitle: "Enter your invite code",
        .inviteSubtitle: "Marvi Society is invite-only. Ask your curator or venue partner for a code.",
        .invitePlaceholder: "e.g. MARVI-IST or TURGUT",
        .inviteAccepted: "Invite code accepted",
        .memberBenefits: "Member benefits",
        .featCuratedTitle: "Curated invitations",
        .featCuratedSub: "Access live campaigns matched to your niche.",
        .profileSetupTitle: "Your creator profile",
        .profileSetupSub: "Used for verification and invitation matching.",
        .fullNamePlaceholder: "Full name",
        .instagramPlaceholder: "Instagram handle", .cityPlaceholder: "City",
        .yourNiches: "Your niches", .popularCities: "Popular cities",
        .agreementTitle: "Membership agreement",
        .agreementSub: "Required before entering the club.",
        .age18Toggle: "I am 18 years of age or older.",
        .termsToggle: "I agree to the Terms of Service, Privacy Policy, and Community Guidelines.",
        .joinMarvi: "Join Marvi Society",
        .welcome: "Welcome", .signInStep: "Sign in", .inviteStep: "Invite",
        .profileStep: "Profile", .agreementStep: "Agreement",
        .validatingInvite: "Validating invite code…",
        .settingUpAccount: "Setting up your account…",
        .checkEmailTitle: "Check your email",
        .passwordResetDefault: "If an account exists for this email, we sent a password reset link.",
        .passwordResetInstructions: "Open the email on this device, tap the link, then set a new password on marvisociety.com. Return here and sign in.",
        .privateAccess: "Private access", .yourCity: "Your city",
        .findExploreEvents: "Find and Explore Events", .eventsCount: "events",
        .filterAll: "All", .filterSaved: "Saved", .filterFewSlots: "Few slots",
        .sortNewest: "Newest", .sortFewSlots: "Few slots", .sortBestMatch: "Best match",
        .listMode: "List", .mapMode: "Map",
        .tonight: "Tonight", .thisWeek: "This week", .weekend: "Weekend",
        .filters: "Filters", .sortBy: "Sort by", .location: "Location", .date: "Date",
        .anyWhen: "Any when", .anyWhere: "Any where", .anyType: "Any type",
        .searchEvents: "Search events", .noEventsTitle: "No events match",
        .noEventsSub: "Try changing filters or check back later.",
        .viewEventBrief: "View event brief", .nearYou: "Near you",
        .dining: "Dining", .nightlife: "Nightlife", .wellness: "Wellness",
        .beauty: "Beauty", .fitness: "Fitness", .retail: "Retail",
        .acceptInvitation: "Accept invitation", .rsvpEvent: "Confirm RSVP",
        .confirmGift: "Confirm gift delivery", .useNow: "Use now",
        .shippingAddress: "Shipping address", .guestCount: "Guest count",
        .myEventsTitle: "My events", .requests: "Requests", .toConfirm: "To confirm",
        .toReview: "To review", .toVisit: "To visit", .completed: "Completed",
        .noBookings: "No events yet", .noBookingsSub: "Accepted invitations appear here.",
        .checkIn: "Check in", .submitProof: "Submit proof", .proofLinks: "Proof links",
        .cancelInvitation: "Cancel invitation", .fullyBooked: "Fully booked",
        .awaitingApproval: "Awaiting approval", .membershipPaused: "Membership paused",
        .eventRSVP: "Event RSVP", .giftDelivery: "Gift delivery",
        .guestCountLabel: "Guest count",
        .followers: "Followers", .profileHealth: "Profile Health",
        .management: "Management", .venueStudio: "Venue studio", .adminConsole: "Admin console",
        .member: "Member", .creator: "Creator",
        .saveToAccount: "Save to account", .syncFromServer: "Sync from server",
        .signingOut: "Signing out…",
        .signOutTitle: "Sign out?", .signOutMessage: "You will need to sign in again with your email and password.",
        .applicationChecklist: "Application checklist",
        .instagramConnected: "Instagram connected", .cityVerified: "City verified",
        .nichesSet: "Niches selected", .creatorReferences: "Creator references",
        .membershipApproved: "Membership approved",
        .accountSection: "Account",
        .accountSectionSub: "Temporarily pause or permanently delete your membership.",
        .pauseAccount: "Temporarily close account",
        .pauseAccountSub: "Pause hides you from invitations and cancels pending bookings. Your profile stays saved.",
        .reactivateAccount: "Reactivate account",
        .deleteAccountForever: "Permanently delete account",
        .deleteAccountSub: "This removes your profile, bookings, and login permanently.",
        .pauseConfirmTitle: "Temporarily close account?",
        .pauseConfirmMessage: "Your membership will be paused, pending invitations cancelled, and push notifications stopped. You can reactivate later without losing your profile.",
        .deleteConfirmTitle: "Permanently delete account?",
        .deleteConfirmMessage: "This removes your profile, bookings, and login permanently. This cannot be undone.",
        .typeDeleteHint: "Type DELETE to confirm permanent deletion.",
        .accountPausedMessage: "Account paused. You can reactivate from Profile anytime.",
        .legalSection: "Legal & account", .settingsSection: "Settings",
        .pushNotifications: "Push notifications", .proofReminders: "Proof deadline reminders",
        .autoSaveProofLinks: "Auto-save proof links", .languageLabel: "Language",
        .deleteOnWeb: "Delete account on web", .helpSupport: "Help & support",
        .emailSupport: "Email support", .reportSafety: "Report a safety issue",
        .underReviewBanner: "Application under review",
        .underReviewBannerSub: "You can browse events while we verify your profile. Accepting invitations may be limited until approval.",
        .approvedBanner: "Membership approved",
        .approvedBannerSub: "Your creator profile is active. Accept invitations and submit proof after each visit.",
        .pausedSelfBanner: "Account temporarily closed",
        .pausedSelfBannerSub: "You paused your account. Reactivate anytime from Profile. Pending invitations were cancelled.",
        .pausedAdminBanner: "Membership paused",
        .pausedAdminBannerSub: "Your account was paused by our team. Contact support to restore access.",
        .reactivateMyAccount: "Reactivate my account",
        .inboxTitle: "Inbox", .inboxEmpty: "Inbox is clear",
        .inboxSub: "Campaign updates, proof reminders, and admin messages.",
        .inboxLoading: "Fetching your latest notifications.",
        .openAction: "Open",
        .welcomeBack: "Welcome back", .signInToContinue: "Sign in with your email and password to continue.",
        .forgotPasswordEmail: "Forgot password? Reset via email",
        .statusUnderReview: "Under review", .statusApproved: "Approved", .statusPaused: "Paused",
        .stageInvited: "Invited", .stageConfirmed: "Confirmed", .stageCheckedIn: "Checked in",
        .stageProofDue: "Proof due", .stageCompleted: "Completed", .stageCancelled: "Cancelled",
        .roleCreator: "Creator", .roleVenue: "Venue", .roleAdmin: "Admin",
        .modelInvitation: "Invitation", .modelEvent: "Event", .modelGift: "Gift", .modelInstant: "Instant",
        .errSessionExpired: "Your session expired. Please sign in again.",
        .errSignInRequired: "Please sign in to continue.",
        .errWrongPassword: "Incorrect email or password. Try again or reset your password.",
        .errAccountExists: "An account with this email already exists. Sign in instead, or reset your password if you forgot it.",
        .errInviteInvalid: "Invite code not recognized. Ask your curator for a valid code.",
        .errInvitationFull: "This invitation is full. Try another event.",
        .errCheckInInvalid: "Invalid check-in code. Ask the venue host for the correct code.",
        .errProfileNotReady: "Your creator profile is not set up yet. Contact support.",
        .errReactivateSupport: "This account was paused by our team. Email support@marvisociety.com to restore access.",
        .errEnterEmail: "Enter your email address first.",
        .errTypeDelete: "Type DELETE to confirm permanent deletion.",
        .errSomeDataRefresh: "Some data could not be refreshed. Pull down to try again.",
        .errAlreadyAccepted: "You already accepted this invitation.",
        .errNotAuthenticated: "Please sign in to continue.",
        .errConfirmEmail: "We sent a confirmation link to your email. Open it to verify your account, then come back and sign in.",
        .openAdminConsole: "Open admin console",
        .bootstrapLoading: "Loading your club…",
        .syncErrorTitle: "Could not sync",
        .hiGreeting: "Hi",
        .saveProfile: "Save to account",
        .mapLocationNeeded: "Turn on location to see nearby instant offers.",
        .enableLocation: "Enable location",
        .instantNearby: "Instant offers nearby",
        .upcomingEventsIn: "Upcoming Events in",
        .upNextInCity: "Upcoming Events in",
        .venueWorkspaceNote: "Venue and admin workspaces unlock automatically based on your account role.",
        .workspace: "Workspace",
        .workspaceAdminSub: "Admin access enabled on this account.",
        .workspaceSwitchSub: "Switch between creator, venue, and admin tools.",
        .adminConsoleSub: "Review creator applications, campaigns, and proof.",
        .openTasks: "Open tasks", .liveOffers: "Live offers",
        .creatorSignals: "Creator signals", .creatorSignalsSub: "Used for invitation matching.",
        .scoreLabel: "Score", .deliveryLabel: "Delivery",
        .strikeHistory: "Strike history", .strikeHistorySub: "Policy violations affect matching priority.",
        .socialAccounts: "Social accounts", .socialAccountsSub: "Linked profiles for verification and proof tracking.",
        .changeAvatar: "Profile photo", .changeCover: "Cover image",
        .displayName: "Display name", .bio: "Bio", .cityField: "City", .tiktokHandleField: "TikTok handle",
        .handleEmpty: "@add your handle",
        .nichesComma: "Niches (comma separated)", .languagesComma: "Languages (comma separated)",
        .openInstagram: "Open Instagram profile", .openTiktok: "Open TikTok profile",
        .profileSavedSuccess: "Profile saved to your account.", .saving: "Saving…",
        .checklistProgress: "of 7 steps complete",
        .nicheSelected: "Niche selected", .audienceReviewed: "Audience reviewed", .agreementSigned: "Agreement signed",
        .tiktokConnected: "TikTok connected",
        .inviteFriends: "Invite a creator",
        .inviteFriendsSub: "Send a single-use invite to their email. They must sign up with that address.",
        .inviteEmailPlaceholder: "Friend's email",
        .sendInviteBtn: "Send invite email",
        .inviteSentSuccess: "Invite sent — they'll receive an email with their code.",
        .socialSetupTitle: "Link your social accounts",
        .socialSetupSub: "Instagram and TikTok are required for verification and invite matching.",
        .socialSetupContinue: "Save and continue",
        .errInviteEmailMismatch: "This invite was sent to a different email. Sign in with the invited address.",
        .signedIn: "Signed in", .notSignedIn: "Not signed in",
        .developer: "Developer", .debugBuildsOnly: "Debug builds only.",
        .reactivating: "Reactivating…", .closeAccountBtn: "Close account", .deleteForeverBtn: "Delete forever",
        .unreadSuffix: "unread", .settingsSub: "Preferences saved on this device.",
        .privacyPolicy: "Privacy Policy", .termsOfService: "Terms of Service",
        .communityGuidelines: "Community Guidelines", .legalSectionSub: "Policies required for App Store review.",
        .myEventsSub: "Your events organized",
        .pendingInvites: "Pending Invites", .interestShown: "Interest Shown",
        .decline: "Decline", .accept: "Accept",
        .noInterestShown: "No interest shown", .saveEventsExploreSub: "Save events from Explore to track them here.",
        .noPendingInvites: "No pending invites", .nothingToConfirm: "Nothing to confirm",
        .nothingToReview: "Nothing to review", .noVisitsScheduled: "No visits scheduled",
        .emptyRequestsSub: "When a venue invites you directly, it appears here.",
        .emptyConfirmSub: "Confirmed visits waiting for your check-in show here.",
        .emptyReviewSub: "Submit proof after your visit to move events forward.",
        .emptyVisitSub: "Checked-in collaborations appear here until proof is due.",
        .categoryLabel: "Category",
        .checkInAtVenue: "Check in at venue",
        .checkInSheetSub: "Enter the code shown by staff or use your booking reference.",
        .checkInCode: "Check-in code", .checkingIn: "Checking in…",
        .confirmCheckIn: "Confirm check-in", .checkInNav: "Check in",
        .submitProofTitle: "Submit proof",
        .submitProofSub: "Paste Instagram or TikTok links for %@.",
        .attachScreenshot: "Attach screenshot", .submitting: "Submitting…",
        .sendToReview: "Send to review", .proofNav: "Proof",
        .timelineConfirm: "Confirm", .timelineCheckIn: "Check in", .timelineProof: "Proof", .addProof: "Add proof",
        .eventRSVPSub: "Your attendance is reserved against venue capacity.",
        .giftDeliverySub: "A shipping address is required when you confirm.",
        .campaignBrief: "Campaign brief", .metricDate: "date", .metricTime: "time",
        .creatorValue: "creator value", .openSlots: "open slots", .capacity: "Capacity",
        .creatorsConfirmed: "%d creators confirmed", .percentFilled: "%d%% filled",
        .deliverables: "Deliverables", .requirements: "Requirements", .hostNote: "Host note",
        .acceptanceTerms: "Acceptance terms",
        .termAttendance: "Attendance", .termAttendanceVal: "Arrive within the confirmed window.",
        .termContent: "Content", .termContentVal: "Deliver all agreed links before the proof deadline.",
        .termPolicy: "Policy", .termPolicyVal: "No private guest filming without consent.",
        .cancelInvitationQ: "Cancel this invitation?", .keepBtn: "Keep",
        .venueNotifiedCancel: "The venue will be notified and your slot may be released.",
        .pleaseWait: "Please wait…", .confirmedStatus: "Confirmed",
        .matchPercent: "%d%% match", .slotsLeft: "%d slots left",
        .extrasRequiredSub: "Required before confirming this collaboration.",
        .featuredEvent: "Featured Event", .featuredEvents: "Featured Events",
        .sortEvents: "Sort events", .loadingEvents: "Loading events…", .noEventsYet: "No events yet",
        .fetchingLive: "Fetching live campaigns from the server.",
        .newVenueInvites: "New venue invitations appear here when published for %@. Pull down to refresh.",
        .searchVenuePrompt: "Venue, area, category",
        .now: "Now", .details: "Details", .eventsFound: "%d Events found",
        .loadingWorkspace: "Loading your workspace…",
        .configurationRequired: "Configuration required",
        .configurationSub: "Copy Config/Secrets.xcconfig.example to Secrets.xcconfig and add your Supabase project URL and anon key.",
        .strikePolicyMessage: "This records a policy strike against the creator linked to this booking.",
        .updating: "Updating…", .loadingApplicant: "Loading applicant details…",
        .applicantProfile: "Applicant profile", .reviewContext: "Review context",
        .noLinksYet: "No links attached yet.", .campaignDetails: "Campaign details",
        .createAccountDirect: "Create account directly", .sendInviteEmail: "Send invite email",
        .actionsLabel: "Actions", .liveMap: "Live map",
        .liveMapLegend: "Rose = creators with shared location. Gold = venues/offers.",
        .radiusLabel: "Radius", .enableLocationBroadcast: "Enable location on this device to use your position as the broadcast center.",
        .manageEvents: "Manage your events", .atEstablishments: "at your establishments",
        .liveCampaign: "Live campaign", .creatorsLeft: "%d creators left",
        .loadingCreators: "Loading creators…", .reviewLabel: "Review",
        .checkedInAt: "Checked in %@", .collaborationModelLabel: "Collaboration model",
        .creatorSlotsCount: "Creator slots: %d",
        .confirm: "Confirm", .issueStrike: "Issue strike", .reasonLabel: "Reason",
        .issueStrikeTitle: "Issue strike", .strikeDefaultReason: "Proof not delivered per campaign terms",
        .operationsCommand: "Operations command", .adminControl: "Admin control",
        .adminControlSub: "Review applications, campaigns, proof submissions, and operational risk.",
        .usersLabel: "Users", .bookingsLabel: "Bookings", .strikesLabel: "Strikes",
        .reviewQueue: "Review queue", .reviewQueueSub: "Approve or reject items before they go live.",
        .adminTabQueue: "Queue", .adminTabUsers: "Users", .adminTabMap: "Map", .adminTabBroadcast: "Broadcast",
        .studioUnderReview: "Under\nReview", .studioUpcoming: "Upcoming\nEvents", .studioOpenSwipe: "Open for\nswipe",
        .studioHappening: "Happening", .studioPast: "Past", .studioCreate: "Create",
        .profileEngagement: "Engagement",
        .geoBroadcast: "Geo broadcast",
        .geoBroadcastSub: "Send an in-app notification to approved users whose last shared location is within the radius.",
        .sendToArea: "Send to area", .locationUnavailable: "Location unavailable.",
        .inviteEmailQueued: "Invite email queued.", .noUsersLoaded: "No users loaded",
        .noUsersLoadedSub: "Run apply-admin-operations.sql in Supabase, then pull to refresh.",
        .searchUsersPrompt: "Email, name, city, handle",
        .approve: "Approve", .block: "Block", .approvedMsg: "Approved.", .accountBlocked: "Account blocked.",
        .sendInAppNotification: "Send in-app notification", .sendEmailBtn: "Send email",
        .notificationSent: "Notification sent.", .emailQueued: "Email queued.",
        .loadingProfile: "Loading profile…", .roleLabel: "Role", .referralLabel: "Referral",
        .instagramLabel: "Instagram", .lastLocationLabel: "Last location", .notSharedYet: "Not shared yet",
        .statusField: "Status", .notificationTitlePh: "Notification title", .notificationBodyPh: "Notification body",
        .emailSubjectPh: "Email subject", .emailBodyPh: "Email body",
        .liveMapStats: "%d creators · %d live offers", .noEmail: "No email", .liveStatusLabel: "Live",
        .venuePartnerWorkspace: "Venue partner workspace", .reviewCreators: "Review creators",
        .campaigns: "Campaigns", .campaignsSub: "%d active in this workspace",
        .brandPartners: "Brand partners", .brandPartnersSub: "Campaigns linked to your venue workspace.",
        .noBrandCampaigns: "No brand campaigns yet",
        .noBrandCampaignsSub: "Submit a campaign for admin review to publish on Explore.",
        .toReviewVenueSub: "Share your thoughts after creator visits.",
        .noReviewsTab: "No reviews in this tab", .noReviewsTabSub: "Creators appear here after check-in or checkout.",
        .creatorMatching: "Creator matching", .shortlistComplete: "Shortlist complete",
        .noCreatorsMatch: "No creators to match",
        .noCreatorsMatchSub: "When your campaign is live, creator applications will appear here for swiping.",
        .allReviewedSub: "All creators in this batch have been reviewed.",
        .visitLabel: "Visit", .shareThoughts: "Share your thoughts",
        .shareThoughtsSub: "Rate punctuality and presentation.",
        .punctuality: "Punctuality", .presentation: "Presentation", .optionalNote: "Optional note",
        .hospitality: "Hospitality", .experience: "Experience",
        .reviewAlreadySubmitted: "Review already submitted — saving again will update it.",
        .submitReview: "Submit review", .creatorReviewNav: "Creator review",
        .newCampaign: "New campaign", .newCampaignSub: "Submitted for admin review before going live.",
        .campaignTitlePh: "Campaign title", .venueNamePh: "Venue name", .areaPh: "Area",
        .eventDateLabel: "Event date", .valuePh: "Value (e.g. Dinner for 2)",
        .deliverablesPh: "Deliverables, comma separated",
        .sendToAdminReview: "Send to admin review", .createNav: "Create",
        .segmentCheckedIn: "Checked in", .segmentCheckedOut: "Checked out", .segmentNoShow: "No show",
        .tabEstablishments: "Establishments", .tabBrands: "Brands",
        .followersCount: "%d followers", .creatorSlotsVenue: "%@ · %d creator slots",
        .myLocations: "Your locations", .myLocationsSub: "One account — manage every venue, shop, or brand.",
        .addLocation: "Add location", .addLocationSub: "Submit a new place for admin review. No extra account needed.",
        .selectLocation: "Active location", .locationPendingReview: "Pending review",
        .locationTypeLabel: "Type", .addressOptional: "Address (optional)", .contactPhoneOptional: "Contact phone (optional)",
        .errServerSetupReferral: "Server setup incomplete. Run apply-referral-fix.sql in Supabase.",
        .errServerSetupMultiVenue: "Server setup incomplete. Run apply-multi-venue.sql in Supabase.",
        .errAppleSignInUnavailable: "Sign in with Apple is not available on this build. Use email sign-in.",
        .errServerConfig: "Server configuration error. Check Supabase anon key in Secrets.xcconfig.",
        .errAdminAccessDisabled: "Admin access is not enabled. Sign in, run grant-admin SQL in Supabase, then tap Sync from server.",
        .errNoLinkedBooking: "This task has no linked booking.",
        .errSignInCheckIn: "Please sign in to check in.",
        .errEnterCheckInCode: "Enter the check-in code from the venue host.",
        .errEnterInviteCode: "Enter a valid invite code.",
        .errSignInRedeemInvite: "Sign in before redeeming your invite.",
        .errSignInSubmitProof: "Please sign in to submit proof.",
        .errUploadScreenshot: "Could not upload screenshot.",
        .errAddProofLink: "Add at least one proof link or screenshot.",
        .errAdminRequired: "Admin access required.",
        .errNoUsersInArea: "No approved users with recent location in this area.",
        .errSentToUsers: "Sent to %d user(s) within %d km."
    ]

    private static let turkish: [Key: String] = [
        .ok: "Tamam", .cancel: "İptal", .close: "Kapat", .done: "Bitti",
        .continueAction: "Devam", .save: "Kaydet", .delete: "Sil",
        .retry: "Tekrar dene", .refresh: "Yenile", .loading: "Yükleniyor…",
        .email: "E-posta", .password: "Şifre", .signIn: "Giriş yap", .signOut: "Çıkış yap",
        .signUp: "Kayıt ol", .forgotPassword: "Şifreni mi unuttun?",
        .deleteConfirmWord: "SİL",
        .explore: "Keşfet", .myEvents: "Etkinliklerim", .profile: "Profil",
        .studio: "Stüdyo", .inbox: "Gelen Kutusu", .account: "Hesap", .admin: "Yönetim",
        .heroLine1: "Hayal ettiğini yaşa", .heroLine2: "Marvi Society ile",
        .heroSubtitle: "İstanbul'un davetiye usulü creator × mekân kulübü. Küratörlü etkinlikler, kanıt akışı, güvenilir eşleşme.",
        .getStarted: "Başla", .alreadyMemberSignIn: "Zaten üye misin? Giriş yap",
        .when: "Ne zaman", .whereAxis: "Nerede", .eventTypeAxis: "Etkinlik türü",
        .featApprovedTitle: "Sadece onaylı üyeler",
        .featApprovedSub: "Her creator başvurusu ekibimiz tarafından incelenir.",
        .featVenuesTitle: "Seçkin mekân deneyimleri",
        .featVenuesSub: "Yemek, gece hayatı, wellness ve daha fazlası.",
        .featProofTitle: "Mekânları koruyan kanıt",
        .featProofSub: "Her iş birliğinden sonra içerik linklerini gönder.",
        .step1of4: "Adım 1 / 4", .step2of4: "Adım 2 / 4",
        .step3of4: "Adım 3 / 4", .step4of4: "Adım 4 / 4",
        .createAccount: "Hesabını oluştur", .signInContinue: "Devam etmek için giriş yap",
        .welcomeBackSignIn: "Tekrar hoş geldin — e-posta ve şifreni gir.",
        .createAccountSub: "Ad soyad, e-posta ve şifre. Davet kodu ve profil sonraki adımlarda.",
        .signInSub: "Tekrar hoş geldin — e-posta ve şifreni gir.",
        .orEmail: "veya e-posta", .orAppleSignIn: "veya Apple", .orContinueWith: "veya şununla devam et",
        .newMemberCreate: "Yeni üye misin? Hesap oluştur",
        .alreadyMemberToggle: "Zaten üye misin? Giriş yap",
        .forgotPasswordReset: "Şifreni mi unuttun? E-posta ile sıfırla",
        .accountExistsTitle: "Bu e-posta zaten kayıtlı.",
        .signInToAccount: "Hesabına giriş yap",
        .signInWithApple: "Apple ile giriş yap", .signInWithGoogle: "Google ile devam et", .signingIn: "Giriş yapılıyor…",
        .appleDevNotice: "Apple ile giriş için aktif Apple Developer hesabı ($99/yıl) gerekir. Şimdilik e-posta ile hesap oluşturup giriş yapabilirsin.",
        .emailSignInRecommended: "Marvi hesabınızın e-posta adresi ve şifresi ile giriş yapın.",
        .inviteTitle: "Davet kodunu gir",
        .inviteSubtitle: "Marvi Society davetiye usulüdür. Küratöründen veya mekân partnerinden kod iste.",
        .invitePlaceholder: "ör. MARVI-IST veya TURGUT",
        .inviteAccepted: "Davet kodu kabul edildi",
        .memberBenefits: "Üyelik avantajları",
        .featCuratedTitle: "Küratörlü davetler",
        .featCuratedSub: "Nişine uygun canlı kampanyalara eriş.",
        .profileSetupTitle: "Creator profilin",
        .profileSetupSub: "Doğrulama ve davet eşleşmesi için kullanılır.",
        .fullNamePlaceholder: "Ad soyad",
        .instagramPlaceholder: "Instagram kullanıcı adı", .cityPlaceholder: "Şehir",
        .yourNiches: "Nişlerin", .popularCities: "Popüler şehirler",
        .agreementTitle: "Üyelik sözleşmesi",
        .agreementSub: "Kulübe girmeden önce zorunludur.",
        .age18Toggle: "18 yaşında veya daha büyüğüm.",
        .termsToggle: "Kullanım Koşulları, Gizlilik Politikası ve Topluluk Kuralları'nı kabul ediyorum.",
        .joinMarvi: "Marvi Society'ye katıl",
        .welcome: "Hoş geldin", .signInStep: "Giriş", .inviteStep: "Davet",
        .profileStep: "Profil", .agreementStep: "Sözleşme",
        .validatingInvite: "Davet kodu doğrulanıyor…",
        .settingUpAccount: "Hesabın hazırlanıyor…",
        .checkEmailTitle: "E-postanı kontrol et",
        .passwordResetDefault: "Bu e-postayla kayıtlı bir hesap varsa şifre sıfırlama linki gönderdik.",
        .passwordResetInstructions: "E-postayı bu cihazda aç, linke dokun ve marvisociety.com üzerinde yeni şifreni belirle. Sonra buraya dönüp giriş yap.",
        .privateAccess: "Özel erişim", .yourCity: "Şehrin",
        .findExploreEvents: "Etkinlikleri Keşfet", .eventsCount: "etkinlik",
        .filterAll: "Tümü", .filterSaved: "Kaydedilenler", .filterFewSlots: "Az kontenjan",
        .sortNewest: "En yeni", .sortFewSlots: "Az kontenjan", .sortBestMatch: "En iyi eşleşme",
        .listMode: "Liste", .mapMode: "Harita",
        .tonight: "Bu gece", .thisWeek: "Bu hafta", .weekend: "Hafta sonu",
        .filters: "Filtreler", .sortBy: "Sırala", .location: "Konum", .date: "Tarih",
        .anyWhen: "Her zaman", .anyWhere: "Her yer", .anyType: "Her tür",
        .searchEvents: "Etkinlik ara", .noEventsTitle: "Eşleşen etkinlik yok",
        .noEventsSub: "Filtreleri değiştir veya daha sonra tekrar bak.",
        .viewEventBrief: "Etkinlik detayına bak", .nearYou: "Yakınında",
        .dining: "Yemek", .nightlife: "Gece hayatı", .wellness: "Wellness",
        .beauty: "Güzellik", .fitness: "Fitness", .retail: "Perakende",
        .acceptInvitation: "Daveti kabul et", .rsvpEvent: "RSVP onayla",
        .confirmGift: "Hediye gönderimini onayla", .useNow: "Hemen kullan",
        .shippingAddress: "Teslimat adresi", .guestCount: "Misafir sayısı",
        .myEventsTitle: "Etkinliklerim", .requests: "Talepler", .toConfirm: "Onaylanacak",
        .toReview: "İncelenecek", .toVisit: "Ziyaret", .completed: "Tamamlanan",
        .noBookings: "Henüz etkinlik yok", .noBookingsSub: "Kabul ettiğin davetler burada görünür.",
        .checkIn: "Check-in yap", .submitProof: "Kanıt gönder", .proofLinks: "Kanıt linkleri",
        .cancelInvitation: "Daveti iptal et", .fullyBooked: "Kontenjan doldu",
        .awaitingApproval: "Onay bekleniyor", .membershipPaused: "Üyelik duraklatıldı",
        .eventRSVP: "Etkinlik RSVP", .giftDelivery: "Hediye gönderimi",
        .guestCountLabel: "Misafir sayısı",
        .followers: "Takipçi", .profileHealth: "Profil Sağlığı",
        .management: "Yönetim", .venueStudio: "Mekân stüdyosu", .adminConsole: "Yönetim konsolu",
        .member: "Üye", .creator: "Creator",
        .saveToAccount: "Hesaba kaydet", .syncFromServer: "Sunucudan senkronize et",
        .signingOut: "Çıkış yapılıyor…",
        .signOutTitle: "Çıkış yap?", .signOutMessage: "Devam etmek için e-posta ve şifrenle tekrar giriş yapman gerekecek.",
        .applicationChecklist: "Başvuru kontrol listesi",
        .instagramConnected: "Instagram bağlandı", .cityVerified: "Şehir doğrulandı",
        .nichesSet: "Nişler seçildi", .creatorReferences: "Creator referansları",
        .membershipApproved: "Üyelik onaylandı",
        .accountSection: "Hesap",
        .accountSectionSub: "Üyeliğini geçici olarak duraklat veya kalıcı olarak sil.",
        .pauseAccount: "Hesabı geçici kapat",
        .pauseAccountSub: "Duraklatma seni davetlerden gizler ve bekleyen rezervasyonları iptal eder. Profilin saklanır.",
        .reactivateAccount: "Hesabı yeniden aç",
        .deleteAccountForever: "Hesabı kalıcı sil",
        .deleteAccountSub: "Profilin, rezervasyonların ve girişin kalıcı olarak silinir.",
        .pauseConfirmTitle: "Hesap geçici kapatılsın mı?",
        .pauseConfirmMessage: "Üyeliğin duraklatılır, bekleyen davetler iptal edilir ve bildirimler durur. Profilini kaybetmeden sonra yeniden açabilirsin.",
        .deleteConfirmTitle: "Hesap kalıcı silinsin mi?",
        .deleteConfirmMessage: "Profilin, rezervasyonların ve girişin kalıcı olarak silinir. Bu işlem geri alınamaz.",
        .typeDeleteHint: "Kalıcı silmeyi onaylamak için SİL yaz.",
        .accountPausedMessage: "Hesap duraklatıldı. Profilden istediğin zaman yeniden açabilirsin.",
        .legalSection: "Yasal & hesap", .settingsSection: "Ayarlar",
        .pushNotifications: "Anlık bildirimler", .proofReminders: "Kanıt hatırlatıcıları",
        .autoSaveProofLinks: "Kanıt linklerini otomatik kaydet", .languageLabel: "Dil",
        .deleteOnWeb: "Web'den hesap sil", .helpSupport: "Yardım & destek",
        .emailSupport: "E-posta desteği", .reportSafety: "Güvenlik sorunu bildir",
        .underReviewBanner: "Başvuru inceleniyor",
        .underReviewBannerSub: "Profilin doğrulanırken etkinliklere göz atabilirsin. Onaylanana kadar davet kabulü sınırlı olabilir.",
        .approvedBanner: "Üyelik onaylandı",
        .approvedBannerSub: "Creator profilin aktif. Davetleri kabul et ve her ziyaretten sonra kanıt gönder.",
        .pausedSelfBanner: "Hesap geçici olarak kapalı",
        .pausedSelfBannerSub: "Hesabını duraklattın. Profilden istediğin zaman yeniden aç. Bekleyen davetler iptal edildi.",
        .pausedAdminBanner: "Üyelik duraklatıldı",
        .pausedAdminBannerSub: "Hesabın ekibimiz tarafından duraklatıldı. Erişim için destekle iletişime geç.",
        .reactivateMyAccount: "Hesabımı yeniden aç",
        .inboxTitle: "Gelen Kutusu", .inboxEmpty: "Gelen kutusu boş",
        .inboxSub: "Kampanya güncellemeleri, kanıt hatırlatıcıları ve yönetim mesajları.",
        .inboxLoading: "Son bildirimlerin yükleniyor.",
        .openAction: "Aç",
        .welcomeBack: "Tekrar hoş geldin",
        .signInToContinue: "Devam etmek için e-posta ve şifrenle giriş yap.",
        .forgotPasswordEmail: "Şifreni mi unuttun? E-posta ile sıfırla",
        .statusUnderReview: "İnceleniyor", .statusApproved: "Onaylandı", .statusPaused: "Duraklatıldı",
        .stageInvited: "Davet edildi", .stageConfirmed: "Onaylandı", .stageCheckedIn: "Check-in yapıldı",
        .stageProofDue: "Kanıt bekleniyor", .stageCompleted: "Tamamlandı", .stageCancelled: "İptal edildi",
        .roleCreator: "Creator", .roleVenue: "Mekân", .roleAdmin: "Yönetici",
        .modelInvitation: "Davet", .modelEvent: "Etkinlik", .modelGift: "Hediye", .modelInstant: "Anlık",
        .errSessionExpired: "Oturumun sona erdi. Lütfen tekrar giriş yap.",
        .errSignInRequired: "Devam etmek için giriş yap.",
        .errWrongPassword: "E-posta veya şifre hatalı. Tekrar dene veya şifreni sıfırla.",
        .errAccountExists: "Bu e-postayla zaten bir hesap var. Giriş yap veya şifreni sıfırla.",
        .errInviteInvalid: "Davet kodu tanınmadı. Küratöründen geçerli bir kod iste.",
        .errInvitationFull: "Bu davet dolu. Başka bir etkinlik dene.",
        .errCheckInInvalid: "Check-in kodu geçersiz. Mekân hostundan doğru kodu iste.",
        .errProfileNotReady: "Creator profilin henüz hazır değil. Destekle iletişime geç.",
        .errReactivateSupport: "Bu hesap ekibimiz tarafından duraklatıldı. Erişim için support@marvisociety.com adresine yaz.",
        .errEnterEmail: "Önce e-posta adresini gir.",
        .errTypeDelete: "Kalıcı silmeyi onaylamak için SİL yaz.",
        .errSomeDataRefresh: "Bazı veriler yenilenemedi. Aşağı çekip tekrar dene.",
        .errAlreadyAccepted: "Bu daveti zaten kabul ettin.",
        .errNotAuthenticated: "Devam etmek için giriş yap.",
        .errConfirmEmail: "E-postana bir onay bağlantısı gönderdik. Hesabını doğrulamak için aç, sonra buraya dönüp giriş yap.",
        .openAdminConsole: "Yönetim konsolunu aç",
        .bootstrapLoading: "Kulübün yükleniyor…",
        .syncErrorTitle: "Senkronize edilemedi",
        .hiGreeting: "Merhaba",
        .saveProfile: "Hesaba kaydet",
        .mapLocationNeeded: "Yakındaki anlık teklifleri görmek için konumu aç.",
        .enableLocation: "Konumu etkinleştir",
        .instantNearby: "Yakında anlık teklifler",
        .upcomingEventsIn: "Yaklaşan etkinlikler —",
        .upNextInCity: "Yaklaşan etkinlikler —",
        .venueWorkspaceNote: "Mekân ve yönetim alanları hesap rolüne göre otomatik açılır.",
        .workspace: "Çalışma alanı",
        .workspaceAdminSub: "Bu hesapta yönetici erişimi etkin.",
        .workspaceSwitchSub: "Creator, mekân ve yönetim araçları arasında geç.",
        .adminConsoleSub: "Creator başvurularını, kampanyaları ve kanıtları incele.",
        .openTasks: "Açık görevler", .liveOffers: "Canlı teklifler",
        .creatorSignals: "Creator sinyalleri", .creatorSignalsSub: "Davet eşleşmesi için kullanılır.",
        .scoreLabel: "Puan", .deliveryLabel: "Teslimat",
        .strikeHistory: "Uyarı geçmişi", .strikeHistorySub: "Politika ihlalleri eşleşme önceliğini etkiler.",
        .socialAccounts: "Sosyal hesaplar", .socialAccountsSub: "Doğrulama ve kanıt takibi için bağlı profiller.",
        .changeAvatar: "Profil fotoğrafı", .changeCover: "Kapak görseli",
        .displayName: "Görünen ad", .bio: "Biyografi", .cityField: "Şehir", .tiktokHandleField: "TikTok kullanıcı adı",
        .handleEmpty: "@kullanıcı adı ekle",
        .nichesComma: "Nişler (virgülle ayır)", .languagesComma: "Diller (virgülle ayır)",
        .openInstagram: "Instagram profilini aç", .openTiktok: "TikTok profilini aç",
        .profileSavedSuccess: "Profil hesabına kaydedildi.", .saving: "Kaydediliyor…",
        .checklistProgress: "/ 7 adım tamamlandı",
        .nicheSelected: "Niş seçildi", .audienceReviewed: "Kitle incelendi", .agreementSigned: "Sözleşme imzalandı",
        .tiktokConnected: "TikTok bağlandı",
        .inviteFriends: "Creator davet et",
        .inviteFriendsSub: "Tek kullanımlık davet e-postası gönder. Kayıt aynı e-posta adresiyle yapılmalı.",
        .inviteEmailPlaceholder: "Arkadaşının e-postası",
        .sendInviteBtn: "Davet e-postası gönder",
        .inviteSentSuccess: "Davet gönderildi — kod e-postayla iletilecek.",
        .socialSetupTitle: "Sosyal hesaplarını bağla",
        .socialSetupSub: "Doğrulama ve davet eşleşmesi için Instagram ve TikTok zorunludur.",
        .socialSetupContinue: "Kaydet ve devam et",
        .errInviteEmailMismatch: "Bu davet farklı bir e-postaya gönderildi. Davet edilen adresle giriş yap.",
        .signedIn: "Giriş yapıldı", .notSignedIn: "Giriş yapılmadı",
        .developer: "Geliştirici", .debugBuildsOnly: "Yalnızca debug sürümlerinde.",
        .reactivating: "Yeniden açılıyor…", .closeAccountBtn: "Hesabı kapat", .deleteForeverBtn: "Kalıcı sil",
        .unreadSuffix: "okunmamış", .settingsSub: "Tercihler bu cihazda saklanır.",
        .privacyPolicy: "Gizlilik Politikası", .termsOfService: "Kullanım Koşulları",
        .communityGuidelines: "Topluluk Kuralları", .legalSectionSub: "App Store incelemesi için gerekli politikalar.",
        .myEventsSub: "Etkinliklerin düzenli",
        .pendingInvites: "Bekleyen davetler", .interestShown: "İlgi gösterilenler",
        .decline: "Reddet", .accept: "Kabul et",
        .noInterestShown: "İlgi gösterilen yok", .saveEventsExploreSub: "Takip etmek için Keşfet'ten etkinlik kaydet.",
        .noPendingInvites: "Bekleyen davet yok", .nothingToConfirm: "Onaylanacak bir şey yok",
        .nothingToReview: "İncelenecek bir şey yok", .noVisitsScheduled: "Planlanmış ziyaret yok",
        .emptyRequestsSub: "Bir mekân seni doğrudan davet ettiğinde burada görünür.",
        .emptyConfirmSub: "Check-in bekleyen onaylı ziyaretler burada görünür.",
        .emptyReviewSub: "Ziyaretinden sonra kanıt göndererek ilerle.",
        .emptyVisitSub: "Check-in yapılmış iş birlikleri kanıt süresine kadar burada kalır.",
        .categoryLabel: "Kategori",
        .checkInAtVenue: "Mekânda check-in yap",
        .checkInSheetSub: "Personelin gösterdiği kodu gir veya rezervasyon referansını kullan.",
        .checkInCode: "Check-in kodu", .checkingIn: "Check-in yapılıyor…",
        .confirmCheckIn: "Check-in onayla", .checkInNav: "Check-in",
        .submitProofTitle: "Kanıt gönder",
        .submitProofSub: "%@ için Instagram veya TikTok linklerini yapıştır.",
        .attachScreenshot: "Ekran görüntüsü ekle", .submitting: "Gönderiliyor…",
        .sendToReview: "İncelemeye gönder", .proofNav: "Kanıt",
        .timelineConfirm: "Onay", .timelineCheckIn: "Check-in", .timelineProof: "Kanıt", .addProof: "Kanıt ekle",
        .eventRSVPSub: "Katılımın mekân kapasitesinden düşülür.",
        .giftDeliverySub: "Onay sırasında teslimat adresi gerekir.",
        .campaignBrief: "Kampanya özeti", .metricDate: "tarih", .metricTime: "saat",
        .creatorValue: "creator değeri", .openSlots: "açık kontenjan", .capacity: "Kapasite",
        .creatorsConfirmed: "%d creator onayladı", .percentFilled: "%d%% dolu",
        .deliverables: "Teslim edilecekler", .requirements: "Gereksinimler", .hostNote: "Host notu",
        .acceptanceTerms: "Kabul koşulları",
        .termAttendance: "Katılım", .termAttendanceVal: "Onaylı zaman aralığında gel.",
        .termContent: "İçerik", .termContentVal: "Kanıt son tarihinden önce tüm linkleri gönder.",
        .termPolicy: "Politika", .termPolicyVal: "İzinsiz misafir çekimi yapma.",
        .cancelInvitationQ: "Bu davet iptal edilsin mi?", .keepBtn: "Vazgeç",
        .venueNotifiedCancel: "Mekân bilgilendirilir ve kontenjanın serbest kalabilir.",
        .pleaseWait: "Lütfen bekle…", .confirmedStatus: "Onaylandı",
        .matchPercent: "%d%% eşleşme", .slotsLeft: "%d kontenjan kaldı",
        .extrasRequiredSub: "Bu iş birliğini onaylamadan önce gerekli.",
        .featuredEvent: "Öne çıkan etkinlik", .featuredEvents: "Öne çıkan etkinlikler",
        .sortEvents: "Etkinlikleri sırala", .loadingEvents: "Etkinlikler yükleniyor…", .noEventsYet: "Henüz etkinlik yok",
        .fetchingLive: "Sunucudan canlı kampanyalar alınıyor.",
        .newVenueInvites: "%@ için yeni mekân davetleri yayınlandığında burada görünür. Yenilemek için aşağı çek.",
        .searchVenuePrompt: "Mekân, bölge, kategori",
        .now: "Şimdi", .details: "Detaylar", .eventsFound: "%d etkinlik bulundu",
        .loadingWorkspace: "Çalışma alanın yükleniyor…",
        .configurationRequired: "Yapılandırma gerekli",
        .configurationSub: "Config/Secrets.xcconfig.example dosyasını Secrets.xcconfig olarak kopyala ve Supabase URL ile anon key ekle.",
        .strikePolicyMessage: "Bu, rezervasyona bağlı creatora politika uyarısı kaydeder.",
        .updating: "Güncelleniyor…", .loadingApplicant: "Başvuran detayları yükleniyor…",
        .applicantProfile: "Başvuran profili", .reviewContext: "İnceleme bağlamı",
        .noLinksYet: "Henüz link eklenmedi.", .campaignDetails: "Kampanya detayları",
        .createAccountDirect: "Doğrudan hesap oluştur", .sendInviteEmail: "Davet e-postası gönder",
        .actionsLabel: "İşlemler", .liveMap: "Canlı harita",
        .liveMapLegend: "Pembe = konum paylaşan creatorlar. Altın = mekânlar/teklifler.",
        .radiusLabel: "Yarıçap", .enableLocationBroadcast: "Yayın merkezi olarak konumunu kullanmak için bu cihazda konumu aç.",
        .manageEvents: "Etkinliklerini yönet", .atEstablishments: "mekânlarında",
        .liveCampaign: "Canlı kampanya", .creatorsLeft: "%d creator kaldı",
        .loadingCreators: "Creatorlar yükleniyor…", .reviewLabel: "İncele",
        .checkedInAt: "Check-in: %@", .collaborationModelLabel: "İş birliği modeli",
        .creatorSlotsCount: "Creator kontenjanı: %d",
        .confirm: "Onayla", .issueStrike: "Uyarı ver", .reasonLabel: "Sebep",
        .issueStrikeTitle: "Uyarı ver", .strikeDefaultReason: "Kampanya koşullarına göre kanıt teslim edilmedi",
        .operationsCommand: "Operasyon merkezi", .adminControl: "Yönetim kontrolü",
        .adminControlSub: "Başvuruları, kampanyaları, kanıt gönderimlerini ve operasyonel riski incele.",
        .usersLabel: "Kullanıcılar", .bookingsLabel: "Rezervasyonlar", .strikesLabel: "Uyarılar",
        .reviewQueue: "İnceleme kuyruğu", .reviewQueueSub: "Yayınlanmadan önce öğeleri onayla veya reddet.",
        .adminTabQueue: "Kuyruk", .adminTabUsers: "Kullanıcılar", .adminTabMap: "Harita", .adminTabBroadcast: "Yayın",
        .studioUnderReview: "İncelemede", .studioUpcoming: "Yaklaşan\nEtkinlikler", .studioOpenSwipe: "Swipe\naçık",
        .studioHappening: "Devam eden", .studioPast: "Geçmiş", .studioCreate: "Oluştur",
        .profileEngagement: "Etkileşim",
        .geoBroadcast: "Konum yayını",
        .geoBroadcastSub: "Son konum paylaşımı yarıçap içinde olan onaylı kullanıcılara uygulama içi bildirim gönder.",
        .sendToArea: "Bölgeye gönder", .locationUnavailable: "Konum kullanılamıyor.",
        .inviteEmailQueued: "Davet e-postası kuyruğa alındı.", .noUsersLoaded: "Kullanıcı yüklenmedi",
        .noUsersLoadedSub: "Supabase'de apply-admin-operations.sql çalıştır, sonra yenile.",
        .searchUsersPrompt: "E-posta, ad, şehir, kullanıcı adı",
        .approve: "Onayla", .block: "Engelle", .approvedMsg: "Onaylandı.", .accountBlocked: "Hesap engellendi.",
        .sendInAppNotification: "Uygulama içi bildirim gönder", .sendEmailBtn: "E-posta gönder",
        .notificationSent: "Bildirim gönderildi.", .emailQueued: "E-posta kuyruğa alındı.",
        .loadingProfile: "Profil yükleniyor…", .roleLabel: "Rol", .referralLabel: "Referans",
        .instagramLabel: "Instagram", .lastLocationLabel: "Son konum", .notSharedYet: "Henüz paylaşılmadı",
        .statusField: "Durum", .notificationTitlePh: "Bildirim başlığı", .notificationBodyPh: "Bildirim metni",
        .emailSubjectPh: "E-posta konusu", .emailBodyPh: "E-posta metni",
        .liveMapStats: "%d creator · %d canlı teklif", .noEmail: "E-posta yok", .liveStatusLabel: "Canlı",
        .venuePartnerWorkspace: "Mekân partner çalışma alanı", .reviewCreators: "Creatorları incele",
        .campaigns: "Kampanyalar", .campaignsSub: "Bu alanda %d aktif",
        .brandPartners: "Marka partnerleri", .brandPartnersSub: "Mekân çalışma alanına bağlı kampanyalar.",
        .noBrandCampaigns: "Henüz marka kampanyası yok",
        .noBrandCampaignsSub: "Keşfet'te yayınlamak için admin incelemesine kampanya gönder.",
        .toReviewVenueSub: "Creator ziyaretlerinden sonra düşüncelerini paylaş.",
        .noReviewsTab: "Bu sekmede inceleme yok", .noReviewsTabSub: "Check-in veya checkout sonrası creatorlar burada görünür.",
        .creatorMatching: "Creator eşleştirme", .shortlistComplete: "Kısa liste tamamlandı",
        .noCreatorsMatch: "Eşleşecek creator yok",
        .noCreatorsMatchSub: "Kampanyan canlı olduğunda creator başvuruları kaydırma için burada görünür.",
        .allReviewedSub: "Bu gruptaki tüm creatorlar incelendi.",
        .visitLabel: "Ziyaret", .shareThoughts: "Düşüncelerini paylaş",
        .shareThoughtsSub: "Dakiklik ve sunumu puanla.",
        .punctuality: "Dakiklik", .presentation: "Sunum", .optionalNote: "İsteğe bağlı not",
        .hospitality: "Misafirperverlik", .experience: "Deneyim",
        .reviewAlreadySubmitted: "İnceleme zaten gönderildi — tekrar kaydetmek günceller.",
        .submitReview: "İncelemeyi gönder", .creatorReviewNav: "Creator incelemesi",
        .newCampaign: "Yeni kampanya", .newCampaignSub: "Canlı olmadan önce admin incelemesine gönderilir.",
        .campaignTitlePh: "Kampanya başlığı", .venueNamePh: "Mekân adı", .areaPh: "Bölge",
        .eventDateLabel: "Etkinlik tarihi", .valuePh: "Değer (ör. 2 kişilik akşam yemeği)",
        .deliverablesPh: "Teslim edilecekler, virgülle ayır",
        .sendToAdminReview: "Admin incelemesine gönder", .createNav: "Oluştur",
        .segmentCheckedIn: "Check-in yapıldı", .segmentCheckedOut: "Check-out", .segmentNoShow: "Gelmedi",
        .tabEstablishments: "Mekânlar", .tabBrands: "Markalar",
        .followersCount: "%d takipçi", .creatorSlotsVenue: "%@ · %d creator kontenjanı",
        .myLocations: "Mekânların", .myLocationsSub: "Tek hesap — restoran, otel, mağaza ve daha fazlası.",
        .addLocation: "Mekân ekle", .addLocationSub: "Admin incelemesi için yeni bir yer gönder. Ekstra hesap gerekmez.",
        .selectLocation: "Aktif mekân", .locationPendingReview: "İnceleme bekliyor",
        .locationTypeLabel: "Tür", .addressOptional: "Adres (isteğe bağlı)", .contactPhoneOptional: "İletişim telefonu (isteğe bağlı)",
        .errServerSetupReferral: "Sunucu kurulumu eksik. Supabase'de apply-referral-fix.sql çalıştır.",
        .errServerSetupMultiVenue: "Sunucu kurulumu eksik. Supabase'de apply-multi-venue.sql çalıştır.",
        .errAppleSignInUnavailable: "Bu sürümde Apple ile giriş kullanılamıyor. E-posta ile giriş yap.",
        .errServerConfig: "Sunucu yapılandırma hatası. Secrets.xcconfig içindeki Supabase anon key'i kontrol et.",
        .errAdminAccessDisabled: "Yönetici erişimi etkin değil. Giriş yap, Supabase'de grant-admin SQL çalıştır, sonra Sunucudan senkronize et'e dokun.",
        .errNoLinkedBooking: "Bu görevin bağlı rezervasyonu yok.",
        .errSignInCheckIn: "Check-in için giriş yap.",
        .errEnterCheckInCode: "Mekân hostundan check-in kodunu al.",
        .errEnterInviteCode: "Geçerli bir davet kodu gir.",
        .errSignInRedeemInvite: "Daveti kullanmadan önce giriş yap.",
        .errSignInSubmitProof: "Kanıt göndermek için giriş yap.",
        .errUploadScreenshot: "Ekran görüntüsü yüklenemedi.",
        .errAddProofLink: "En az bir kanıt linki veya ekran görüntüsü ekle.",
        .errAdminRequired: "Yönetici erişimi gerekli.",
        .errNoUsersInArea: "Bu bölgede yakın konum paylaşan onaylı kullanıcı yok.",
        .errSentToUsers: "%d km içindeki %d kullanıcıya gönderildi."
    ]
}

// MARK: - AppState helper

extension AppState {
    func t(_ key: MarviL10n.Key) -> String {
        MarviL10n.t(key, language: preferredLanguage)
    }

    func tf(_ key: MarviL10n.Key, _ arguments: CVarArg...) -> String {
        String(format: t(key), arguments: arguments)
    }
}

// MARK: - Localized enum labels

extension OfferCategory {
    func label(for language: AppLanguage) -> String {
        switch self {
        case .dining: MarviL10n.t(.dining, language: language)
        case .nightlife: MarviL10n.t(.nightlife, language: language)
        case .wellness: MarviL10n.t(.wellness, language: language)
        case .beauty: MarviL10n.t(.beauty, language: language)
        case .fitness: MarviL10n.t(.fitness, language: language)
        case .retail: MarviL10n.t(.retail, language: language)
        }
    }
}

extension CollaborationModel {
    func label(for language: AppLanguage) -> String {
        switch self {
        case .invitation: MarviL10n.t(.modelInvitation, language: language)
        case .event: MarviL10n.t(.modelEvent, language: language)
        case .gift: MarviL10n.t(.modelGift, language: language)
        case .instant: MarviL10n.t(.modelInstant, language: language)
        }
    }
}

extension UserRole {
    func label(for language: AppLanguage) -> String {
        switch self {
        case .creator: MarviL10n.t(.roleCreator, language: language)
        case .venue: MarviL10n.t(.roleVenue, language: language)
        case .admin: MarviL10n.t(.roleAdmin, language: language)
        }
    }
}

extension MembershipStatus {
    func label(for language: AppLanguage) -> String {
        switch self {
        case .underReview: MarviL10n.t(.statusUnderReview, language: language)
        case .approved: MarviL10n.t(.statusApproved, language: language)
        case .paused: MarviL10n.t(.statusPaused, language: language)
        }
    }
}

extension BookingStage {
    func label(for language: AppLanguage) -> String {
        switch self {
        case .invited: MarviL10n.t(.stageInvited, language: language)
        case .confirmed: MarviL10n.t(.stageConfirmed, language: language)
        case .checkedIn: MarviL10n.t(.stageCheckedIn, language: language)
        case .proofDue: MarviL10n.t(.stageProofDue, language: language)
        case .completed: MarviL10n.t(.stageCompleted, language: language)
        case .cancelled: MarviL10n.t(.stageCancelled, language: language)
        }
    }
}
