package com.marvisociety.app.data

import com.marvisociety.app.data.CollaborationModel.INSTANT
import com.marvisociety.app.data.CollaborationModel.INVITATION
import com.marvisociety.app.data.OfferCategory.DINING
import com.marvisociety.app.data.OfferCategory.NIGHTLIFE

object SampleData {
    val profile = CreatorProfile(
        name = "Aylin Demir",
        handle = "aylin.in.istanbul",
        tiktokHandle = "aylinistanbul",
        city = "Istanbul",
        status = MembershipStatus.APPROVED,
        score = 92,
        audienceLabel = "48.2K",
        niches = listOf("Food", "Nightlife"),
        proofRate = "98%"
    )

    val offers = listOf(
        Offer(
            id = "1",
            title = "Sunset tasting menu",
            venue = "Mikla",
            area = "Beyoglu",
            category = DINING,
            dateLabel = "Thu 8 PM",
            timeLabel = "20:00",
            valueLabel = "₺2,400 experience",
            capacity = 4,
            remaining = 2,
            collaborationModel = INVITATION
        ),
        Offer(
            id = "2",
            title = "Rooftop launch night",
            venue = "Ulus 29",
            area = "Besiktas",
            category = NIGHTLIFE,
            dateLabel = "Fri 10 PM",
            timeLabel = "22:00",
            valueLabel = "VIP table",
            capacity = 6,
            remaining = 1,
            collaborationModel = INVITATION
        ),
        Offer(
            id = "3",
            title = "Instant coffee content",
            venue = "Petra Roasting",
            area = "Karakoy",
            category = DINING,
            dateLabel = "Today",
            timeLabel = "Anytime",
            valueLabel = "Coffee + pastry",
            capacity = 8,
            remaining = 5,
            collaborationModel = INSTANT
        )
    )

    val bookings = listOf(
        Booking(
            id = "b1",
            offer = offers[0],
            stage = BookingStage.CONFIRMED,
            proofDeadline = "48h after visit"
        )
    )
}
