import Foundation

enum APIDTOs {
    static func formatRelative(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "Now" }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = iso.date(from: raw)
        if date == nil {
            iso.formatOptions = [.withInternetDateTime]
            date = iso.date(from: raw)
        }
        guard let date else { return raw.prefix(10).description }

        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "Now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        if seconds < 604800 { return "\(seconds / 86400)d ago" }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct OfferRow: Decodable {
    let id: UUID
    let title: String
    let venue_name: String?
    let area: String?
    let category: String?
    let model: String?
    let date_label: String?
    let time_label: String?
    let value_label: String?
    let capacity: Int?
    let remaining_slots: Int?
    let image_name: String?
    let description: String?
    let deliverables: [String]?
    let requirements: [String]?
    let host_note: String?
    let lat: Double?
    let lng: Double?
    let created_at: String?

    func toOffer() -> Offer {
        Offer(
            id: id,
            title: title,
            venue: venue_name ?? "Venue",
            area: area ?? "Istanbul",
            category: OfferCategory.fromAPI(category),
            dateLabel: date_label ?? "TBD",
            timeLabel: time_label ?? "",
            valueLabel: value_label ?? "",
            capacity: capacity ?? 1,
            remaining: remaining_slots ?? 0,
            imageName: image_name ?? "venue-placeholder",
            description: description ?? "",
            deliverables: deliverables ?? [],
            requirements: requirements ?? [],
            hostNote: host_note ?? "",
            collaborationModel: CollaborationModel.fromAPI(model),
            latitude: lat,
            longitude: lng,
            createdAt: ISO8601DateFormatter().date(from: created_at ?? "")
        )
    }
}

struct CreatorProfileRow: Decodable {
    let full_name: String?
    let instagram_handle: String?
    let tiktok_handle: String?
    let city: String?
    let status: String?
    let score: Double?
    let audience_count: Int?
    let niches: [String]?
    let proof_rate: Double?
    let bio: String?
    let languages: [String]?
    let avatar_url: String?
    let cover_url: String?

    func toProfile() -> CreatorProfile {
        let audience = audience_count ?? 0
        let audienceLabel: String
        if audience >= 1000 {
            audienceLabel = String(format: "%.1fK", Double(audience) / 1000)
        } else {
            audienceLabel = "\(audience)"
        }

        return CreatorProfile(
            name: full_name ?? "",
            handle: instagram_handle ?? "",
            tiktokHandle: tiktok_handle ?? "",
            city: (city ?? "istanbul").capitalized,
            status: MembershipStatus.fromAPI(status) ?? .underReview,
            score: Int(score ?? 0),
            audienceLabel: audienceLabel,
            niches: niches ?? [],
            proofRate: proof_rate.map { String(format: "%.0f%%", $0) } ?? "—",
            bio: bio ?? "",
            languages: languages ?? [],
            completedApplicationSteps: 0,
            avatarURL: avatar_url ?? "",
            coverURL: cover_url ?? ""
        )
    }
}

struct NotificationRow: Decodable {
    let id: UUID
    let title: String
    let body: String
    let icon: String?
    let tint: String?
    let is_read: Bool?
    let type: String?
    let created_at: String?
    let booking_id: UUID?
    let offer_id: UUID?

    func toMessage() -> InboxMessage {
        InboxMessage(
            id: id,
            title: title,
            body: body,
            dateLabel: APIDTOs.formatRelative(created_at),
            icon: icon ?? "bell.fill",
            tint: PaletteToken(rawValue: tint ?? "rose") ?? .rose,
            isRead: is_read ?? false,
            notificationType: type ?? "general",
            bookingID: booking_id,
            offerID: offer_id
        )
    }
}

struct SavedOfferRow: Decodable {
    let offer_id: UUID
}

struct AdminTaskRow: Decodable {
    let id: UUID
    let subject_id: UUID?
    let type: String
    let title: String
    let subtitle: String?
    let priority: String?
    let status: String?
    let created_at: String?

    func toTask() -> AdminTask {
        AdminTask(
            id: id,
            subjectID: subject_id,
            type: AdminTaskType.fromAPI(type),
            title: title,
            subtitle: subtitle ?? "",
            dateLabel: APIDTOs.formatRelative(created_at),
            priority: priority ?? "Medium",
            status: AdminTaskStatus.fromAPI(status)
        )
    }
}

struct VenueProfileRow: Decodable {
    let id: UUID
    let venue_name: String
    let area: String
    let category: String?
    let status: String?
    let lat: Double?
    let lng: Double?

