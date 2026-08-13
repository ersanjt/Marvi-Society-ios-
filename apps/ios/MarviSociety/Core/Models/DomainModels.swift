import Foundation
import SwiftUI

struct AccountContext: Equatable {
    let role: UserRole
    let membershipStatus: MembershipStatus?
    let hasVenueProfile: Bool
    let referralCode: String?
    let pausedBySelf: Bool
}

enum UserRole: String, CaseIterable, Codable, Identifiable {
    case creator = "Creator"
    case venue = "Venue"
    case admin = "Admin"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .creator: "sparkles"
        case .venue: "building.2"
        case .admin: "checkmark.shield"
        }
    }

    var description: String {
        // Prefer localized strings via MarviL10n when language is known.
        switch self {
        case .creator:
            "Find curated Istanbul invitations and submit proof."
        case .venue:
            "Create campaigns and manage creator attendance."
        case .admin:
            "Approve members, venues, campaigns, and proof."
        }
    }

    func localizedDescription(language: AppLanguage) -> String {
        switch self {
        case .creator: MarviL10n.t(.roleCreatorDesc, language: language)
        case .venue: MarviL10n.t(.roleVenueDesc, language: language)
        case .admin: MarviL10n.t(.roleAdminDesc, language: language)
        }
    }

    static func fromAPI(_ raw: String?) -> UserRole? {
        switch raw?.lowercased() {
        case "creator": .creator
        case "venue", "business", "brand": .venue
        case "admin": .admin
        default: nil
        }
    }

    /// Postgres `user_role` enum value.
    var apiValue: String {
        switch self {
        case .creator: "creator"
        case .venue: "venue"
        case .admin: "admin"
        }
    }

    /// Workspace tabs available for a server-side account role.
    static func allowedWorkspaces(for accountRole: UserRole) -> [UserRole] {
        switch accountRole {
        case .admin: [.creator, .admin]
        case .venue: [.venue]
        case .creator: [.creator]
        }
    }

    /// Display order when multiple workspaces are available (Creator · Venue · Admin).
    static func sortedWorkspaces(_ roles: [UserRole]) -> [UserRole] {
        let order: [UserRole] = [.creator, .venue, .admin]
        return order.filter { roles.contains($0) }
    }
}

enum CollaborationModel: String, CaseIterable, Codable, Identifiable, Hashable {
    case invitation = "Invitation"
    case event = "Event"
    case gift = "Gift"
    case instant = "Instant"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .invitation: "calendar.badge.clock"
        case .event: "party.popper"
        case .gift: "gift"
        case .instant: "bolt.fill"
        }
    }
}

enum OfferCategory: String, CaseIterable, Codable, Identifiable, Hashable {
    case dining = "Dining"
    case nightlife = "Nightlife"
    case wellness = "Wellness"
    case beauty = "Beauty"
    case fitness = "Fitness"
    case retail = "Retail"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dining: "fork.knife"
        case .nightlife: "music.mic"
        case .wellness: "leaf"
        case .beauty: "wand.and.stars"
        case .fitness: "figure.run"
        case .retail: "bag"
        }
    }

    var tint: Color {
        switch self {
        case .dining: MarviColor.tomato
        case .nightlife: MarviColor.aubergine
        case .wellness: MarviColor.emerald
        case .beauty: MarviColor.rose
        case .fitness: MarviColor.blue
        case .retail: MarviColor.gold
        }
    }
}

struct BusinessCategoryOption: Identifiable, Hashable, Sendable {
    let key: String
    let english: String
    let turkish: String
    let offerCategory: OfferCategory

    var id: String { key }

    func label(for language: AppLanguage) -> String {
        language == .turkish ? turkish : english
    }
}

