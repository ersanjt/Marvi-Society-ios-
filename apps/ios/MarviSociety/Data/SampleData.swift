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
            description: "A hosted dinner for creators with strong food, lifestyle, and city culture content.",
            deliverables: ["3 Instagram stories", "1 short Reel within 48 hours", "Google review"],
            requirements: ["Minimum 8K followers", "Public profile", "Smart evening dress code"],
            hostNote: "Arrive on time. Check in under Marvi Society.",
            collaborationModel: .invitation,
            latitude: 41.0775,
            longitude: 29.0433
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
            description: "Beauty clinic preview for polished before-and-after content.",
            deliverables: ["2 stories", "1 before-and-after carousel", "Tag clinic"],
            requirements: ["Beauty or wellness niche", "Consent for repost"],
            hostNote: "Treatment confirmed after consultation.",
            collaborationModel: .gift,
            latitude: 41.0520,
            longitude: 28.9940
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
            description: "Opening-night coverage for a new rooftop concept.",
            deliverables: ["4 live stories", "1 Reel or grid post", "Story highlight 7 days"],
            requirements: ["Age 21+", "Evening fashion dress code"],
            hostNote: "Guest list closes at 19:00.",
            collaborationModel: .event,
            latitude: 41.0256,
            longitude: 28.9744
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
            description: "Week-long reformer pilates collaboration across multiple visits.",
            deliverables: ["1 story per visit", "1 recap Reel"],
            requirements: ["Fitness content comfort", "Book 24h ahead"],
            hostNote: "Morning or evening classes available.",
            collaborationModel: .invitation,
            latitude: 41.0831,
            longitude: 29.0340
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
            description: "Weekend brunch for city guide and food creators.",
            deliverables: ["3 stories with location tag", "1 TikTok or Reel"],
            requirements: ["Food or Istanbul guide niche"],
            hostNote: "Window tables for confirmed members.",
            collaborationModel: .invitation,
            latitude: 41.0252,
            longitude: 28.9839
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
            description: "Creator evening at a local concept store.",
            deliverables: ["3 stories", "1 styled post"],
            requirements: ["Fashion or lifestyle niche"],
            hostNote: "Stylist available for pulls.",
            collaborationModel: .gift,
            latitude: 40.9848,
            longitude: 29.0260
        ),
        Offer(
            id: stableID("77777777-7777-7777-7777-777777777777"),
            title: "Flat white + pastry",
            venue: "Kadikoy Brew Lab",
            area: "Kadikoy",
            category: .dining,
            dateLabel: "Today",
            timeLabel: "Anytime",
            valueLabel: "Coffee + pastry",
            capacity: 25,
            remaining: 19,
            imageName: "cup.and.saucer",
            description: "Walk-in grab-and-go collaboration. Open the map, accept, visit within 2 hours, post a story.",
            deliverables: ["1 Instagram story with location tag"],
            requirements: ["Within 1 km", "Post within 2 hours"],
            hostNote: "Show your check-in code at the counter.",
            collaborationModel: .instant,
            latitude: 40.9903,
            longitude: 29.0244
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
        tiktokHandle: "@aylin.istanbul",
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

    static let strikes: [Strike] = []

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