    func toSummary(isActive: Bool = false) -> VenueSummary {
        VenueSummary(
            id: id,
            venueName: venue_name,
            area: area,
            category: OfferCategory.fromAPI(category),
            status: MembershipStatus.fromAPI(status),
            isActive: isActive,
            latitude: lat,
            longitude: lng
        )
    }
}

struct MyVenueRow: Decodable {
    let id: UUID
    let venue_name: String
    let area: String
    let category: String?
    let status: String?
    let is_active: Bool?

    func toSummary() -> VenueSummary {
        VenueSummary(
            id: id,
            venueName: venue_name,
            area: area,
            category: OfferCategory.fromAPI(category),
            status: MembershipStatus.fromAPI(status),
            isActive: is_active ?? false
        )
    }
}

struct CampaignOfferRow: Decodable {
    let id: UUID
    let title: String
    let category: String
    let date_label: String?
    let value_label: String?
    let capacity: Int?
    let remaining_slots: Int?
    let deliverables: [String]?
    let status: String?
    let venue_profiles: VenueProfileEmbed?

    struct VenueProfileEmbed: Decodable {
        let venue_name: String?
        let area: String?
    }

    func toCampaign(matchedCreators: Int = 0) -> Campaign {
        let capacity = capacity ?? 1
        let remaining = remaining_slots ?? 0
        return Campaign(
            id: id,
            title: title,
            venueName: venue_profiles?.venue_name ?? "Venue",
            area: venue_profiles?.area ?? "Istanbul",
            category: OfferCategory.fromAPI(category),
            dateLabel: date_label ?? "TBD",
            valueLabel: value_label ?? "",
            slots: capacity,
            matchedCreators: max(0, capacity - remaining),
            status: CampaignStatus.fromAPI(status),
            deliverables: deliverables ?? []
        )
    }
}

extension MembershipStatus {
    static func fromAPI(_ raw: String?) -> MembershipStatus? {
        switch raw?.lowercased() {
        case "approved": .approved
        case "paused": .paused
        case "under_review": .underReview
        default: nil
        }
    }
}

extension BookingStage {
    static func fromAPI(_ raw: String?) -> BookingStage {
        switch raw?.lowercased() {
        case "invited": .invited
        case "confirmed": .confirmed
        case "checked_in": .checkedIn
        case "proof_due": .proofDue
        case "completed": .completed
        case "cancelled": .cancelled
        default: .invited
        }
    }
}

extension ProofStatus {
    static func fromAPI(_ raw: String?) -> ProofStatus {
        switch raw?.lowercased() {
        case "not_started": .notStarted
        case "pending": .pending
        case "approved": .approved
        case "flagged": .flagged
        default: .notStarted
        }
    }
}

extension OfferCategory {
    static func fromAPI(_ raw: String?) -> OfferCategory {
        switch raw?.lowercased() {
        case "dining": .dining
        case "nightlife": .nightlife
        case "wellness": .wellness
        case "beauty": .beauty
        case "fitness": .fitness
        case "retail": .retail
        default: .dining
        }
    }

    var apiValue: String {
        switch self {
        case .dining: "dining"
        case .nightlife: "nightlife"
        case .wellness: "wellness"
        case .beauty: "beauty"
        case .fitness: "fitness"
        case .retail: "retail"
        }
    }
}

extension CollaborationModel {
    static func fromAPI(_ raw: String?) -> CollaborationModel {
        switch raw?.lowercased() {
        case "event": .event
        case "gift": .gift
        case "instant": .instant
        default: .invitation
        }
    }

    var apiValue: String {
        switch self {
        case .invitation: "invitation"
        case .event: "event"
        case .gift: "gift"
        case .instant: "instant"
        }
    }
}

extension CampaignStatus {
    static func fromAPI(_ raw: String?) -> CampaignStatus {
        switch raw?.lowercased() {
        case "draft": .draft
        case "live": .live
        case "completed": .completed
        default: .review
        }
    }
}

extension AdminTaskType {
    static func fromAPI(_ raw: String?) -> AdminTaskType {
        switch raw?.lowercased() {
        case "creator_application": .creatorApplication
        case "venue_application": .venueApplication
        case "campaign_review": .campaignReview
        case "proof_review": .proofReview
        default: .creatorApplication
        }
    }
}

extension AdminTaskStatus {
    static func fromAPI(_ raw: String?) -> AdminTaskStatus {
        switch raw?.lowercased() {
        case "approved": .approved
        case "rejected": .rejected
        default: .open
        }
    }
}