enum BusinessCategoryCatalog {
    /// Product order: Hotel → Restaurant → Cafe → then rest.
    /// Keys match `public.business_categories.slug` where possible.
    static let all: [BusinessCategoryOption] = [
        // Top picks
        .init(key: "hotel", english: "Hotel", turkish: "Otel", offerCategory: .wellness),
        .init(key: "restaurant", english: "Restaurant", turkish: "Restoran", offerCategory: .dining),
        .init(key: "cafe", english: "Cafe", turkish: "Kafe", offerCategory: .dining),
        // Food & drink
        .init(key: "coffee-shop", english: "Coffee shop", turkish: "Kahve dükkanı", offerCategory: .dining),
        .init(key: "bakery", english: "Bakery", turkish: "Fırın", offerCategory: .dining),
        .init(key: "patisserie", english: "Patisserie", turkish: "Pastane", offerCategory: .dining),
        .init(key: "dessert-shop", english: "Dessert shop", turkish: "Tatlıcı", offerCategory: .dining),
        .init(key: "fast-food", english: "Fast food", turkish: "Fast food", offerCategory: .dining),
        .init(key: "food-truck", english: "Food truck", turkish: "Yemek kamyonu", offerCategory: .dining),
        .init(key: "catering", english: "Catering", turkish: "Catering", offerCategory: .dining),
        // Hospitality
        .init(key: "resort", english: "Resort", turkish: "Tatil köyü", offerCategory: .wellness),
        .init(key: "hostel", english: "Hostel", turkish: "Hostel", offerCategory: .wellness),
        // Nightlife
        .init(key: "bar-pub", english: "Bar / Pub", turkish: "Bar / Pub", offerCategory: .nightlife),
        .init(key: "lounge", english: "Lounge", turkish: "Lounge", offerCategory: .nightlife),
        .init(key: "nightclub", english: "Nightclub", turkish: "Gece kulübü", offerCategory: .nightlife),
        .init(key: "live-music-venue", english: "Live music venue", turkish: "Canlı müzik mekanı", offerCategory: .nightlife),
        // Wellness & fitness
        .init(key: "spa", english: "Spa", turkish: "Spa", offerCategory: .wellness),
        .init(key: "wellness-center", english: "Wellness center", turkish: "Wellness merkezi", offerCategory: .wellness),
        .init(key: "yoga-pilates", english: "Yoga / Pilates studio", turkish: "Yoga / Pilates stüdyosu", offerCategory: .wellness),
        .init(key: "gym-fitness", english: "Gym / Fitness center", turkish: "Spor salonu", offerCategory: .fitness),
        .init(key: "sports-club", english: "Sports club", turkish: "Spor kulübü", offerCategory: .fitness),
        .init(key: "dance-studio", english: "Dance studio", turkish: "Dans stüdyosu", offerCategory: .fitness),
        // Beauty
        .init(key: "beauty-salon", english: "Beauty salon", turkish: "Güzellik salonu", offerCategory: .beauty),
        .init(key: "hair-salon", english: "Hair salon / Barber", turkish: "Kuaför / Berber", offerCategory: .beauty),
        .init(key: "nail-studio", english: "Nail studio", turkish: "Tırnak stüdyosu", offerCategory: .beauty),
        .init(key: "cosmetics", english: "Cosmetics", turkish: "Kozmetik", offerCategory: .beauty),
        // Health
        .init(key: "clinic", english: "Clinic", turkish: "Klinik", offerCategory: .wellness),
        .init(key: "dentist", english: "Dentist", turkish: "Diş kliniği", offerCategory: .wellness),
        .init(key: "pharmacy", english: "Pharmacy", turkish: "Eczane", offerCategory: .wellness),
        // Retail
        .init(key: "fashion", english: "Fashion / Clothing", turkish: "Moda / Giyim", offerCategory: .retail),
        .init(key: "shoes-accessories", english: "Shoes / Accessories", turkish: "Ayakkabı / Aksesuar", offerCategory: .retail),
        .init(key: "jewelry", english: "Jewelry", turkish: "Mücevher", offerCategory: .retail),
        .init(key: "home-decor", english: "Home decor / Furniture", turkish: "Ev dekorasyonu / Mobilya", offerCategory: .retail),
        .init(key: "electronics", english: "Electronics", turkish: "Elektronik", offerCategory: .retail),
        .init(key: "grocery-market", english: "Grocery / Market", turkish: "Market", offerCategory: .retail),
        .init(key: "bookstore", english: "Bookstore", turkish: "Kitapçı", offerCategory: .retail),
        .init(key: "concept-store", english: "Concept store", turkish: "Konsept mağaza", offerCategory: .retail),
        .init(key: "ecommerce", english: "E-commerce / Online store", turkish: "E-ticaret / Online mağaza", offerCategory: .retail),
        // Culture & events
        .init(key: "cinema-theater", english: "Cinema / Theater", turkish: "Sinema / Tiyatro", offerCategory: .nightlife),
        .init(key: "museum-gallery", english: "Museum / Art gallery", turkish: "Müze / Sanat galerisi", offerCategory: .retail),
        .init(key: "entertainment-center", english: "Entertainment center", turkish: "Eğlence merkezi", offerCategory: .nightlife),
        .init(key: "event-venue", english: "Event venue", turkish: "Etkinlik mekanı", offerCategory: .nightlife),
        .init(key: "event-planner", english: "Event planner", turkish: "Etkinlik organizasyonu", offerCategory: .retail),
        .init(key: "photography-studio", english: "Photography / Video studio", turkish: "Fotoğraf / Video stüdyosu", offerCategory: .retail),
        // Services
        .init(key: "education-training", english: "Education / Training", turkish: "Eğitim / Kurs", offerCategory: .retail),
        .init(key: "coworking", english: "Coworking space", turkish: "Ortak çalışma alanı", offerCategory: .retail),
        .init(key: "professional-services", english: "Professional services", turkish: "Profesyonel hizmetler", offerCategory: .retail),
        .init(key: "real-estate", english: "Real estate", turkish: "Gayrimenkul", offerCategory: .retail),
        .init(key: "travel-tourism", english: "Travel / Tourism", turkish: "Seyahat / Turizm", offerCategory: .wellness),
        .init(key: "car-dealer-rental", english: "Car dealer / Rental", turkish: "Otomotiv / Araç kiralama", offerCategory: .retail),
        .init(key: "pet-services", english: "Pet shop / Pet services", turkish: "Evcil hayvan hizmetleri", offerCategory: .retail),
        .init(key: "kids-family", english: "Kids / Family services", turkish: "Çocuk / Aile hizmetleri", offerCategory: .retail),
        .init(key: "home-services", english: "Home services", turkish: "Ev hizmetleri", offerCategory: .retail),
        .init(key: "digital-technology", english: "Digital / Technology", turkish: "Dijital / Teknoloji", offerCategory: .retail),
        .init(key: "nonprofit-community", english: "Nonprofit / Community", turkish: "STK / Topluluk", offerCategory: .retail)
    ]

