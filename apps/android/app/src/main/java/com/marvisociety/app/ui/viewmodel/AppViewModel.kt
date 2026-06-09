package com.marvisociety.app.ui.viewmodel

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import com.marvisociety.app.data.Booking
import com.marvisociety.app.data.CreatorProfile
import com.marvisociety.app.data.Offer
import com.marvisociety.app.data.SampleData

class AppViewModel : ViewModel() {
    var hasCompletedOnboarding by mutableStateOf(false)
        private set

    var profile: CreatorProfile = SampleData.profile
        private set

    var offers: List<Offer> = SampleData.offers
        private set

    var bookings: List<Booking> = SampleData.bookings
        private set

    var savedOfferIds by mutableStateOf(setOf("1", "3"))
        private set

    fun completeOnboarding(handle: String, city: String, inviteCode: String) {
        val validCodes = setOf("MARVI-IST", "MARVI2026", "TSS-REF")
        if (inviteCode.uppercase() !in validCodes) return
        profile = profile.copy(handle = handle, city = city)
        hasCompletedOnboarding = true
    }

    fun toggleSaved(offerId: String) {
        savedOfferIds = if (offerId in savedOfferIds) {
            savedOfferIds - offerId
        } else {
            savedOfferIds + offerId
        }
    }

    fun instantOffers(): List<Offer> = offers.filter { it.model == "instant" }
}
