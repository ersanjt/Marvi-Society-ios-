package com.marvisociety.app.data

object SampleData {
    val profile = CreatorProfile(
        name = "Aylin Demir",
        handle = "@aylin.in.istanbul",
        city = "Istanbul",
        score = 92,
        proofRate = "96%"
    )

    val offers = listOf(
        Offer("1", "Bosphorus tasting dinner", "Mira Bosphorus", "Bebek", "Dining", "invitation", "Dinner for 2", 3, 12),
        Offer("2", "Kadıköy Brew Lab instant", "Kadıköy Brew Lab", "Kadıköy", "Café", "instant", "Coffee + pastry", 5, 8),
        Offer("3", "Rooftop opening night", "Karakoy House", "Karaköy", "Nightlife", "event", "VIP entry", 8, 20),
        Offer("4", "Luma Clinic glow session", "Luma Clinic", "Nişantaşı", "Beauty", "gift", "Facial package", 2, 6)
    )

    val bookings = listOf(
        Booking("b1", offers[0], "confirmed", "Jun 9, 18:00"),
        Booking("b2", offers[1], "checked_in", "Today, 22:00")
    )
}