    static func offerCategory(for label: String) -> OfferCategory {
        let normalized = label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let match = all.first(where: {
            $0.key == normalized
                || $0.english.lowercased() == normalized
                || $0.turkish.lowercased() == normalized
        }) {
            return match.offerCategory
        }
        // Legacy client keys still resolve.
        let legacy: [String: OfferCategory] = [
            "live-music": .nightlife, "wellness": .wellness, "gym": .fitness,
            "accessories": .retail, "grocery": .retail, "entertainment": .nightlife,
            "photo-video": .retail, "education": .retail, "professional": .retail,
            "travel": .wellness, "automotive": .retail, "technology": .retail,
            "community": .retail, "dessert": .dining
        ]
        if let mapped = legacy[normalized] { return mapped }
        if normalized.range(of: "hotel|otel|resort|hostel", options: .regularExpression) != nil { return .wellness }
        if normalized.range(of: "restaurant|restoran|cafe|coffee|food|bakery|kafe|yemek", options: .regularExpression) != nil { return .dining }
        if normalized.range(of: "bar|pub|club|lounge|night|music|event|gece|etkinlik", options: .regularExpression) != nil { return .nightlife }
        if normalized.range(of: "gym|fitness|sport|yoga|pilates|spor", options: .regularExpression) != nil { return .fitness }
        if normalized.range(of: "beauty|salon|hair|nail|cosmetic|güzellik|kuaför", options: .regularExpression) != nil { return .beauty }
        if normalized.range(of: "spa|wellness|clinic|health|sağlık", options: .regularExpression) != nil { return .wellness }
        return .retail
    }
}

enum MembershipStatus: String, Codable {
    case underReview = "Under review"
    case approved = "Approved"
    case paused = "Paused"
}

enum BookingStage: String, Codable {
    case invited = "Invited"
    case confirmed = "Confirmed"
    case checkedIn = "Checked in"
    case proofDue = "Proof due"
    case completed = "Completed"
    case cancelled = "Cancelled"
}

enum ProofStatus: String, Codable {
    case notStarted = "Not started"
    case pending = "Pending review"
    case approved = "Approved"
    case flagged = "Flagged"
}

enum CampaignStatus: String, CaseIterable, Codable, Identifiable {
    case draft = "Draft"
    case review = "In review"
    case live = "Live"
    case completed = "Completed"

    var id: String { rawValue }
}

enum AdminTaskType: String, Codable {
    case creatorApplication = "Creator application"
    case venueApplication = "Venue application"
    case campaignReview = "Campaign review"
    case proofReview = "Proof review"
    case socialVerification = "Social verification"
}

enum AdminTaskStatus: String, Codable {
    case open = "Open"
    case approved = "Approved"
    case rejected = "Rejected"
}

enum PaletteToken: String, Codable {
    case emerald
    case aubergine
    case gold
    case rose
    case tomato
    case blue
    case muted
    case ink

    var color: Color {
        switch self {
        case .emerald: MarviColor.emerald
        case .aubergine: MarviColor.aubergine
        case .gold: MarviColor.gold
        case .rose: MarviColor.rose
        case .tomato: MarviColor.tomato
        case .blue: MarviColor.blue
        case .muted: MarviColor.muted
        case .ink: MarviColor.ink
        }
    }
}

struct Offer: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let venue: String
    let area: String
    let category: OfferCategory
    let dateLabel: String
    let timeLabel: String
    let valueLabel: String
    let capacity: Int
    let remaining: Int
    let imageName: String
    let description: String
    let deliverables: [String]
    let requirements: [String]
    let hostNote: String
    let collaborationModel: CollaborationModel
    let latitude: Double?
    let longitude: Double?
    let createdAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        venue: String,
        area: String,
        category: OfferCategory,
        dateLabel: String,
        timeLabel: String,
        valueLabel: String,
        capacity: Int,
        remaining: Int,
        imageName: String,
        description: String,
        deliverables: [String],
        requirements: [String],
        hostNote: String,
        collaborationModel: CollaborationModel = .invitation,
        latitude: Double? = nil,
        longitude: Double? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.venue = venue
        self.area = area
        self.category = category
        self.dateLabel = dateLabel
        self.timeLabel = timeLabel
        self.valueLabel = valueLabel
        self.capacity = capacity
        self.remaining = remaining
        self.imageName = imageName
        self.description = description
        self.deliverables = deliverables
        self.requirements = requirements
        self.hostNote = hostNote
        self.collaborationModel = collaborationModel
        self.latitude = latitude
        self.longitude = longitude
        self.createdAt = createdAt
    }

    var sortDate: Date { createdAt ?? .distantPast }

    var coordinate: (lat: Double, lng: Double)? {
        guard let latitude, let longitude else { return nil }
        return (latitude, longitude)
    }

    func distanceKm(from userLat: Double, userLng: Double) -> Double? {
        guard let coordinate else { return nil }
        return Self.haversineKm(
            lat1: userLat, lng1: userLng,
            lat2: coordinate.lat, lng2: coordinate.lng
        )
    }

    private static func haversineKm(lat1: Double, lng1: Double, lat2: Double, lng2: Double) -> Double {
        let earthRadius = 6371.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLng = (lng2 - lng1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) * sin(dLng / 2) * sin(dLng / 2)
        return earthRadius * 2 * atan2(sqrt(a), sqrt(1 - a))
    }
}

