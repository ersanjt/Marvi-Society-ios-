import Foundation

// MARK: - Database rows (snake_case)

struct VenueProfileEmbed: Decodable {
    let venue_name: String
    let area: String
}

struct OfferRow: Decodable {
    let id: UUID
    let venue_id: UUID?
    let title: String
    let venue_name: String?
    let area: String?
    let venue_profiles: VenueProfileEmbed?
    let category: String
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
    let checklist: [String]?
    let status: String?
    let lat: Double?
    let lng: Double?
    let created_at: String?

    func toOffer() -> Offer {
        Offer(
            id: id,
            title: title,
            venue: venue_profiles?.venue_name ?? venue_name ?? "Venue",
            area: venue_profiles?.area ?? area ?? "Istanbul",
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
            createdAt: APIDTOs.parseISO8601(created_at)
        )
    }
}

struct BookingRow: Decodable {
    let id: UUID
    let offer_id: UUID
    let stage: String
    let check_in_code: String
    let guest_name: String?
    let proof_deadline_label: String?
    let proof_status: String?
    let proof_links: [String]?
    let offers: OfferRow?

    func toBooking() -> Booking? {
        guard let offerRow = offers else { return nil }
        return Booking(
            id: id,
            offer: offerRow.toOffer(),
            stage: BookingStage.fromAPI(stage),
            proofDeadline: proof_deadline_label ?? "Today, 22:00",
            checklist: offerRow.checklist ?? [
                "Confirm guest details",
                "Check in with venue host",
                "Upload story, post, or review links"
            ],
            proofStatus: ProofStatus.fromAPI(proof_status),
            checkInCode: check_in_code,
            guestName: guest_name ?? "",
            proofLinks: proof_links ?? []
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
    let languages: [String]?
    let proof_rate: Double?
    let bio: String?

    func toProfile() -> CreatorProfile {
        let audience = audience_count ?? 0
        let audienceLabel: String = {
            if audience >= 1000 {
                return String(format: "%.1fK", Double(audience) / 1000.0)
            }
            return "\(audience)"
        }()

        return CreatorProfile(
            name: full_name ?? "Creator",
            handle: instagram_handle ?? "",
            tiktokHandle: tiktok_handle ?? "",
            city: city ?? "Istanbul",
            status: MembershipStatus.fromAPI(status),
            score: Int(score ?? 0),
            audienceLabel: audienceLabel,
            niches: niches ?? [],
            proofRate: "\(Int(proof_rate ?? 0))%",
            bio: bio ?? "",
            languages: languages ?? ["English"],
            completedApplicationSteps: status == "approved" ? 6 : 4
        )
    }
}

struct NotificationRow: Decodable {
    let id: UUID
    let title: String
    let body: String
    let icon: String?
    let tint: String?
    let created_at: String?

    func toMessage() -> InboxMessage {
        InboxMessage(
            id: id,
            title: title,
            body: body,
            dateLabel: formatRelative(created_at),
            icon: icon ?? "bell.fill",
            tint: PaletteToken.fromAPI(tint)
        )
    }

    private func formatRelative(_ iso: String?) -> String {
        guard let iso,
              let date = ISO8601DateFormatter().date(from: iso) else {
            return "Now"
        }
        let interval = Date().timeIntervalSince(date)
        if interval < 3600 { return "Now" }
        if interval < 86400 { return "Today" }
        return "Earlier"
    }
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

struct SavedOfferRow: Decodable {
    let offer_id: UUID
}

// MARK: - API enum mapping

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

struct VenueProfileRow: Decodable {
    let id: UUID
    let venue_name: String
    let area: String
    let category: String?
    let status: String?
    let lat: Double?
    let lng: Double?

    func toSummary() -> VenueSummary {
        VenueSummary(
            id: id,
            venueName: venue_name,
            area: area,
            category: OfferCategory.fromAPI(category),
            latitude: lat,
            longitude: lng
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

struct OfferIDTitleRow: Decodable {
    let id: UUID
    let title: String
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
        default: .confirmed
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

extension MembershipStatus {
    static func fromAPI(_ raw: String?) -> MembershipStatus {
        switch raw?.lowercased() {
        case "approved": .approved
        case "paused": .paused
        default: .underReview
        }
    }
}

extension AdminTaskType {
    static func fromAPI(_ raw: String?) -> AdminTaskType {
        switch raw?.lowercased() {
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

enum APIDTOs {
    static func parseISO8601(_ iso: String?) -> Date? {
        guard let iso else { return nil }
        let full = ISO8601DateFormatter()
        full.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return full.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
    }

    static func formatRelative(_ iso: String?) -> String {
        guard let iso,
              let date = parseISO8601(iso) else {
            return "Now"
        }
        let interval = Date().timeIntervalSince(date)
        if interval < 3600 { return "Now" }
        if interval < 86400 { return "Today" }
        if interval < 604_800 { return "This week" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

extension PaletteToken {
    static func fromAPI(_ raw: String?) -> PaletteToken {
        switch raw?.lowercased() {
        case "aubergine": .aubergine
        case "gold": .gold
        case "rose": .rose
        case "tomato": .tomato
        case "blue": .blue
        case "muted": .muted
        case "ink": .ink
        default: .emerald
        }
    }
}
