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
        switch self {
        case .creator:
            "Find curated Istanbul invitations and submit proof."
        case .venue:
            "Create campaigns and manage creator attendance."
        case .admin:
            "Approve members, venues, campaigns, and proof."
        }
    }

    static func fromAPI(_ raw: String?) -> UserRole? {
        switch raw?.lowercased() {
        case "creator": .creator
        case "venue": .venue
        case "admin": .admin
        default: nil
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

    /// Fallback when no locale signal is available.
    static var defaultApp: AppLanguage { .english }

    /// Device/App Store region and system language (before GPS).
    static func inferredFromDevice() -> AppLanguage {
        if isDeviceLikelyInTurkey { return .turkish }
        return .english
    }

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

struct FollowCounts: Equatable {
    var followers: Int
    var following: Int

    static let zero = FollowCounts(followers: 0, following: 0)
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
    let address: String
    let contactName: String
    let contactPhone: String
}

struct CreateCampaignInput: Sendable {
    let title: String
    let category: OfferCategory
    let collaborationModel: CollaborationModel
    let dateLabel: String
    let valueLabel: String
    let slots: Int
    let deliverables: [String]
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
        deliverables: [String]
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
        offerID: UUID? = nil
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
    }

    var deepLink: MarviDeepLink? {
        if let bookingID { return .booking(bookingID) }
        if let offerID { return .offer(offerID) }
        switch notificationType.lowercased() {
        case "membership": return .profile
        case "admin", "campaign": return .admin
        case "booking": return .inbox
        default: return nil
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
    }

    var displayName: String {
        if let fullName, !fullName.isEmpty { return fullName }
        if let instagramHandle, !instagramHandle.isEmpty { return instagramHandle }
        return email ?? userID.uuidString.prefix(8).description
    }

    var hasLiveLocation: Bool {
        lastLat != nil && lastLng != nil
    }
}

struct AdminUserDetail: Codable {
    let userID: UUID
    var email: String?
    var role: String?
    var status: String?
    var referralCode: String?
    var phone: String?
    var creatorCity: String?
    var creatorHandle: String?
    var creatorScore: Int?
    var locationLat: Double?
    var locationLng: Double?
    var locationUpdatedAt: Date?
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
            creatorCity = creator["city"]?.stringValue
            creatorHandle = creator["instagram_handle"]?.stringValue
            creatorScore = creator["score"]?.intValue
        } else {
            creatorCity = nil
            creatorHandle = nil
            creatorScore = nil
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