struct Booking: Codable, Identifiable, Hashable {
    let id: UUID
    let offer: Offer
    var stage: BookingStage
    let proofDeadline: String
    let checklist: [String]
    var proofStatus: ProofStatus
    var checkInCode: String
    var guestName: String
    var proofLinks: [String]
    var shippingAddress: String?
    var rsvpGuests: Int?
}

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case english = "en"
    case turkish = "tr"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .english: "English"
        case .turkish: "Türkçe"
        }
    }

    /// Fallback when no locale signal is available — Istanbul Turkish is the product default.
    static var defaultApp: AppLanguage { .turkish }

    /// Prefer Turkish as the primary app language; English is opt-in via Settings.
    static func inferredFromDevice() -> AppLanguage { .turkish }

    static var isDeviceLikelyInTurkey: Bool {
        let region = Locale.current.region?.identifier
            ?? Locale.current.language.region?.identifier
        if region?.uppercased() == "TR" { return true }

        let preferred = Locale.preferredLanguages.first?.lowercased() ?? ""
        if preferred.hasPrefix("tr") { return true }

        return false
    }

    static func isCoordinateInTurkey(latitude: Double, longitude: Double) -> Bool {
        latitude >= 35.8 && latitude <= 42.3 && longitude >= 25.9 && longitude <= 44.9
    }
}

enum MarviDeepLink: Equatable {
    case inbox
    case profile
    case admin
    case community
    case venueStudio
    case bookings
    case offer(UUID)
    case booking(UUID)
}

struct AcceptOfferOptions: Equatable {
    var shippingAddress: String?
    var rsvpGuests: Int?
}

struct Strike: Codable, Identifiable, Hashable {
    let id: UUID
    let reason: String
    let severity: String
    let createdAtLabel: String
}

struct CreatorProfile: Codable {
    var name: String
    var handle: String
    var tiktokHandle: String
    var city: String
    var status: MembershipStatus
    var score: Int
    var audienceLabel: String
    var niches: [String]
    var proofRate: String
    var bio: String
    var languages: [String]
    var completedApplicationSteps: Int
    var avatarURL: String
    var coverURL: String

    static let empty = CreatorProfile(
        name: "",
        handle: "",
        tiktokHandle: "",
        city: "Istanbul",
        status: .underReview,
        score: 0,
        audienceLabel: "0",
        niches: [],
        proofRate: "—",
        bio: "",
        languages: [],
        completedApplicationSteps: 0,
        avatarURL: "",
        coverURL: ""
    )

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed.split(separator: " ").first.map(String.init) ?? trimmed }
        let handleName = handle.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "@", with: "")
        return handleName.isEmpty ? "Member" : handleName
    }
}

enum ShowcaseMediaType: String, Codable, Sendable {
    case image
    case video
    case link
}

struct ShowcaseItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let mediaType: ShowcaseMediaType
    let mediaURL: String
    let externalURL: String
    let caption: String

    /// The URL to open when tapped (external link takes priority over hosted media).
    var openURL: URL? {
        let target = externalURL.isEmpty ? mediaURL : externalURL
        return URL(string: target)
    }

    /// The image to render as the tile thumbnail, when available.
    var thumbnailURL: URL? {
        mediaURL.isEmpty ? nil : URL(string: mediaURL)
    }
}

struct ChatConversation: Identifiable, Equatable, Sendable {
    let id: UUID
    let bookingID: UUID
    let offerTitle: String
    let venueName: String
    let lastMessage: String?
    let lastMessageAt: Date?

    var preview: String {
        let trimmed = lastMessage?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? offerTitle : trimmed
    }
}

struct ChatMessage: Identifiable, Equatable, Sendable {
    let id: UUID
    let conversationID: UUID
    let senderUserID: UUID
    let body: String
    let createdAt: Date
}

struct ActivityEventItem: Identifiable, Equatable, Sendable {
    enum Category: String, CaseIterable, Identifiable, Sendable {
        case all
        case bookings
        case campaigns
        case admin
        case messages
        case social
        case other

        var id: String { rawValue }
    }

    let id: UUID
    let action: String
    let subjectType: String
    let subjectID: UUID?
    let createdAt: Date
    let actorLabel: String
    let actorKind: String
    let metadata: [String: String]

