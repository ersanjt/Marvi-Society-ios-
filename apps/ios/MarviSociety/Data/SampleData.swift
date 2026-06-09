import SwiftUI

enum SampleData {
    private static func stableID(_ value: String) -> UUID {
        UUID(uuidString: value) ?? UUID()
    }

    static let offers: [Offer] = [
        Offer(
            id: stableID("11111111-1111-1111-1111-111111111111"),
            title: "Bosphorus tasting dinner",
            venue: "Mira Bosphorus",
            area: "Bebek",
            category: .dining,
            dateLabel: "Fri, Jun 5",
            timeLabel: "20:30",
            valueLabel: "Dinner for 2",
            capacity: 12,
            remaining: 3,
            imageName: "photo",
            description: "A hosted dinner for creators with strong food, lifestyle, and city culture content. The venue wants warm evening coverage with a focus on the terrace, plating, and guest atmosphere.",
            deliverables: [
                "3 Instagram stories with venue tag",
                "1 short Reel within 48 hours",
                "Google review after visit"
            ],
            requirements: [
                "Minimum 8K Instagram followers",
                "Public profile",
                "Smart evening dress code"
            ],
            hostNote: "Arrive on time. The host will check in members at the entrance under Marvi Society."
        ),
        Offer(
            id: stableID("22222222-2222-2222-2222-222222222222"),
            title: "Signature facial launch",
            venue: "Luma Clinic",
            area: "Nisantasi",
            category: .beauty,
            dateLabel: "Mon, Jun 8",
            timeLabel: "14:00",
            valueLabel: "Treatment credit",
            capacity: 8,
            remaining: 2,
            imageName: "photo.on.rectangle",
            description: "A beauty clinic preview for creators who can document a polished before-and-after experience with a calm, premium tone.",
            deliverables: [
                "2 Instagram stories before leaving",
                "1 before-and-after carousel",
                "Tag clinic and Marvi Society"
            ],
            requirements: [
                "Beauty, wellness, or lifestyle niche",
                "No competing clinic content for 7 days",
                "Consent for venue repost"
            ],
            hostNote: "Treatment choice is confirmed after skin consultation."
        ),
        Offer(
            id: stableID("33333333-3333-3333-3333-333333333333"),
            title: "Rooftop opening night",
            venue: "Karakoy House",
            area: "Karakoy",
            category: .nightlife,
            dateLabel: "Sat, Jun 13",
            timeLabel: "22:00",
            valueLabel: "VIP table access",
            capacity: 20,
            remaining: 5,
            imageName: "moon.stars",
            description: "Opening-night coverage for a new rooftop concept. Best for creators with nightlife, fashion, music, or Istanbul city-aesthetic content.",
            deliverables: [
                "4 live stories",
                "1 tagged grid post or Reel",
                "Story highlight for 7 days"
            ],
            requirements: [
                "Age 21+",
                "Evening fashion dress code",
                "No flash filming of private guests"
            ],
            hostNote: "Guest list closes at 19:00 on event day."
        ),
        Offer(
            id: stableID("44444444-4444-4444-4444-444444444444"),
            title: "Pilates reformer week",
            venue: "Axis Studio",
            area: "Etiler",
            category: .fitness,
            dateLabel: "Jun 10-16",
            timeLabel: "Flexible",
            valueLabel: "3 class pass",
            capacity: 15,
            remaining: 7,
            imageName: "figure.run",
            description: "A week-long reformer pilates collaboration for creators who can show the studio experience across multiple visits.",
            deliverables: [
                "1 story per visit",
                "1 short recap Reel",
                "Mention trainer by name"
            ],
            requirements: [
                "Comfortable filming fitness content",
                "Book classes 24 hours ahead",
                "Bring grip socks"
            ],
            hostNote: "Members may choose morning or evening classes based on availability."
        ),
        Offer(
            id: stableID("55555555-5555-5555-5555-555555555555"),
            title: "Galataport brunch set",
            venue: "Pier Social",
            area: "Galataport",
            category: .dining,
            dateLabel: "Sun, Jun 14",
            timeLabel: "11:30",
            valueLabel: "Brunch for 2",
            capacity: 10,
            remaining: 4,
            imageName: "sun.max",
            description: "A relaxed weekend brunch for city guide and food creators. The venue is looking for bright, useful content for visitors and locals.",
            deliverables: [
                "3 stories with location tag",
                "1 TikTok or Reel",
                "Saveable recommendation caption"
            ],
            requirements: [
                "Food or Istanbul guide content",
                "Shoot during natural daylight",
                "Submit links after posting"
            ],
            hostNote: "Window tables are reserved for confirmed Marvi members."
        ),
        Offer(
            id: stableID("66666666-6666-6666-6666-666666666666"),
            title: "Concept store preview",
            venue: "Arka Edit",
            area: "Moda",
            category: .retail,
            dateLabel: "Thu, Jun 18",
            timeLabel: "18:00",
            valueLabel: "Shopping credit",
            capacity: 14,
            remaining: 6,
            imageName: "bag",
            description: "A creator evening at a local concept store with independent labels, accessories, and home objects.",
            deliverables: [
                "3 stories with product tags",
                "1 styled outfit or flatlay post",
                "Venue repost rights"
            ],
            requirements: [
                "Fashion, design, or lifestyle niche",
                "Credit featured brands",
                "No direct resale content"
            ],
            hostNote: "A stylist will be available for creator pulls."
        )
    ]

