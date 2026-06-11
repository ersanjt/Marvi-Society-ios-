import SwiftUI

enum OfferImagery {
    static func imageURL(for offer: Offer) -> URL? {
        let name = offer.imageName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.hasPrefix("http"), let url = URL(string: name) { return url }
        return stockURL(for: offer.category)
    }

    static func stockURL(for category: OfferCategory) -> URL? {
        let raw: String
        switch category {
        case .dining:
            raw = "https://images.unsplash.com/photo-1414235077428-338989a2e8c0?w=900&q=80"
        case .nightlife:
            raw = "https://images.unsplash.com/photo-1516450360452-9312f5e86fc7?w=900&q=80"
        case .wellness:
            raw = "https://images.unsplash.com/photo-1544161515-4ab6ce6db874?w=900&q=80"
        case .beauty:
            raw = "https://images.unsplash.com/photo-1570172619644-dfd03ed5d881?w=900&q=80"
        case .fitness:
            raw = "https://images.unsplash.com/photo-1540497077202-7a8ee7868e29?w=900&q=80"
        case .retail:
            raw = "https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=900&q=80"
        }
        return URL(string: raw)
    }
}

struct OfferImageView: View {
    let offer: Offer
    var height: CGFloat = 200
    var cornerRadius: CGFloat = 0

    var body: some View {
        Group {
            if let url = OfferImagery.imageURL(for: offer) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholder
                    default:
                        ZStack {
                            placeholder
                            ProgressView().tint(.white)
                        }
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var placeholder: some View {
        ZStack {
            MarviGradient.brandVertical
            Image(systemName: offer.category.icon)
                .font(.system(size: height > 100 ? 48 : 28, weight: .light))
                .foregroundStyle(.white.opacity(0.25))
        }
    }
}