    var category: Category {
        let actionKey = action.lowercased()
        let subject = subjectType.lowercased()
        if actionKey.hasPrefix("admin_") || (subject == "user" && actionKey.contains("admin")) {
            return .admin
        }
        if subject == "offer" || actionKey.contains("campaign") {
            return .campaigns
        }
        if subject == "booking" || actionKey.contains("booking") || actionKey.contains("offer_requested")
            || actionKey.contains("offer_accepted") {
            return .bookings
        }
        if subject == "conversation" || actionKey.contains("message") {
            return .messages
        }
        if subject == "creator" || subject == "collaboration_request"
            || actionKey.contains("shortlist") || actionKey.contains("collaboration") {
            return .social
        }
        return .other
    }

    func meta(_ key: String) -> String? {
        let value = metadata[key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? nil : value
    }
}

struct PendingCollaborationRequest: Identifiable, Equatable, Sendable {
    let id: UUID
    let offerID: UUID
    let offerTitle: String
    let venueName: String
    let status: String
    let createdAt: Date

    var isPendingCreator: Bool { status == "pending_creator" }
}

struct FollowCounts: Equatable {
    var followers: Int
    var following: Int

    static let zero = FollowCounts(followers: 0, following: 0)
}

struct MemberSearchResult: Identifiable, Equatable, Sendable {
    enum Kind: String, Sendable {
        case creator
        case venue
    }

    let id: UUID
    let userID: UUID
    let memberType: Kind
    let fullName: String
    let instagramHandle: String
    let tiktokHandle: String
    let city: String
    let score: Int
    let followers: Int
    var isFollowing: Bool
    let avatarURL: String

    var isCreator: Bool { memberType == .creator }
    var isVenue: Bool { memberType == .venue }

    var displayName: String {
        let trimmed = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let handle = instagramHandle.replacingOccurrences(of: "@", with: "")
        return handle.isEmpty ? "Member" : handle
    }

    var handleLabel: String {
        let handle = instagramHandle.replacingOccurrences(of: "@", with: "")
        return handle.isEmpty ? "" : "@\(handle)"
    }
}

struct MemberActivityItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let actorUserID: UUID
    let actorCreatorID: UUID?
    let actorVenueID: UUID?
    let actorName: String
    let actionType: String
    let title: String
    let subtitle: String
    let createdAt: Date

    var icon: String {
        switch actionType {
        case "checked_in": "mappin.and.ellipse"
        case "showcase_added": "photo.on.rectangle.angled"
        case "venue_offer": "tag.fill"
        default: "sparkles"
        }
    }
}

struct DirectThread: Identifiable, Equatable, Sendable {
    let id: UUID
    let peerUserID: UUID
    let peerName: String
    let peerHandle: String
    let lastMessage: String?
    let lastMessageAt: Date?

    var preview: String {
        let trimmed = lastMessage?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? peerName : trimmed
    }
}

struct ProfileComment: Identifiable, Equatable, Sendable {
    let id: UUID
    let authorUserID: UUID
    let authorName: String
    let body: String
    let createdAt: Date
}

struct PublicVenueOffer: Identifiable, Equatable, Sendable {
    let id: UUID
    let title: String
    let area: String
    let category: OfferCategory
    let remainingSlots: Int
}

struct PublicVenueProfile: Identifiable, Equatable, Sendable {
    let id: UUID
    let ownerUserID: UUID
    let venueName: String
    let area: String
    let category: OfferCategory
    let address: String
    let followers: Int
    let following: Int
    var isFollowing: Bool
    let liveOffers: [PublicVenueOffer]
}

struct CollaborationEntry: Identifiable, Hashable {
    let id: UUID
    let venueName: String
    let area: String
    let title: String
    let dateLabel: String
    /// Rating the venue gave the creator (punctuality + presentation averaged, 0 when not rated).
    let venueRating: Double?
    let venueComment: String
    /// Whether the creator left a thank-you review for the venue.
    let creatorThanked: Bool
}

struct PublicCreatorReview: Identifiable, Hashable {
    let id = UUID()
    let venueName: String
    let averageRating: Double
    let comment: String
    let dateLabel: String
}

struct PublicCreatorCollaboration: Identifiable, Hashable {
    let id = UUID()
    let venueName: String
    let area: String
    let category: OfferCategory
}

struct PublicCreatorProfile: Identifiable {
    let id: UUID
    let userID: UUID
    let profile: CreatorProfile
    let followers: Int
    let following: Int
    var isFollowing: Bool
    let reviewsReceived: [PublicCreatorReview]
    let collaborations: [PublicCreatorCollaboration]
}

struct VenueReviewItem: Identifiable, Hashable {
    let id: UUID
    let creatorName: String
    let instagramHandle: String
    let offerTitle: String
    let stage: BookingStage
    let proofStatus: ProofStatus
    let stageLabel: String
    let checkedInLabel: String
    let hasReview: Bool

    init(
        id: UUID,
        creatorName: String,
        instagramHandle: String,
        offerTitle: String,
        stage: BookingStage,
        proofStatus: ProofStatus,
        stageLabel: String,
        checkedInLabel: String,
        hasReview: Bool
    ) {
        self.id = id
        self.creatorName = creatorName
        self.instagramHandle = instagramHandle
        self.offerTitle = offerTitle
        self.stage = stage
        self.proofStatus = proofStatus
        self.stageLabel = stageLabel
        self.checkedInLabel = checkedInLabel
        self.hasReview = hasReview
    }
}

