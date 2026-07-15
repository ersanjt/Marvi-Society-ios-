package com.marvisociety.app.ui

import com.marvisociety.app.data.Offer
import com.marvisociety.app.data.OfferCategory

object OfferImagery {
    fun imageUrl(offer: Offer): String {
        val name = offer.imageName.trim()
        if (name.startsWith("http")) return name
        return stockUrl(offer.category)
    }

    fun stockUrl(category: OfferCategory): String = when (category) {
        OfferCategory.DINING ->
            "https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=900&q=80"
        OfferCategory.NIGHTLIFE ->
            "https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=900&q=80"
        OfferCategory.WELLNESS ->
            "https://images.unsplash.com/photo-1544161515-4ab6ce6db874?w=900&q=80"
        OfferCategory.BEAUTY ->
            "https://images.unsplash.com/photo-1570172619644-dfd03ed5d881?w=900&q=80"
        OfferCategory.FITNESS ->
            "https://images.unsplash.com/photo-1540497077202-7a8ee7868e29?w=900&q=80"
        OfferCategory.RETAIL ->
            "https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=900&q=80"
    }
}