    static let bookings: [Booking] = [
        Booking(
            id: UUID(),
            offer: offers[1],
            stage: .confirmed,
            proofDeadline: "Jun 9, 18:00",
            checklist: [
                "Arrive 10 minutes early",
                "Capture entrance and treatment room",
                "Upload post links after publishing"
            ],
            proofStatus: .notStarted,
            checkInCode: "4281",
            guestName: "Derya",
            proofLinks: []
        ),
        Booking(
            id: UUID(),
            offer: offers[4],
            stage: .invited,
            proofDeadline: "Jun 15, 20:00",
            checklist: [
                "Confirm guest name",
                "Record brunch set before eating",
                "Submit Google review link"
            ],
            proofStatus: .notStarted,
            checkInCode: "7714",
            guestName: "",
            proofLinks: []
        )
    ]

    static let profile = CreatorProfile(
        name: "Aylin Demir",
        handle: "@aylin.in.istanbul",
        city: "Istanbul",
        status: .approved,
        score: 92,
        audienceLabel: "41.8K audience",
        niches: ["Food", "Beauty", "City Guide"],
        proofRate: "96% proof rate",
        bio: "Istanbul city guide focused on restaurants, beauty clinics, and polished weekend plans.",
        languages: ["Turkish", "English", "Persian"],
        completedApplicationSteps: 4
    )

    static let venueMetrics: [VenueMetric] = [
        VenueMetric(title: "Live promos", value: "6", trend: "+2 this week", icon: "megaphone"),
        VenueMetric(title: "Creator matches", value: "84", trend: "31 confirmed", icon: "person.2"),
        VenueMetric(title: "Proof received", value: "89%", trend: "+6% vs last month", icon: "checkmark.seal"),
        VenueMetric(title: "Avg. reach", value: "312K", trend: "per campaign", icon: "chart.line.uptrend.xyaxis")
    ]

    static let campaigns: [Campaign] = [
        Campaign(
            title: "Bosphorus tasting dinner",
            venueName: "Mira Bosphorus",
            area: "Bebek",
            category: .dining,
            dateLabel: "Fri, Jun 5",
            valueLabel: "Dinner for 2",
            slots: 12,
            matchedCreators: 9,
            status: .live,
            deliverables: ["3 Instagram stories", "1 short Reel", "Google review"]
        ),
        Campaign(
            title: "Rooftop opening night",
            venueName: "Karakoy House",
            area: "Karakoy",
            category: .nightlife,
            dateLabel: "Sat, Jun 13",
            valueLabel: "VIP table access",
            slots: 20,
            matchedCreators: 15,
            status: .review,
            deliverables: ["4 live stories", "1 tagged post", "Story highlight"]
        ),
        Campaign(
            title: "Signature facial launch",
            venueName: "Luma Clinic",
            area: "Nisantasi",
            category: .beauty,
            dateLabel: "Mon, Jun 8",
            valueLabel: "Treatment credit",
            slots: 8,
            matchedCreators: 8,
            status: .completed,
            deliverables: ["2 stories", "Before-after carousel", "Repost rights"]
        )
    ]

    static let adminTasks: [AdminTask] = [
        AdminTask(
            type: .creatorApplication,
            title: "Aylin Demir",
            subtitle: "41.8K audience, food and beauty niche, Istanbul.",
            dateLabel: "Today",
            priority: "High"
        ),
        AdminTask(
            type: .venueApplication,
            title: "Pier Social",
            subtitle: "Galataport brunch venue requested partner approval.",
            dateLabel: "Today",
            priority: "Medium"
        ),
        AdminTask(
            type: .campaignReview,
            title: "Rooftop opening night",
            subtitle: "Karakoy House wants 20 creators for opening night.",
            dateLabel: "Yesterday",
            priority: "High"
        )
    ]

    static let inboxMessages: [InboxMessage] = [
        InboxMessage(
            title: "Luma Clinic confirmed",
            body: "Your appointment is locked for Mon, Jun 8 at 14:00.",
            dateLabel: "Today",
            icon: "checkmark.circle.fill",
            tint: .emerald
        ),
        InboxMessage(
            title: "Proof reminder",
            body: "Pier Social proof is due after the brunch visit.",
            dateLabel: "Yesterday",
            icon: "bell.badge.fill",
            tint: .gold
        )
    ]
}