struct InfluencerCandidate: Identifiable, Hashable {
    let id: UUID
    let name: String
    let niche: String
    let score: Int
    let punctuality: Int
    let presentation: Int
    let followers: String

    init(
        id: UUID = UUID(),
        name: String,
        niche: String,
        score: Int,
        punctuality: Int,
        presentation: Int,
        followers: String
    ) {
        self.id = id
        self.name = name
        self.niche = niche
        self.score = score
        self.punctuality = punctuality
        self.presentation = presentation
        self.followers = followers
    }
}

struct VenueMetric: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let trend: String
    let icon: String
}

struct VenueSummary: Codable, Hashable, Identifiable {
    let id: UUID
    let venueName: String
    let area: String
    let category: OfferCategory
    let status: MembershipStatus?
    let isActive: Bool
    let latitude: Double?
    let longitude: Double?

    init(
        id: UUID,
        venueName: String,
        area: String,
        category: OfferCategory,
        status: MembershipStatus? = nil,
        isActive: Bool = false,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) {
        self.id = id
        self.venueName = venueName
        self.area = area
        self.category = category
        self.status = status
        self.isActive = isActive
        self.latitude = latitude
        self.longitude = longitude
    }
}

struct RegisterVenueInput: Sendable {
    let venueName: String
    let area: String
    let category: OfferCategory
    let categoryLabel: String
    let address: String
    let contactName: String
    let contactPhone: String
}

struct BrandSummary: Codable, Hashable, Identifiable, Sendable {
    var id: UUID { brandID }
    let organizationID: UUID
    let organizationName: String
    let brandID: UUID
    let brandName: String
}

struct OrganizationBrandResult: Codable, Hashable, Sendable {
    let organizationID: UUID
    let organizationName: String
    let brandID: UUID
    let brandName: String

    var asBrandSummary: BrandSummary {
        BrandSummary(
            organizationID: organizationID,
            organizationName: organizationName,
            brandID: brandID,
            brandName: brandName
        )
    }
}

struct EstablishmentDetailsInput: Sendable {
    let instagramHandle: String
    let description: String
    let categories: [String]
    let contactName: String
    let contactPhone: String
    let contactIsSelf: Bool
    let offerCategory: OfferCategory
}

struct EstablishmentAddressInput: Sendable {
    let isPhysical: Bool
    let country: String
    let city: String
    let locationLabel: String
    let addressLine1: String
    let addressLine2: String
    let postalCode: String
    let lat: Double?
    let lng: Double?
}

struct CreateCampaignInput: Sendable {
    let title: String
    let category: OfferCategory
    let collaborationModel: CollaborationModel
    let dateLabel: String
    let valueLabel: String
    let slots: Int
    let deliverables: [String]
    var imageName: String = ""
    var description: String = ""
    var timeLabel: String = "Flexible"
    var requirements: [String] = []
    var hostNote: String = ""
}

struct Campaign: Codable, Identifiable, Hashable {
    let id: UUID
    var title: String
    var venueName: String
    var area: String
    var category: OfferCategory
    var dateLabel: String
    var valueLabel: String
    var slots: Int
    var matchedCreators: Int
    var status: CampaignStatus
    var deliverables: [String]
    var isDeleted: Bool
    var adminBlockReason: String?

    init(
        id: UUID = UUID(),
        title: String,
        venueName: String,
        area: String,
        category: OfferCategory,
        dateLabel: String,
        valueLabel: String,
        slots: Int,
        matchedCreators: Int,
        status: CampaignStatus,
        deliverables: [String],
        isDeleted: Bool = false,
        adminBlockReason: String? = nil
    ) {
        self.id = id
        self.title = title
        self.venueName = venueName
        self.area = area
        self.category = category
        self.dateLabel = dateLabel
        self.valueLabel = valueLabel
        self.slots = slots
        self.matchedCreators = matchedCreators
        self.status = status
        self.deliverables = deliverables
        self.isDeleted = isDeleted
        self.adminBlockReason = adminBlockReason
    }
}

struct AdminSubjectDetail: Equatable {
    var name: String
    var handle: String?
    var city: String?
    var area: String?
    var category: String?
    var niches: [String]
    var languages: [String]
    var score: Int?
    var audienceLabel: String?
    var status: String?
    var tiktokHandle: String? = nil
    var socialVerificationCode: String? = nil
    var socialVerificationSubmittedAt: Date? = nil
}

struct AdminTask: Codable, Identifiable, Hashable {
    let id: UUID
    var subjectID: UUID?
    var type: AdminTaskType
    var title: String
    var subtitle: String
    var dateLabel: String
    var priority: String
    var status: AdminTaskStatus

    init(
        id: UUID = UUID(),
        subjectID: UUID? = nil,
        type: AdminTaskType,
        title: String,
        subtitle: String,
        dateLabel: String,
        priority: String,
        status: AdminTaskStatus = .open
    ) {
        self.id = id
        self.subjectID = subjectID
        self.type = type
        self.title = title
        self.subtitle = subtitle
        self.dateLabel = dateLabel
        self.priority = priority
        self.status = status
    }
}

