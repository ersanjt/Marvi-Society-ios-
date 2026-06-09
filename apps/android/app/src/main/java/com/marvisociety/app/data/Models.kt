package com.marvisociety.app.data

data class Offer(
    val id: String,
    val title: String,
    val venue: String,
    val area: String,
    val category: String,
    val model: String,
    val valueLabel: String,
    val remaining: Int,
    val capacity: Int
)

data class Booking(
    val id: String,
    val offer: Offer,
    val stage: String,
    val proofDeadline: String
)

data class CreatorProfile(
    val name: String,
    val handle: String,
    val city: String,
    val score: Int,
    val proofRate: String
)
