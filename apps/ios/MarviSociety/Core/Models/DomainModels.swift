import Foundation
import SwiftUI

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
        longitude: Double? = nil
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
    }

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
}

struct VenueMetric: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let trend: String
    let icon: String
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

struct AdminTask: Codable, Identifiable, Hashable {
    let id: UUID
    var type: AdminTaskType
    var title: String
    var subtitle: String
    var dateLabel: String
    var priority: String
    var status: AdminTaskStatus

    init(
        id: UUID = UUID(),
        type: AdminTaskType,
        title: String,
        subtitle: String,
        dateLabel: String,
        priority: String,
        status: AdminTaskStatus = .open
    ) {
        self.id = id
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

    init(
        id: UUID = UUID(),
        title: String,
        body: String,
        dateLabel: String,
        icon: String,
        tint: PaletteToken
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.dateLabel = dateLabel
        self.icon = icon
        self.tint = tint
    }
}