struct InboxMessage: Codable, Identifiable {
    let id: UUID
    var title: String
    var body: String
    var dateLabel: String
    var icon: String
    var tint: PaletteToken
    var isRead: Bool
    var notificationType: String
    var bookingID: UUID?
    var offerID: UUID?
    var conversationID: UUID?

    init(
        id: UUID = UUID(),
        title: String,
        body: String,
        dateLabel: String,
        icon: String,
        tint: PaletteToken,
        isRead: Bool = false,
        notificationType: String = "general",
        bookingID: UUID? = nil,
        offerID: UUID? = nil,
        conversationID: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.dateLabel = dateLabel
        self.icon = icon
        self.tint = tint
        self.isRead = isRead
        self.notificationType = notificationType
        self.bookingID = bookingID
        self.offerID = offerID
        self.conversationID = conversationID
    }

    var section: InboxSection {
        InboxSection.from(type: notificationType)
    }

    func deepLink(for role: UserRole) -> MarviDeepLink? {
        if let conversationID {
            _ = conversationID
            return .community
        }
        if let bookingID {
            switch role {
            case .venue: return .venueStudio
            case .admin: return .admin
            case .creator: return .booking(bookingID)
            }
        }
        if let offerID {
            switch role {
            case .venue: return .venueStudio
            case .admin: return .admin
            case .creator: return .offer(offerID)
            }
        }
        switch notificationType.lowercased() {
        case "membership", "social":
            return .profile
        case "admin", "campaign", "ops":
            return role == .admin ? .admin : .inbox
        case "message":
            return .community
        case "collaboration", "shortlist", "booking", "proof":
            switch role {
            case .venue: return .venueStudio
            case .admin: return .admin
            case .creator: return .bookings
            }
        default:
            return .inbox
        }
    }
}

enum InboxSection: String, CaseIterable, Identifiable {
    case actionNeeded
    case bookings
    case messages
    case account
    case ops

    var id: String { rawValue }

    static func from(type: String) -> InboxSection {
        switch type.lowercased() {
        case "collaboration", "shortlist":
            return .actionNeeded
        case "booking", "proof":
            return .bookings
        case "message":
            return .messages
        case "membership", "social":
            return .account
        case "admin", "campaign", "ops":
            return .ops
        default:
            return .actionNeeded
        }
    }

    func title(for role: UserRole, language: AppLanguage) -> String {
        switch (self, role) {
        case (.actionNeeded, .venue):
            return MarviL10n.t(.inboxSectionRequests, language: language)
        case (.actionNeeded, .admin):
            return MarviL10n.t(.inboxSectionOps, language: language)
        case (.actionNeeded, _):
            return MarviL10n.t(.inboxSectionAction, language: language)
        case (.bookings, .venue):
            return MarviL10n.t(.inboxSectionCampaigns, language: language)
        case (.bookings, _):
            return MarviL10n.t(.inboxSectionBookings, language: language)
        case (.messages, _):
            return MarviL10n.t(.inboxSectionMessages, language: language)
        case (.account, _):
            return MarviL10n.t(.inboxSectionAccount, language: language)
        case (.ops, _):
            return MarviL10n.t(.inboxSectionOps, language: language)
        }
    }

    static func ordered(for role: UserRole) -> [InboxSection] {
        switch role {
        case .admin:
            return [.ops, .actionNeeded, .messages, .account, .bookings]
        case .venue:
            return [.actionNeeded, .bookings, .messages, .account, .ops]
        case .creator:
            return [.actionNeeded, .bookings, .messages, .account, .ops]
        }
    }
}

struct AdminUserSummary: Identifiable, Hashable, Codable {
    var id: UUID { userID }
    let userID: UUID
    var email: String?
    var role: String?
    var status: String?
    var fullName: String?
    var instagramHandle: String?
    var city: String?
    var strikeCount: Int
    var bookingCount: Int
    var lastLat: Double?
    var lastLng: Double?
    var lastSeenAt: Date?
    var creatorID: UUID?
    var avatarURL: String?
    var coverURL: String?

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case email, role, status
        case fullName = "full_name"
        case instagramHandle = "instagram_handle"
        case city
        case strikeCount = "strike_count"
        case bookingCount = "booking_count"
        case lastLat = "last_lat"
        case lastLng = "last_lng"
        case lastSeenAt = "last_seen_at"
        case creatorID = "creator_id"
        case avatarURL = "avatar_url"
        case coverURL = "cover_url"
    }

    var displayName: String {
        if let fullName, !fullName.isEmpty { return fullName }
        if let instagramHandle, !instagramHandle.isEmpty { return instagramHandle }
        return email ?? userID.uuidString.prefix(8).description
    }

    var hasLiveLocation: Bool {
        lastLat != nil && lastLng != nil
    }

    var initials: String {
        let parts = displayName.split(separator: " ").prefix(2)
        let letters = parts.compactMap { $0.first.map(String.init) }
        return letters.isEmpty ? "?" : letters.joined().uppercased()
    }
}

struct AdminUserDetail: Codable {
    let userID: UUID
    var email: String?
    var role: String?
    var status: String?
    var referralCode: String?
    var phone: String?
    var creatorID: UUID?
    var creatorCity: String?
    var creatorHandle: String?
    var creatorScore: Int?
    var avatarURL: String?
    var coverURL: String?
    var locationLat: Double?
    var locationLng: Double?
    var locationUpdatedAt: Date?
    var socialVerificationCode: String?
    var socialVerificationSubmittedAt: Date?
    var socialVerificationVerifiedAt: Date?
    var bookingSummaries: [String]
    var strikeSummaries: [String]

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case email, role, status
        case referralCode = "referral_code"
        case phone, creator, location, bookings, strikes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userID = try container.decode(UUID.self, forKey: .userID)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        role = try container.decodeIfPresent(String.self, forKey: .role)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        referralCode = try container.decodeIfPresent(String.self, forKey: .referralCode)
        phone = try container.decodeIfPresent(String.self, forKey: .phone)

        if let creator = try container.decodeIfPresent([String: JSONValue].self, forKey: .creator) {
            creatorID = creator["id"]?.uuidValue
            creatorCity = creator["city"]?.stringValue
            creatorHandle = creator["instagram_handle"]?.stringValue
            creatorScore = creator["score"]?.intValue
            avatarURL = creator["avatar_url"]?.stringValue
            coverURL = creator["cover_url"]?.stringValue
            socialVerificationCode = creator["social_verification_code"]?.stringValue
            socialVerificationSubmittedAt = creator["social_verification_submitted_at"]?.dateValue
            socialVerificationVerifiedAt = creator["social_verification_verified_at"]?.dateValue
        } else {
            creatorID = nil
            creatorCity = nil
            creatorHandle = nil
            creatorScore = nil
            avatarURL = nil
            coverURL = nil
            socialVerificationCode = nil
            socialVerificationSubmittedAt = nil
            socialVerificationVerifiedAt = nil
        }

        if let location = try container.decodeIfPresent([String: JSONValue].self, forKey: .location) {
            locationLat = location["lat"]?.doubleValue
            locationLng = location["lng"]?.doubleValue
            locationUpdatedAt = location["updated_at"]?.dateValue
        } else {
            locationLat = nil
            locationLng = nil
            locationUpdatedAt = nil
        }

        bookingSummaries = (try? container.decode([BookingSummary].self, forKey: .bookings))?.map(\.label) ?? []
        strikeSummaries = (try? container.decode([StrikeSummary].self, forKey: .strikes))?.map(\.label) ?? []
    }

    func encode(to encoder: Encoder) throws {}

    private struct BookingSummary: Decodable {
        let stage: String?
        let offerTitle: String?
        let venueName: String?

        enum CodingKeys: String, CodingKey {
            case stage
            case offerTitle = "offer_title"
            case venueName = "venue_name"
        }

        var label: String {
            [offerTitle, venueName, stage].compactMap { $0 }.joined(separator: " · ")
        }
    }

    private struct StrikeSummary: Decodable {
        let reason: String?
        let severity: String?

        var label: String {
            [severity, reason].compactMap { $0 }.joined(separator: " · ")
        }
    }
}

private enum JSONValue: Decodable {
    case string(String)
    case number(Double)
    case other

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let number = try? container.decode(Double.self) {
            self = .number(number)
        } else {
            self = .other
        }
    }

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var uuidValue: UUID? {
        guard let stringValue else { return nil }
        return UUID(uuidString: stringValue)
    }

    var doubleValue: Double? {
        switch self {
        case .number(let value): return value
        case .string(let value): return Double(value)
        default: return nil
        }
    }

    var intValue: Int? {
        guard let doubleValue else { return nil }
        return Int(doubleValue)
    }

    var dateValue: Date? {
        guard let stringValue else { return nil }
        return ISO8601DateFormatter().date(from: stringValue)
    }
}

struct AdminInviteResult: Codable {
    let email: String
    let inviteCode: String

    enum CodingKeys: String, CodingKey {
        case email
        case inviteCode = "invite_code"
    }
}

struct AdminInviteCodeItem: Identifiable, Equatable, Sendable {
    let id: UUID
    let code: String
    let ownerType: String
    let usesCount: Int
    let maxUses: Int?
    let inviteEmail: String?
    let createdAt: Date

    var quotaLabel: String {
        guard let maxUses else { return "\(usesCount)" }
        return "\(usesCount) / \(maxUses)"
    }
}

struct AdminProvisionResult: Codable {
    let userID: UUID
    let email: String
    let temporaryPassword: String?
    let autoApproved: Bool

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case email
        case temporaryPassword = "temporary_password"
        case autoApproved = "auto_approved"
    }
}

enum SocialVerificationState: String, Codable, Equatable {
    case needsHandles = "needs_handles"
    case pending
    case submitted
    case verified
}

struct SocialVerificationStatus: Equatable {
    let state: SocialVerificationState
    let code: String?
    let instagramHandle: String
    let tiktokHandle: String
    let marviInstagramHandle: String
    let submittedAt: Date?
    let verifiedAt: Date?

    var isVerified: Bool { state == .verified }

    var dmMessage: String {
        guard let code else { return "" }
        let ig = instagramHandle.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "@", with: "")
        let tt = tiktokHandle.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "@", with: "")
        return "\(code) · Instagram @\(ig) · TikTok @\(tt)"
    }
}
